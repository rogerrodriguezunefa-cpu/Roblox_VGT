local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local VehicleHealthService = {}

function VehicleHealthService.InitVehicle(vehicleModel: Model, maxHealth: number)
	vehicleModel:SetAttribute("MaxHealth", maxHealth)
	vehicleModel:SetAttribute("Health", maxHealth)
	vehicleModel:SetAttribute("IsDestroyed", false)
end

local function detachRandomPiece(vehicleModel: Model, impactPos: Vector3)
	local detachableFolder = vehicleModel:FindFirstChild("DetachableParts")
	if not detachableFolder then
		return
	end

	local pieces = detachableFolder:GetChildren()
	if #pieces == 0 then
		return
	end

	local chosenPiece = pieces[math.random(1, #pieces)]
	chosenPiece.Parent = Workspace

	local chassis = vehicleModel.PrimaryPart
	for _, item in ipairs(chosenPiece:GetDescendants()) do
		if item:IsA("WeldConstraint") or item:IsA("Motor6D") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = true
			item.Massless = false
			local pushDir = (item.Position - impactPos).Unit + Vector3.new(0, 1.2, 0)
			item:ApplyImpulse(pushDir * item.AssemblyMass * 35)
			item:ApplyAngularImpulse(Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15)))
		end
	end

	if chosenPiece:IsA("BasePart") then
		chosenPiece.Anchored = false
		chosenPiece.CanCollide = true
		chosenPiece.Massless = false
		for _, w in ipairs(chosenPiece:GetChildren()) do
			if w:IsA("WeldConstraint") then
				w:Destroy()
			end
		end
		if chassis then
			for _, w in ipairs(chassis:GetChildren()) do
				if w:IsA("WeldConstraint") and w.Part1 == chosenPiece then
					w:Destroy()
				end
			end
		end
		local away = chosenPiece.Position - impactPos
		local pushDir = (if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 1, 0)) + Vector3.new(0, 1.2, 0)
		chosenPiece:ApplyImpulse(pushDir * chosenPiece.AssemblyMass * 35)
	end

	Debris:AddItem(chosenPiece, 8)
end

local function explodeVehicle(vehicleModel: Model)
	if vehicleModel:GetAttribute("IsDestroyed") or vehicleModel:GetAttribute("Destroyed") then
		return
	end
	vehicleModel:SetAttribute("IsDestroyed", true)
	vehicleModel:SetAttribute("Destroyed", true)

	local chassis = vehicleModel.PrimaryPart
	local explosionPos = if chassis then chassis.Position else vehicleModel:GetPivot().Position

	local explosion = Instance.new("Explosion")
	explosion.Position = explosionPos
	explosion.BlastRadius = 24
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace

	for _, descendant in ipairs(vehicleModel:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("HingeConstraint") or descendant:IsA("CylindricalConstraint") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = true
			descendant.Massless = false
			local randomDir = Vector3.new(math.random(-10, 10), math.random(8, 20), math.random(-10, 10)).Unit
			descendant:ApplyImpulse(randomDir * descendant.AssemblyMass * math.random(40, 70))
		end
	end

	Debris:AddItem(vehicleModel, 10)
end

function VehicleHealthService.ApplyDamage(vehicleModel: Model, amount: number, impactPos: Vector3?, attackerPlayer: Player?)
	if vehicleModel:GetAttribute("IsDestroyed") or vehicleModel:GetAttribute("Destroyed") then
		return
	end

	local currentHealth = (vehicleModel:GetAttribute("Health") :: number?) or 100
	local newHealth = math.max(0, currentHealth - amount)
	local actualDamage = math.round(currentHealth - newHealth)

	if attackerPlayer then
		vehicleModel:SetAttribute("LastAttacker", attackerPlayer.Name)
		local ownerName = vehicleModel:GetAttribute("OwnerName") :: string?
		if actualDamage > 0 and ownerName ~= attackerPlayer.Name then
			local ls = attackerPlayer:FindFirstChild("leaderstats")
			local dmgStat = ls and ls:FindFirstChild("Daño") :: IntValue?
			if dmgStat then
				dmgStat.Value += actualDamage
			end
		end
	end

	vehicleModel:SetAttribute("Health", newHealth)

	local hitPoint = impactPos or vehicleModel:GetPivot().Position
	if newHealth > 0 and (currentHealth // 25) > (newHealth // 25) then
		detachRandomPiece(vehicleModel, hitPoint)
	end

	if newHealth <= 0 then
		explodeVehicle(vehicleModel)
	end
end

for _, vehicle in ipairs(CollectionService:GetTagged("CombatVehicle")) do
	if vehicle:IsA("Model") then
		VehicleHealthService.InitVehicle(vehicle, (vehicle:GetAttribute("MaxHealth") :: number?) or 100)
	end
end

return VehicleHealthService
