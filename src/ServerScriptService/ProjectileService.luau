--!strict
-- ServerScriptService/ProjectileService.luau
-- Controla el lanzamiento, persecución, rebote y detonación de proyectiles físicos.

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProjectileModels = ReplicatedStorage:WaitForChild("ProjectileModels")
local VehicleHealthService = require(ServerScriptService:WaitForChild("VehicleHealthService"))
local ArenaDestructionService = require(ServerScriptService:WaitForChild("ArenaDestructionService"))

local ProjectileService = {}

-- Crea un modelo de bloques de respaldo si aún no existe el modelo personalizado en Studio
local function getOrCreateProjectileTemplate(modelName: string): Instance
	local existing = ProjectileModels:FindFirstChild(modelName)
	if existing then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = modelName
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if modelName == "HomingMissile" then
		part.Size = Vector3.new(0.8, 0.8, 2.8)
		part.Color = Color3.fromRGB(245, 195, 50)
		part.Material = Enum.Material.Metal

		local trail = Instance.new("Trail")
		trail.Lifetime = 0.4
		trail.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25, 1.3)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25, 1.3)
		a1.Parent = part
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Parent = part
	elseif modelName == "BouncingTire" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(1.5, 4.2, 4.2)
		part.Color = Color3.fromRGB(32, 34, 38)
		part.Material = Enum.Material.Rubber
	else -- Landmine
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.6, 3.2, 3.2)
		part.Color = Color3.fromRGB(55, 58, 62)
		part.Material = Enum.Material.Metal
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 45, 45)
		light.Range = 10
		light.Brightness = 2
		light.Parent = part
	end

	return part
end

-- Helper para obtener el modelo de vehículo desde cualquier pieza tocada
local function getVehicleFromPart(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:HasTag("CombatVehicle") then
		return model
	end
	return nil
end

-- Helper para explosión y daño en área
local function detonateProjectile(position: Vector3, radius: number, maxDamage: number, attackerVehicle: Model?, attackerPlayer: Player?)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 0 -- Manejamos el daño manualmente con VehicleHealthService
	explosion.BlastPressure = 400000
	explosion.DestroyJointRadiusPercent = 0 -- Evitar que destruya autos de golpe sin usar VehicleHealthService
	explosion.Parent = workspace

	-- Buscar vehículos dentro del radio de explosión y dañar estructuras destructibles
	ArenaDestructionService.DamageStructuresInRadius(position, radius, maxDamage)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	if attackerVehicle then
		overlapParams.FilterDescendantsInstances = { attackerVehicle }
	end

	local hitParts = workspace:GetPartBoundsInRadius(position, radius, overlapParams)
	local damagedVehicles: { [Model]: boolean } = {}

	for _, part in ipairs(hitParts) do
		local vehicle = getVehicleFromPart(part)
		if vehicle and not damagedVehicles[vehicle] then
			damagedVehicles[vehicle] = true

			local targetRoot = vehicle.PrimaryPart or part
			local distance = (targetRoot.Position - position).Magnitude
			local falloff = math.clamp(1 - (distance / radius), 0.25, 1)
			local finalDamage = math.round(maxDamage * falloff)

			VehicleHealthService.ApplyDamage(vehicle, finalDamage, position, attackerPlayer)
		end
	end
end

-- 1. MISIL TELEDIRIGIDO (Interceptor Missiles / Scatter Missiles)
function ProjectileService.SpawnHomingMissile(originCFrame: CFrame, targetVehicle: Model?, attackerVehicle: Model, attackerPlayer: Player?, speed: number, damage: number)
	local template = getOrCreateProjectileTemplate("HomingMissile")
	local missile = template:Clone() :: BasePart
	if missile:IsA("Model") then
		missile = missile.PrimaryPart :: BasePart
	end

	missile.CFrame = originCFrame
	missile.CanCollide = false
	missile.Anchored = false
	missile.Massless = true
	missile.Parent = workspace

	-- Física de vuelo constante
	local attachment = Instance.new("Attachment")
	attachment.Parent = missile

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = math.huge
	linearVelocity.VectorVelocity = originCFrame.LookVector * speed
	linearVelocity.Parent = missile

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.MaxTorque = math.huge
	alignOrientation.Responsiveness = 15 -- Qué tan rápido gira hacia el objetivo
	alignOrientation.CFrame = originCFrame
	alignOrientation.Parent = missile

	local hasDetonated = false
	local startTime = os.clock()

	-- Bucle de persecución
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if hasDetonated or not missile.Parent then
			connection:Disconnect()
			return
		end

		-- Expirar después de 4 segundos
		if os.clock() - startTime > 4 then
			hasDetonated = true
			connection:Disconnect()
			detonateProjectile(missile.Position, 15, damage, attackerVehicle, attackerPlayer)
			missile:Destroy()
			return
		end

		-- Actualizar dirección hacia el objetivo si sigue vivo
		if targetVehicle and targetVehicle.PrimaryPart and (targetVehicle:GetAttribute("Health") or 0) > 0 then
			local targetPos = targetVehicle.PrimaryPart.Position
			local direction = (targetPos - missile.Position).Unit
			local lookCFrame = CFrame.lookAt(missile.Position, targetPos)

			alignOrientation.CFrame = lookCFrame
			linearVelocity.VectorVelocity = direction * speed
		end
	end)

	-- Detectar impacto
	missile.Touched:Connect(function(hitPart)
		if hasDetonated then return end
		if hitPart:IsDescendantOf(attackerVehicle) or not hitPart.CanCollide then return end

		hasDetonated = true
		connection:Disconnect()
		detonateProjectile(missile.Position, 16, damage, attackerVehicle, attackerPlayer)
		missile:Destroy()
	end)

	Debris:AddItem(missile, 4.5)
