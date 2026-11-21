local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local VehicleDamageFX = {}

local PROTECTED_NAMES = {
	Chassis = true,
	Ballast = true,
	DriverSeat = true,
	WheelFL = true,
	WheelFR = true,
	WheelRL = true,
	WheelRR = true,
	WheelFL_Knuckle = true,
	WheelFR_Knuckle = true,
	WheelFL_Rim = true,
	WheelFR_Rim = true,
	WheelRL_Rim = true,
	WheelRR_Rim = true,
	GunBarrelL = true,
	GunBarrelR = true,
}

local function detachPart(car: Model, part: BasePart, originPos: Vector3)
	if part:GetAttribute("Detached") or not part.Parent then
		return
	end
	part:SetAttribute("Detached", true)

	-- Romper WeldConstraints propios o en el chasis que sujeten esta pieza
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	local chassis = car.PrimaryPart
	if chassis then
		for _, child in ipairs(chassis:GetChildren()) do
			if child:IsA("WeldConstraint") and child.Part1 == part then
				child:Destroy()
			end
		end
	end

	part.Parent = Workspace
	part.Massless = false
	part.CanCollide = true
	part.CanQuery = false

	local away = part.Position - originPos
	local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5).Unit
	local launchDir = (dir + Vector3.new(0, 0.75, 0)).Unit

	part:ApplyImpulse(launchDir * part.AssemblyMass * 42)
	part:ApplyAngularImpulse(Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15)) * part.AssemblyMass)

	Debris:AddItem(part, 4.0)
end

local function collectDetachableParts(car: Model): { BasePart }
	local list: { BasePart } = {}
	for _, desc in ipairs(car:GetDescendants()) do
		if desc:IsA("BasePart") and not PROTECTED_NAMES[desc.Name] and not desc:GetAttribute("Detached") then
			table.insert(list, desc)
		end
	end
	return list
end

function VehicleDamageFX.OnDamaged(car: Model, hpRatio: number)
	local chassis = car.PrimaryPart
	if not chassis then
		return
	end

	local stage = (car:GetAttribute("DamageStage") :: number?) or 0
	local targetStage = 0
	if hpRatio <= 0.25 then
		targetStage = 3
	elseif hpRatio <= 0.45 then
		targetStage = 2
	elseif hpRatio <= 0.70 then
		targetStage = 1
	end

	if targetStage <= stage then
		return
	end
	car:SetAttribute("DamageStage", targetStage)

	if targetStage == 3 then
		-- Mini-explosión visual al entrar en daño crítico (<= 25% HP)
		local critExp = Instance.new("Explosion")
		critExp.Position = chassis.Position
		critExp.BlastRadius = 8
		critExp.BlastPressure = 0
		critExp.DestroyJointRadiusPercent = 0
		critExp.Parent = Workspace
	end

	local candidates = collectDetachableParts(car)
	local toDetach = math.min(#candidates, 2)
	for _ = 1, toDetach do
		local idx = math.random(1, #candidates)
		local p = table.remove(candidates, idx)
		if p then
			detachPart(car, p, chassis.Position)
		end
	end
end

function VehicleDamageFX.OnDestroyed(car: Model)
	local chassis = car.PrimaryPart
	local origin = if chassis then chassis.Position else car:GetPivot().Position
	local candidates = collectDetachableParts(car)
	local count = math.min(#candidates, 8)
	for i = 1, count do
		detachPart(car, candidates[i], origin)
	end
end

return VehicleDamageFX
