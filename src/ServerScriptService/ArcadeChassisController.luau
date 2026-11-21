--!strict
-- ServerScriptService/ArcadeChassisController.luau
-- Controlador de físicas arcade estilo Vigilante 8: suspensión por raycast, tracción, derrape y downforce.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type ChassisConfig = {
	SuspensionRestLength: number,
	SpringStiffness: number,
	SpringDamping: number,
	WheelRadius: number,
	MaxSpeed: number,
	Acceleration: number,
	TurnSpeed: number,
	LateralGrip: number,
	DriftGrip: number,
	Downforce: number,
}

local DEFAULT_CONFIG: ChassisConfig = {
	SuspensionRestLength = 2.6,
	SpringStiffness = 180,
	SpringDamping = 18,
	WheelRadius = 1.4,
	MaxSpeed = 95,
	Acceleration = 85,
	TurnSpeed = 2.4,
	LateralGrip = 0.88,
	DriftGrip = 0.22,
	Downforce = 35,
}

-- Perfiles calibrados por clase de vehículo de Vigilante 8
local VEHICLE_PRESETS: { [string]: ChassisConfig } = {
	-- Autos ligeros (muy ágiles y derrapan fácil)
	Strider = {
		SuspensionRestLength = 2.4, SpringStiffness = 175, SpringDamping = 18, WheelRadius = 1.35,
		MaxSpeed = 105, Acceleration = 92, TurnSpeed = 2.8, LateralGrip = 0.85, DriftGrip = 0.18, Downforce = 35,
	},
	Leprechaun = {
		SuspensionRestLength = 2.4, SpringStiffness = 175, SpringDamping = 18, WheelRadius = 1.35,
		MaxSpeed = 105, Acceleration = 92, TurnSpeed = 2.8, LateralGrip = 0.85, DriftGrip = 0.18, Downforce = 35,
	},
	Rattler = {
		SuspensionRestLength = 2.5, SpringStiffness = 180, SpringDamping = 18, WheelRadius = 1.4,
		MaxSpeed = 105, Acceleration = 90, TurnSpeed = 2.8, LateralGrip = 0.86, DriftGrip = 0.18, Downforce = 36,
	},
	-- Camionetas y 4x4 (suspensión alta para pasar sobre escombros)
	StagPickup = {
		SuspensionRestLength = 3.2, SpringStiffness = 220, SpringDamping = 20, WheelRadius = 1.55,
		MaxSpeed = 90, Acceleration = 82, TurnSpeed = 2.3, LateralGrip = 0.90, DriftGrip = 0.24, Downforce = 38,
	},
	Glenn4x4 = {
		SuspensionRestLength = 3.2, SpringStiffness = 220, SpringDamping = 20, WheelRadius = 1.55,
		MaxSpeed = 90, Acceleration = 82, TurnSpeed = 2.3, LateralGrip = 0.90, DriftGrip = 0.24, Downforce = 38,
	},
	Clydesdale = {
		SuspensionRestLength = 3.2, SpringStiffness = 220, SpringDamping = 20, WheelRadius = 1.55,
		MaxSpeed = 90, Acceleration = 82, TurnSpeed = 2.3, LateralGrip = 0.90, DriftGrip = 0.24, Downforce = 38,
	},
	-- Vehículos pesados (más lentos al girar, imparables al embestir)
	SchoolBus = {
		SuspensionRestLength = 2.9, SpringStiffness = 230, SpringDamping = 22, WheelRadius = 1.6,
		MaxSpeed = 78, Acceleration = 65, TurnSpeed = 1.9, LateralGrip = 0.95, DriftGrip = 0.30, Downforce = 45,
	},
	MothTruck = {
		SuspensionRestLength = 2.9, SpringStiffness = 230, SpringDamping = 22, WheelRadius = 1.6,
		MaxSpeed = 78, Acceleration = 65, TurnSpeed = 1.9, LateralGrip = 0.95, DriftGrip = 0.30, Downforce = 45,
	},
}