end

-- 2. NEUMÁTICO REBOTADOR (Steel Belted - Especial de Moth Truck)
function ProjectileService.SpawnBouncingTire(originCFrame: CFrame, attackerVehicle: Model, attackerPlayer: Player?, speed: number, damage: number)
	local template = getOrCreateProjectileTemplate("BouncingTire")
	local tire = template:Clone() :: BasePart
	if tire:IsA("Model") then
		tire = tire.PrimaryPart :: BasePart
	end

	tire.CFrame = originCFrame
	tire.CanCollide = true
	tire.Anchored = false

	-- Propiedades físicas para que rebote fuertemente por toda la arena
	tire.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 1.0, 1, 1) -- Elasticity = 1.0 (rebote máximo)
	tire.Parent = workspace

	-- Impulso inicial hacia adelante
	tire.AssemblyLinearVelocity = originCFrame.LookVector * speed + Vector3.new(0, 15, 0)
	tire.AssemblyAngularVelocity = originCFrame.RightVector * -25 -- Efecto visual de giro

	local bounces = 0
	local maxBounces = 5
	local hasDetonated = false

	tire.Touched:Connect(function(hitPart)
		if hasDetonated then return end
		if hitPart:IsDescendantOf(attackerVehicle) then return end

		local hitVehicle = getVehicleFromPart(hitPart)
		if hitVehicle then
			-- Si golpea a un enemigo, explota de inmediato
			hasDetonated = true
			detonateProjectile(tire.Position, 20, damage, attackerVehicle, attackerPlayer)
			tire:Destroy()
		elseif hitPart.CanCollide then
			-- Si choca contra pared o suelo, cuenta un rebote
			bounces += 1
			if bounces >= maxBounces then
				hasDetonated = true
				detonateProjectile(tire.Position, 18, damage, attackerVehicle, attackerPlayer)
				tire:Destroy()
			end
		end
	end)

	-- Explotar tras 6 segundos si no chocó con nada
	task.delay(6, function()
		if not hasDetonated and tire.Parent then
			hasDetonated = true
			detonateProjectile(tire.Position, 18, damage, attackerVehicle, attackerPlayer)
			tire:Destroy()
		end
	end)
end

-- 3. MINA TERRESTRE (Roadkill Mines)
function ProjectileService.DropMine(dropPosition: Vector3, attackerVehicle: Model, attackerPlayer: Player?, damage: number)
	local template = getOrCreateProjectileTemplate("Landmine")
	local mine = template:Clone() :: BasePart
	if mine:IsA("Model") then
		mine = mine.PrimaryPart :: BasePart
	end

	mine.Position = dropPosition
	mine.Anchored = true
	mine.CanCollide = false
	mine.Parent = workspace

	local isArmed = false
	local hasDetonated = false

	-- Retardo de 1 segundo para no explotarle al auto que la acaba de soltar
	task.delay(1, function()
		if mine.Parent then
			isArmed = true
		end
	end)

	mine.Touched:Connect(function(hitPart)
		if not isArmed or hasDetonated then return end
		if hitPart:IsDescendantOf(attackerVehicle) then return end

		local hitVehicle = getVehicleFromPart(hitPart)
		if hitVehicle then
			hasDetonated = true
			detonateProjectile(mine.Position, 22, damage, attackerVehicle, attackerPlayer)
			mine:Destroy()
		end
	end)

	-- Las minas desaparecen tras 45 segundos para no saturar la arena
	Debris:AddItem(mine, 45)
end

return ProjectileService
