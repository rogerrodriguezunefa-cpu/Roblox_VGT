local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DestructionSystem = {}

local function getRootDestructible(inst: Instance): BasePart?
	local cur: Instance? = inst
	while cur and cur ~= Workspace do
		if cur:IsA("BasePart") and (CollectionService:HasTag(cur, "Destructible") or CollectionService:HasTag(cur, "ChainTank")) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function shatterPart(part: BasePart, originPos: Vector3)
	if part:GetAttribute("Destroyed") then
		return
	end
	part:SetAttribute("Destroyed", true)
	part.Anchored = false
	part:BreakJoints()

	local dir = (part.Position - originPos)
	local pushDir = if dir.Magnitude > 0.1 then (dir.Unit + Vector3.new(0, 0.6, 0)).Unit else Vector3.new(0, 1, 0)
	part:ApplyImpulse(pushDir * part.AssemblyMass * 55)

	Debris:AddItem(part, 4.0)
end

function DestructionSystem.DetonateChain(center: Vector3, radius: number, damage: number, attacker: Player?)
	local exp = Instance.new("Explosion")
	exp.Position = center
	exp.BlastRadius = radius
	exp.BlastPressure = 0
	exp.DestroyJointRadiusPercent = 0
	exp.Parent = Workspace

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}

	local partsInRadius = Workspace:GetPartBoundsInRadius(center, radius + 4, params)
	local damagedCars: { [Model]: boolean } = {}
	local damageEvent = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?

	for _, hitPart in ipairs(partsInRadius) do
		-- Dañar vehículos cercanos una sola vez por explosión
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("IsVehicle") and not model:GetAttribute("Destroyed") and not damagedCars[model] then
			damagedCars[model] = true
			if damageEvent then
				damageEvent:Fire(model, damage)
			end
		end

		-- Reacción en cadena en tanques y estructuras destructibles
		if CollectionService:HasTag(hitPart, "ChainTank") and not hitPart:GetAttribute("Destroyed") then
			task.delay(0.15, function()
				if hitPart.Parent and not hitPart:GetAttribute("Destroyed") then
					shatterPart(hitPart, center)
					DestructionSystem.DetonateChain(hitPart.Position, radius, damage, attacker)
				end
			end)
		elseif CollectionService:HasTag(hitPart, "Destructible") and not hitPart:GetAttribute("Destroyed") then
			DestructionSystem.Damage(hitPart, damage, attacker, center)
		end
	end
end

function DestructionSystem.Damage(instance: Instance, amount: number, attacker: Player?, impactPos: Vector3?): boolean
	local target = getRootDestructible(instance)
	if not target or target:GetAttribute("Destroyed") then
		return false
	end

	local hp = (target:GetAttribute("Health") :: number?) or 40
	local newHp = math.max(0, hp - amount)
	target:SetAttribute("Health", newHp)

	if newHp <= 0 then
		local center = impactPos or target.Position
		shatterPart(target, center)
		if CollectionService:HasTag(target, "ChainTank") then
			DestructionSystem.DetonateChain(target.Position, 26, 45, attacker)
		end
	end

	return true
end

return DestructionSystem
