--!strict
-- ServerScriptService/ArenaDestructionService.luau
-- Convierte estructuras etiquetadas como "DestructibleStructure" en bloques físicos al recibir explosiones o embestidas.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local ArenaDestructionService = {}

-- Destruye un modelo de edificio o estructura de bloques
function ArenaDestructionService.DestroyStructure(structure: Instance, blastOrigin: Vector3?, blastForce: number?)
	if structure:GetAttribute("IsDestroyed") then
		return
	end
	structure:SetAttribute("IsDestroyed", true)

	local force = blastForce or 45

	-- Recorrer todas las piezas del edificio/puente/letrero
	for _, item in ipairs(structure:GetDescendants()) do
		if item:IsA("WeldConstraint") or item:IsA("JointInstance") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = true

			-- Aplicar impulso radial desde el centro de la explosión
			if blastOrigin then
				local offset = item.Position - blastOrigin + Vector3.new(0, 3, 0)
				if offset.Magnitude > 0.001 then
					item:ApplyImpulse(offset.Unit * item.AssemblyMass * force)
				end
			end
		end
	end

	-- Si la etiqueta se puso directamente sobre una sola Part (ej. un muro o árbol)
	if structure:IsA("BasePart") then
		structure.Anchored = false
		structure.CanCollide = true
		if blastOrigin then
			local offset = structure.Position - blastOrigin + Vector3.new(0, 3, 0)
			if offset.Magnitude > 0.001 then
				structure:ApplyImpulse(offset.Unit * structure.AssemblyMass * force)
			end
		end
	end

	-- Limpiar los escombros tras 12 segundos para mantener los 60 FPS
	Debris:AddItem(structure, 12)
end

-- Aplica daño a estructuras dentro de un radio de explosión (conectado a ProjectileService)
function ArenaDestructionService.DamageStructuresInRadius(center: Vector3, radius: number, damage: number)
	local parts = workspace:GetPartBoundsInRadius(center, radius)
	local processedStructures: { [Instance]: boolean } = {}

	for _, part in ipairs(parts) do
		-- Buscar hacia arriba si pertenece a una estructura etiquetada
		local current: Instance? = part
		while current and current ~= workspace do
			if current:HasTag("DestructibleStructure") and not processedStructures[current] then
				processedStructures[current] = true

				local hp = ((current:GetAttribute("Health") :: number?) or 50) - damage
				current:SetAttribute("Health", hp)

				if hp <= 0 then
					ArenaDestructionService.DestroyStructure(current, center, 50)
				end
				break
			end
			current = current.Parent
		end
	end
end

-- Configurar embestidas: si un auto pesado choca a alta velocidad, derriba cercas/estructuras débiles
local function setupDestructibleStructure(structure: Instance)
	if structure:GetAttribute("Health") == nil then
		structure:SetAttribute("Health", 50)
	end

	local function bindPart(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		part.Touched:Connect(function(hit: BasePart)
			if structure:GetAttribute("IsDestroyed") then
				return
			end
			-- Si lo golpea un vehículo a más de 65 studs/s y la estructura es débil (Health <= 40)
			if hit.AssemblyLinearVelocity.Magnitude > 65 and ((structure:GetAttribute("Health") :: number?) or 50) <= 40 then
				local vehicle = hit:FindFirstAncestorOfClass("Model")
				if vehicle and vehicle:HasTag("CombatVehicle") then
					ArenaDestructionService.DestroyStructure(structure, hit.Position, 35)
				end
			end
		end)
	end

	if structure:IsA("BasePart") then
		bindPart(structure)
	end
	for _, part in ipairs(structure:GetDescendants()) do
		bindPart(part)
	end
end

for _, structure in ipairs(CollectionService:GetTagged("DestructibleStructure")) do
	setupDestructibleStructure(structure)
end
CollectionService:GetInstanceAddedSignal("DestructibleStructure"):Connect(setupDestructibleStructure)

return ArenaDestructionService
