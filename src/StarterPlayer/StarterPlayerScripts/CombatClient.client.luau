local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireWeaponEvent = Remotes:WaitForChild("FireWeapon") :: RemoteEvent
local WeaponVFXEvent = Remotes:WaitForChild("WeaponVFX") :: RemoteEvent

local LOCK_RANGE = 250
local LOCK_ANGLE = 0.82
local currentTarget: Model? = nil

local function getPlayerVehicle(): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		return humanoid.SeatPart:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function findLockOnTarget(myVehicle: Model): Model?
	local camera = Workspace.CurrentCamera
	local myChassis = myVehicle.PrimaryPart
	if not myChassis or not camera then
		return nil
	end

	local bestTarget: Model? = nil
	local bestScore = -1
	local camLook = camera.CFrame.LookVector

	for _, vehicle in ipairs(CollectionService:GetTagged("CombatVehicle")) do
		if vehicle:IsA("Model") and vehicle ~= myVehicle and vehicle.PrimaryPart and (vehicle:GetAttribute("Health") or 0) > 0 then
			local toTarget = vehicle.PrimaryPart.Position - camera.CFrame.Position
			local distance = toTarget.Magnitude
			if distance <= LOCK_RANGE and distance > 1 then
				local dot = camLook:Dot(toTarget.Unit)
				if dot >= LOCK_ANGLE and dot > bestScore then
					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = { myVehicle }
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					local result = Workspace:Raycast(camera.CFrame.Position, toTarget, rayParams)
					if result and result.Instance:IsDescendantOf(vehicle) then
						bestScore = dot
						bestTarget = vehicle
					end
				end
			end
		end
	end

	return bestTarget
end

RunService.RenderStepped:Connect(function()
	local myVehicle = getPlayerVehicle()
	if not myVehicle then
		currentTarget = nil
		return
	end
	currentTarget = findLockOnTarget(myVehicle)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local myVehicle = getPlayerVehicle()
	if not myVehicle then
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		FireWeaponEvent:FireServer("RoofMount", currentTarget)
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Space then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat:IsA("VehicleSeat") then
			seat:SetAttribute("IsDrifting", true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Space then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat:IsA("VehicleSeat") then
			seat:SetAttribute("IsDrifting", false)
		end
	end
end)

-- Renderizar efectos visuales rápidos (Beams) replicados desde el servidor
WeaponVFXEvent.OnClientEvent:Connect(function(originPos: Vector3, hitPos: Vector3, _weaponId: string?)
	if typeof(originPos) ~= "Vector3" or typeof(hitPos) ~= "Vector3" then
		return
	end
	local p0 = Instance.new("Part")
	p0.Anchored, p0.CanCollide, p0.CanQuery, p0.Transparency = true, false, false, 1
	p0.Position = originPos
	p0.Parent = Workspace

	local p1 = p0:Clone()
	p1.Position = hitPos
	p1.Parent = Workspace

	local a0 = Instance.new("Attachment", p0)
	local a1 = Instance.new("Attachment", p1)

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.Color = ColorSequence.new(Color3.fromRGB(0, 220, 255))
	beam.FaceCamera = true
	beam.Parent = p0

	task.delay(0.15, function()
		p0:Destroy()
		p1:Destroy()
	end)
end)