local ArcadeChassisController = {}

local function getConfigForVehicle(vehicle: Model): ChassisConfig
	local vType = vehicle:GetAttribute("VehicleType")
	if typeof(vType) == "string" and VEHICLE_PRESETS[vType] then
		return VEHICLE_PRESETS[vType]
	end
	return DEFAULT_CONFIG
end

function ArcadeChassisController.Attach(vehicle: Model, customConfig: ChassisConfig?): RBXScriptConnection?
	if vehicle:GetAttribute("ArcadeChassisAttached") then
		return nil
	end

	local chassis = vehicle:FindFirstChild("Chassis")
	if not chassis or not chassis:IsA("BasePart") then
		return nil
	end

	local seatInst = chassis:FindFirstChild("Seat") or vehicle:FindFirstChild("DriverSeat")
	if not seatInst or not seatInst:IsA("VehicleSeat") then
		return nil
	end
	local seat = seatInst :: VehicleSeat

	local wheelsFolder = vehicle:FindFirstChild("Wheels")
	if not wheelsFolder then
		return nil
	end

	local springFL = chassis:FindFirstChild("SpringFL")
	local springFR = chassis:FindFirstChild("SpringFR")
	local springRL = chassis:FindFirstChild("SpringRL")
	local springRR = chassis:FindFirstChild("SpringRR")
	local wheelFL = wheelsFolder:FindFirstChild("WheelFL")
	local wheelFR = wheelsFolder:FindFirstChild("WheelFR")
	local wheelRL = wheelsFolder:FindFirstChild("WheelRL")
	local wheelRR = wheelsFolder:FindFirstChild("WheelRR")

	if not (springFL and springFL:IsA("Attachment")
		and springFR and springFR:IsA("Attachment")
		and springRL and springRL:IsA("Attachment")
		and springRR and springRR:IsA("Attachment")
		and wheelFL and wheelFL:IsA("BasePart")
		and wheelFR and wheelFR:IsA("BasePart")
		and wheelRL and wheelRL:IsA("BasePart")
		and wheelRR and wheelRR:IsA("BasePart")) then
		return nil
	end

	vehicle:SetAttribute("ArcadeChassisAttached", true)
	local CONFIG = customConfig or getConfigForVehicle(vehicle)

	local corners = {
		{ name = "FL", att = springFL, wheel = wheelFL, isFront = true },
		{ name = "FR", att = springFR, wheel = wheelFR, isFront = true },
		{ name = "RL", att = springRL, wheel = wheelRL, isFront = false },
		{ name = "RR", att = springRR, wheel = wheelRR, isFront = false },
	}

	-- VectorForce central para aplicar fuerzas físicas limpias
	local centerAtt = Instance.new("Attachment")
	centerAtt.Name = "ArcadeCenterAttachment"
	centerAtt.Parent = chassis

	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "ArcadeDriveForce"
	driveForce.Attachment0 = centerAtt
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.ApplyAtCenterOfMass = true
	driveForce.Parent = chassis

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { vehicle }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local wheelSpinAngle = 0
	local currentSteer = 0
	local previousCompression = { FL = 0, FR = 0, RL = 0, RR = 0 }

	-- Asignar NetworkOwner al jugador que se suba para eliminar lag de controles
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if humanoid and humanoid.Parent then
			local player = Players:GetPlayerFromCharacter(humanoid.Parent)
			if player and chassis:CanSetNetworkOwnership() then
				chassis:SetNetworkOwner(player)
			end
		else
			if chassis:CanSetNetworkOwnership() then
				chassis:SetNetworkOwner(nil)
			end
		end
	end)

	-- Bucle principal de físicas (suspensión + motor + derrape)
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not vehicle.Parent or not chassis.Parent or dt <= 0 then
			heartbeatConn:Disconnect()
			return
		end

		local totalForce = Vector3.zero
		local groundedWheels = 0

		local throttle = seat.ThrottleFloat
		local steer = -seat.SteerFloat
		local isDrifting = seat:GetAttribute("IsDrifting") == true

		currentSteer += (steer * math.rad(32) - currentSteer) * math.clamp(dt * 12, 0, 1)

		local forwardDir = chassis.CFrame.LookVector
		local rightDir = chassis.CFrame.RightVector
		local upDir = chassis.CFrame.UpVector

		local velocity = chassis.AssemblyLinearVelocity
		local forwardSpeed = velocity:Dot(forwardDir)
		local lateralSpeed = velocity:Dot(rightDir)

		wheelSpinAngle -= (forwardSpeed * dt) / CONFIG.WheelRadius

		-- 1. Calcular suspensión en las 4 esquinas
		for _, corner in ipairs(corners) do
			local origin = corner.att.WorldPosition
			local rayDir = -upDir * (CONFIG.SuspensionRestLength + CONFIG.WheelRadius)
			local result = workspace:Raycast(origin, rayDir, rayParams)

			local wheelTargetPos: Vector3
			if result then
				groundedWheels += 1
				local distance = result.Distance - CONFIG.WheelRadius
				local compression = math.clamp(CONFIG.SuspensionRestLength - distance, 0, CONFIG.SuspensionRestLength)

				-- Ley de Hooke + Amortiguador: F = (k * x) + (d * dx/dt)
				local springVelocity = (compression - previousCompression[corner.name]) / dt
				local springForce = (compression * CONFIG.SpringStiffness) + (springVelocity * CONFIG.SpringDamping)
				previousCompression[corner.name] = compression

				local forceAtPoint = upDir * math.max(0, springForce) * chassis.AssemblyMass * 0.25
				chassis:ApplyImpulseAtPosition(forceAtPoint * dt, origin)

				wheelTargetPos = result.Position + (upDir * CONFIG.WheelRadius)
			else
				previousCompression[corner.name] = 0
				wheelTargetPos = origin - (upDir * CONFIG.SuspensionRestLength)
			end

			local steerAngle = if corner.isFront then currentSteer else 0
			corner.wheel.CFrame = CFrame.new(wheelTargetPos)
				* chassis.CFrame.Rotation
				* CFrame.Angles(0, steerAngle, 0)
				* CFrame.Angles(wheelSpinAngle, 0, 0)
		end

		-- 2. Tracción, derrape y giro (cuando al menos 2 ruedas tocan el suelo)
		if groundedWheels >= 2 then
			if math.abs(throttle) > 0.05 then
				if (throttle > 0 and forwardSpeed < CONFIG.MaxSpeed) or (throttle < 0 and forwardSpeed > -CONFIG.MaxSpeed * 0.5) then
					totalForce += forwardDir * (throttle * CONFIG.Acceleration * chassis.AssemblyMass)
				end
			else
				totalForce -= forwardDir * (forwardSpeed * 1.5 * chassis.AssemblyMass)
			end

			local activeGrip = if isDrifting then CONFIG.DriftGrip else CONFIG.LateralGrip
			local lateralFriction = -rightDir * (lateralSpeed * activeGrip * 12 * chassis.AssemblyMass)
			totalForce += lateralFriction

			if math.abs(forwardSpeed) > 3 then
				local reverseFactor = if forwardSpeed >= 0 then 1 else -1
				local driftTurnBoost = if isDrifting then 1.35 else 1.0
				local targetYawRate = steer * CONFIG.TurnSpeed * driftTurnBoost * reverseFactor

				local currentAngVel = chassis.AssemblyAngularVelocity
				chassis.AssemblyAngularVelocity = Vector3.new(
					currentAngVel.X * 0.9,
					targetYawRate,
					currentAngVel.Z * 0.9
				)
			end

			totalForce -= upDir * (CONFIG.Downforce * chassis.AssemblyMass)
		else
			-- Estabilización aérea
			chassis.AssemblyAngularVelocity *= 0.96
		end

		driveForce.Force = totalForce
	end)

	return heartbeatConn
end

return ArcadeChassisController
