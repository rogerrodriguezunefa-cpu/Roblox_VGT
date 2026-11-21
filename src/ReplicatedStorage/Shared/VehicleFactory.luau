local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent:WaitForChild("Config"))
local VehicleModels = require(script.Parent:WaitForChild("VehicleModels"))
local WeaponVisuals = require(script.Parent:WaitForChild("WeaponVisuals"))

local VehicleFactory = {}

local function weldParts(partA: BasePart, partB: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = partA
	weld.Part1 = partB
	weld.Parent = partA
	return weld
end

local function createPart(props: {
	Name: string,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	CanCollide: boolean?,
	Massless: boolean?,
	Transparency: number?,
	Parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.Plastic
	part.Shape = props.Shape or Enum.PartType.Block
	part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	part.Massless = if props.Massless ~= nil then props.Massless else false
	part.Transparency = props.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

function VehicleFactory.CreateCar(options: {
	Name: string?,
	Color: Color3?,
	CFrame: CFrame?,
	IsBot: boolean?,
	OwnerName: string?,
	VehicleType: string?,
}): Model
	local typeCfg = if options.VehicleType then Config.VEHICLE_TYPES[options.VehicleType] else nil
	local carColor = options.Color or (if typeCfg then typeCfg.Color else Color3.fromRGB(215, 65, 45))
	local maxHealth = if typeCfg then typeCfg.MaxHealth else Config.VEHICLE.MAX_HEALTH
	local maxSpeed = if typeCfg then typeCfg.MaxSpeed else Config.VEHICLE.MAX_SPEED
	local steerAngle = if typeCfg then typeCfg.SteerAngle else Config.VEHICLE.STEER_ANGLE
	local spawnCFrame = options.CFrame or CFrame.new(0, 6, 0)
	local isBot = options.IsBot == true

	local model = Instance.new("Model")
	model.Name = options.Name or (if isBot then "BotCar" else "PlayerCar")
	model:SetAttribute("IsVehicle", true)
	CollectionService:AddTag(model, "CombatVehicle")
	model:SetAttribute("IsBot", isBot)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("MaxSpeed", maxSpeed)
	model:SetAttribute("SteerAngle", steerAngle)
	model:SetAttribute("VehicleType", options.VehicleType or "Interceptor")
	model:SetAttribute("Turbo", Config.VEHICLE.TURBO_MAX)
	if options.OwnerName then
		model:SetAttribute("OwnerName", options.OwnerName)
	end

	local S = (typeCfg and typeCfg.Scale) or Config.VEHICLE.SCALE or 1.35
	model:SetAttribute("VehicleScale", S)

	-- Chasis principal (el frente apunta hacia -Z)
	local chassis = createPart({
		Name = "Chassis",
		Size = Vector3.new(6.0, 1.8, 14) * S,
		Color = carColor,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	chassis.CFrame = spawnCFrame
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.5, 0.3, 0.1, 1, 1)
	model.PrimaryPart = chassis

	-- Puntos de anclaje (Attachments) para armas modulares
	local mountPoints = {
		{ Name = "RoofMount", Pos = Vector3.new(0, 3.0, 1.2) * S },
		{ Name = "LeftSideMount", Pos = Vector3.new(-4.8, 1.2, 0.5) * S },
		{ Name = "RightSideMount", Pos = Vector3.new(4.8, 1.2, 0.5) * S },
		{ Name = "FrontMount", Pos = Vector3.new(0, 1.5, -6.5) * S },
		{ Name = "RearMount", Pos = Vector3.new(0, 0.6, 7.5) * S },
		-- Puntos de suspensión en las 4 esquinas inferiores del Chassis
		{ Name = "SpringFL", Pos = Vector3.new(-3.85, -0.9, -4.4) * S },
		{ Name = "SpringFR", Pos = Vector3.new(3.85, -0.9, -4.4) * S },
		{ Name = "SpringRL", Pos = Vector3.new(-3.85, -0.9, 4.4) * S },
		{ Name = "SpringRR", Pos = Vector3.new(3.85, -0.9, 4.4) * S },
	}
	for _, mp in ipairs(mountPoints) do
		local att = Instance.new("Attachment")
		att.Name = mp.Name
		att.Position = mp.Pos
		att.Parent = chassis
	end

	-- Lastre inferior invisible para bajar el centro de gravedad (conducción arcade estable)
	local ballast = createPart({
		Name = "Ballast",
		Size = Vector3.new(5, 0.8, 10) * S,
		Color = Color3.fromRGB(30, 30, 30),
		CanCollide = false,
		Transparency = 1,
		Parent = model,
	})
	ballast.CFrame = chassis.CFrame * CFrame.new(0, -1.2 * S, 0)
	ballast.CustomPhysicalProperties = PhysicalProperties.new(5.0, 0.3, 0.1)
	weldParts(chassis, ballast)

	-- Carrocería LEGO única para cada uno de los 13 vehículos
	VehicleModels.Build(options.VehicleType or "Rattler", model, chassis, carColor)

	local detachableFolder = Instance.new("Folder")
	detachableFolder.Name = "DetachableParts"
	detachableFolder.Parent = model

	if options.VehicleType ~= "LuxoSaucer" then
		-- Parachoques delantero blindado
		local bumper = createPart({
			Name = "FrontBumper",
			Size = Vector3.new(9.2, 1.2, 1.0) * S,
			Color = Color3.fromRGB(55, 55, 60),
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
			Massless = true,
			Parent = detachableFolder,
		})
		bumper.CFrame = chassis.CFrame * CFrame.new(0, -0.3 * S, -7.2 * S)
		weldParts(chassis, bumper)

		-- Faros delanteros (indican claramente el frente del auto)
		for _, xOffset in ipairs({ -2.4 * S, 2.4 * S }) do
			local headlight = createPart({
				Name = "Headlight",
				Size = Vector3.new(1.1, 0.6, 0.3) * S,
				Color = Color3.fromRGB(255, 240, 180),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Massless = true,
				Parent = detachableFolder,
			})
			headlight.CFrame = chassis.CFrame * CFrame.new(xOffset, 0.2 * S, -7.05 * S)
			weldParts(chassis, headlight)

			local taillight = createPart({
				Name = "Taillight",
				Size = Vector3.new(1.3, 0.5, 0.3) * S,
				Color = Color3.fromRGB(220, 35, 35),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Massless = true,
				Parent = detachableFolder,
			})
			taillight.CFrame = chassis.CFrame * CFrame.new(xOffset, 0.2 * S, 7.05 * S)
			weldParts(chassis, taillight)
		end
	end

	-- Base de torreta en el techo (lista para las armas de la Fase 2)
	local turretBase = createPart({
		Name = "TurretBase",
		Size = Vector3.new(1.8, 0.5, 1.8) * S,
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.Metal,
		CanCollide = false,
		Massless = true,
		Parent = detachableFolder,
	})
	turretBase.CFrame = chassis.CFrame * CFrame.new(0, 3.0 * S, 1.4 * S)
	weldParts(chassis, turretBase)

	-- Cañones dobles de ametralladora sobre el capó
	for _, xOffset in ipairs({ -1.6 * S, 1.6 * S }) do
		local barrel = createPart({
			Name = if xOffset < 0 then "GunBarrelL" else "GunBarrelR",
			Size = Vector3.new(0.45, 0.45, 2.6) * S,
			Color = Color3.fromRGB(35, 35, 40),
			Material = Enum.Material.Metal,
			CanCollide = false,
			Massless = true,
			Parent = model,
		})
		barrel.CFrame = chassis.CFrame * CFrame.new(xOffset, 1.15 * S, -4.6 * S)
		weldParts(chassis, barrel)
	end

	-- Asiento del conductor (dentro de la cabina)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = maxSpeed
	seat.Torque = Config.VEHICLE.TORQUE
	seat.TurnSpeed = Config.VEHICLE.STEER_SPEED
	seat.CFrame = chassis.CFrame * CFrame.new(0, 0.45 * S, 1.0 * S)
	seat.Parent = model
	weldParts(chassis, seat)

	if not isBot then
		local enterPrompt = Instance.new("ProximityPrompt")
		enterPrompt.Name = "EnterPrompt"
		enterPrompt.ActionText = "Subir al auto"
		enterPrompt.ObjectText = options.OwnerName or "Vehículo"
		enterPrompt.KeyboardKeyCode = Enum.KeyCode.E
		enterPrompt.HoldDuration = 0
		enterPrompt.MaxActivationDistance = 14
		enterPrompt.RequiresLineOfSight = false
		enterPrompt.Parent = chassis
	end

	-- Carpeta para guardar referencias a motores y dirección
	local driveMotors = Instance.new("Folder")
	driveMotors.Name = "DriveMotors"
	driveMotors.Parent = model

	local steerServos = Instance.new("Folder")
	steerServos.Name = "SteerServos"
	steerServos.Parent = model

	-- Configuración de las 4 ruedas (metidas dentro de los guardabarros)
	local wheelConfigs = {
		{ Name = "WheelFL", Offset = Vector3.new(-3.85, -1.0, -4.4) * S, Steer = true },
		{ Name = "WheelFR", Offset = Vector3.new(3.85, -1.0, -4.4) * S, Steer = true },
		{ Name = "WheelRL", Offset = Vector3.new(-3.85, -1.0, 4.4) * S, Steer = false },
		{ Name = "WheelRR", Offset = Vector3.new(3.85, -1.0, 4.4) * S, Steer = false },
	}

	local wheelPhysics = PhysicalProperties.new(2.5, 2.0, 0.0, 10.0, 1.0)

	for _, wCfg in ipairs(wheelConfigs) do
		local isSaucer = options.VehicleType == "LuxoSaucer"
		local wheel = createPart({
			Name = wCfg.Name,
			Size = Vector3.new(1.2, 3.0, 3.0) * S,
			Color = Color3.fromRGB(28, 28, 30),
			Material = Enum.Material.Rubber,
			Shape = Enum.PartType.Cylinder,
			Transparency = if isSaucer then 1 else 0,
			Parent = model,
		})
		wheel.CFrame = chassis.CFrame * CFrame.new(wCfg.Offset)
		wheel.CustomPhysicalProperties = wheelPhysics

		local rim = createPart({
			Name = wCfg.Name .. "_Rim",
			Size = Vector3.new(1.28, 1.95, 1.95) * S,
			Color = Color3.fromRGB(140, 145, 152),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Massless = true,
			Transparency = if isSaucer then 1 else 0,
			Parent = model,
		})
		rim.CFrame = wheel.CFrame
		weldParts(wheel, rim)

		-- Evitar que la rueda choque con el chasis
		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = chassis
		noCollide.Part1 = wheel
		noCollide.Parent = wheel

		local wheelAtt = Instance.new("Attachment")
		wheelAtt.Name = "WheelAttachment"
		wheelAtt.Parent = wheel

		local motorHinge = Instance.new("HingeConstraint")
		motorHinge.Name = wCfg.Name .. "_Motor"
		motorHinge.ActuatorType = Enum.ActuatorType.Motor
		motorHinge.MotorMaxTorque = Config.VEHICLE.TORQUE
		motorHinge.AngularVelocity = 0

		if wCfg.Steer then
			-- Mangueta de dirección invisible (masa equilibrada para evitar vibración en las ruedas)
			local knuckle = createPart({
				Name = wCfg.Name .. "_Knuckle",
				Size = Vector3.new(1.8, 1.8, 1.8) * S,
				Color = Color3.fromRGB(80, 80, 80),
				CanCollide = false,
				Transparency = 1,
				Parent = model,
			})
			knuckle.CFrame = wheel.CFrame
			knuckle.CustomPhysicalProperties = PhysicalProperties.new(6.0, 0.3, 0.1)

			local chassisSteerAtt = Instance.new("Attachment")
			chassisSteerAtt.Position = wCfg.Offset
			chassisSteerAtt.Axis = Vector3.new(0, 1, 0)
			chassisSteerAtt.SecondaryAxis = Vector3.new(0, 0, -1)
			chassisSteerAtt.Parent = chassis

			local knuckleSteerAtt = Instance.new("Attachment")
			knuckleSteerAtt.Axis = Vector3.new(0, 1, 0)
			knuckleSteerAtt.SecondaryAxis = Vector3.new(0, 0, -1)
			knuckleSteerAtt.Parent = knuckle

			local steerHinge = Instance.new("HingeConstraint")
			steerHinge.Name = wCfg.Name .. "_Steer"
			steerHinge.Attachment0 = chassisSteerAtt
			steerHinge.Attachment1 = knuckleSteerAtt
			steerHinge.ActuatorType = Enum.ActuatorType.Servo
			steerHinge.ServoMaxTorque = 10000000
			steerHinge.AngularSpeed = Config.VEHICLE.STEER_SPEED
			steerHinge.LimitsEnabled = true
			steerHinge.LowerAngle = -steerAngle
			steerHinge.UpperAngle = steerAngle
			steerHinge.Parent = steerServos

			local knuckleMotorAtt = Instance.new("Attachment")
			knuckleMotorAtt.Parent = knuckle

			motorHinge.Attachment0 = knuckleMotorAtt
			motorHinge.Attachment1 = wheelAtt
			motorHinge.Parent = driveMotors
		else
			local chassisAtt = Instance.new("Attachment")
			chassisAtt.Position = wCfg.Offset
			chassisAtt.Parent = chassis

			motorHinge.Attachment0 = chassisAtt
			motorHinge.Attachment1 = wheelAtt
			motorHinge.Parent = driveMotors
		end
	end

	-- Barra de vida flotante para Bots (útil para identificarlos y probar daño)
	if isBot then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "BotHealthGui"
		billboard.Size = UDim2.new(0, 110, 0, 28)
		billboard.StudsOffset = Vector3.new(0, 5.8, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = chassis
		billboard.Parent = model

		local bg = Instance.new("Frame")
		bg.Name = "Bg"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		bg.BackgroundTransparency = 0.2
		bg.BorderSizePixel = 0
		bg.Parent = billboard

		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 4)
		bgCorner.Parent = bg

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(75, 210, 95)
		fill.BorderSizePixel = 0
		fill.Parent = bg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 4)
		fillCorner.Parent = fill

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.3
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = "BOT 100"
		label.ZIndex = 2
		label.Parent = bg
	end

	-- Efectos visuales de daño en el capó (humo <= 50% HP, fuego <= 25% HP)
	local hoodSmoke = Instance.new("Smoke")
	hoodSmoke.Name = "DamageSmoke"
	hoodSmoke.Enabled = false
	hoodSmoke.Opacity = 0.45
	hoodSmoke.RiseVelocity = 6
	hoodSmoke.Size = 3.5
	hoodSmoke.Color = Color3.fromRGB(160, 160, 165)
	hoodSmoke.Parent = chassis

	local hoodFire = Instance.new("Fire")
	hoodFire.Name = "DamageFire"
	hoodFire.Enabled = false
	hoodFire.Heat = 4
	hoodFire.Size = 4
	hoodFire.Parent = chassis

	model:GetAttributeChangedSignal("Health"):Connect(function()
		local hp = (model:GetAttribute("Health") :: number?) or maxHealth
		local ratio = hp / math.max(1, maxHealth)
		if ratio <= 0 then
			hoodSmoke.Enabled = true
			hoodSmoke.Color = Color3.fromRGB(45, 45, 45)
			hoodFire.Enabled = true
		elseif ratio <= 0.25 then
			hoodSmoke.Enabled = true
			hoodSmoke.Color = Color3.fromRGB(60, 60, 65)
			hoodFire.Enabled = true
		elseif ratio <= 0.5 then
			hoodSmoke.Enabled = true
			hoodSmoke.Color = Color3.fromRGB(170, 170, 175)
			hoodFire.Enabled = false
		else
			hoodSmoke.Enabled = false
			hoodFire.Enabled = false
		end
	end)

	-- Actualizar armas 3D montadas cuando el auto recoge o gasta armamento del mapa
	local weaponAttrs = {
		"Slot1Weapon", "Slot1Ammo",
		"Slot2Weapon", "Slot2Ammo",
		"Slot3Weapon", "Slot3Ammo",
		"ExclusiveSpecialAmmo",
	}
	for _, attr in ipairs(weaponAttrs) do
		model:GetAttributeChangedSignal(attr):Connect(function()
			WeaponVisuals.Refresh(model)
		end)
	end

	return model
end

return VehicleFactory
