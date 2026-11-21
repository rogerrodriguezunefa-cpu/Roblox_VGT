local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local buildArenaEvent = Instance.new("BindableEvent")
buildArenaEvent.Name = "BuildArenaEvent"
buildArenaEvent.Parent = ServerScriptService

local arenaToken = 0

local function createBlock(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Transparency: number?,
	Parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.Concrete
	part.Anchored = if props.Anchored ~= nil then props.Anchored else true
	part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	part.Transparency = props.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function createRamp(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, material: Enum.Material?): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material or Enum.Material.Concrete
	wedge.Anchored = true
	wedge.Parent = parent
	return wedge
end

local function createExplosiveBarrel(pos: Vector3, parent: Instance, sizeScale: number?, color: Color3?)
	local sc = sizeScale or 1
	local barrel = Instance.new("Part")
	barrel.Name = "ExplosiveBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(4.4 * sc, 3.0 * sc, 3.0 * sc)
	barrel.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	barrel.Anchored = true
	barrel.Material = Enum.Material.Metal
	barrel.Color = color or Color3.fromRGB(215, 45, 35)
	barrel:SetAttribute("IsExplosiveBarrel", true)
	barrel:SetAttribute("Detonated", false)
	barrel.Parent = parent

	local stripe = Instance.new("Part")
	stripe.Name = "WarningStripe"
	stripe.Shape = Enum.PartType.Cylinder
	stripe.Size = Vector3.new(0.8 * sc, 3.08 * sc, 3.08 * sc)
	stripe.CFrame = barrel.CFrame
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.Material = Enum.Material.Neon
	stripe.Color = Color3.fromRGB(255, 195, 35)
	stripe.Parent = barrel

	local function detonate()
		if not barrel.Parent or barrel.Transparency >= 1 then
			return
		end
		barrel:SetAttribute("Detonated", true)
		barrel.Transparency = 1
		barrel.CanCollide = false
		barrel.CanQuery = false
		stripe.Transparency = 1

		local exp = Instance.new("Explosion")
		exp.Position = barrel.Position
		exp.BlastRadius = 22 * sc
		exp.BlastPressure = 0
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = Workspace

		local damageEvent = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?
		local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
		if damageEvent and vehiclesFolder then
			for _, car in ipairs(vehiclesFolder:GetChildren()) do
				if car:IsA("Model") and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
					if car.PrimaryPart and (car.PrimaryPart.Position - barrel.Position).Magnitude <= 24 * sc then
						damageEvent:Fire(car, 50)
					end
				end
			end
		end

		for _, obj in ipairs(parent:GetChildren()) do
			if obj:IsA("BasePart") and obj ~= barrel and obj:GetAttribute("IsExplosiveBarrel") and not obj:GetAttribute("Detonated") then
				if (obj.Position - barrel.Position).Magnitude <= 24 * sc then
					task.delay(0.12, function()
						if obj.Parent then
							obj:SetAttribute("Detonated", true)
						end
					end)
				end
			end
		end

		task.delay(18, function()
			if barrel.Parent then
				barrel:SetAttribute("Detonated", false)
				barrel.Transparency = 0
				barrel.CanCollide = true
				barrel.CanQuery = true
				stripe.Transparency = 0
			end
		end)
	end

	barrel:GetAttributeChangedSignal("Detonated"):Connect(function()
		if barrel:GetAttribute("Detonated") then
			detonate()
		end
	end)

	barrel.Touched:Connect(function(hit: BasePart)
		if barrel:GetAttribute("Detonated") then
			return
		end
		if hit.AssemblyLinearVelocity.Magnitude > 20 then
			barrel:SetAttribute("Detonated", true)
		end
	end)
end

local function createBreakableCluster(center: Vector3, parent: Instance, color: Color3, material: Enum.Material)
	local offsets = {
		Vector3.new(-2, 1.5, 0),
		Vector3.new(2, 1.5, 0),
		Vector3.new(0, 4.5, 0),
	}
	for i, off in ipairs(offsets) do
		local prop = createBlock({
			Name = "BreakableProp_" .. i,
			Size = Vector3.new(3.2, 3.0, 3.2),
			CFrame = CFrame.new(center + off),
			Color = color,
			Material = material,
			Anchored = false,
			Parent = parent,
		})
		prop.CustomPhysicalProperties = PhysicalProperties.new(0.25, 0.5, 0.2)
	end
end

local function findVehicleModel(instance: Instance?): Model?
	local current: Instance? = instance
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("IsVehicle") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local crashCooldowns: { [Model]: number } = {}

local function attachCrashDamage(part: BasePart)
	part.Touched:Connect(function(hit: BasePart)
		local car = findVehicleModel(hit)
		if not car or not car.PrimaryPart or car:GetAttribute("Destroyed") then
			return
		end
		local speed = car.PrimaryPart.AssemblyLinearVelocity.Magnitude
		if speed < 50 then
			return
		end
		local now = os.clock()
		if crashCooldowns[car] and now - crashCooldowns[car] < 1.5 then
			return
		end
		crashCooldowns[car] = now
		local dmg = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?
		if dmg then
			dmg:Fire(car, math.clamp(math.floor((speed - 35) * 0.35), 8, 18))
		end
	end)
end

local function createExplosiveBuilding(pos: Vector3, size: Vector3, color: Color3, material: Enum.Material, parent: Instance, signText: string?)
	local bldg = createBlock({
		Name = "ExplosiveBuilding",
		Size = size,
		CFrame = CFrame.new(pos.X, size.Y / 2, pos.Z),
		Color = color,
		Material = material,
		Parent = parent,
	})
	bldg:SetAttribute("IsExplosiveBarrel", true)
	bldg:SetAttribute("Detonated", false)
	attachCrashDamage(bldg)

	local details: { BasePart } = {}

	local roof = createBlock({
		Name = "Roof",
		Size = Vector3.new(size.X + 2.2, 1.6, size.Z + 2.2),
		CFrame = CFrame.new(pos.X, size.Y + 0.8, pos.Z),
		Color = Color3.fromRGB(65, 55, 50),
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = bldg,
	})
	table.insert(details, roof)

	-- Ventanas luminosas y puerta 3D en la fachada
	local winColor = Color3.fromRGB(255, 225, 130)
	for _, xOff in ipairs({ -size.X * 0.28, size.X * 0.28 }) do
		local win = createBlock({
			Name = "Window",
			Size = Vector3.new(size.X * 0.22, size.Y * 0.25, 0.3),
			CFrame = CFrame.new(pos.X + xOff, size.Y * 0.62, pos.Z - size.Z / 2 - 0.1),
			Color = winColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = bldg,
		})
		table.insert(details, win)
	end

	local awning = createBlock({
		Name = "Awning",
		Size = Vector3.new(size.X * 0.75, 0.6, 3.5),
		CFrame = CFrame.new(pos.X, size.Y * 0.42, pos.Z - size.Z / 2 - 1.7),
		Color = Color3.fromRGB(205, 55, 45),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = bldg,
	})
	table.insert(details, awning)

	if signText then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = bldg
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 0.28)
		lbl.Position = UDim2.fromScale(0, 0.08)
		lbl.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		lbl.TextColor3 = Color3.fromRGB(255, 210, 65)
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.Text = signText
		lbl.Parent = gui
	end

	bldg:GetAttributeChangedSignal("Detonated"):Connect(function()
		if not bldg:GetAttribute("Detonated") or bldg.Transparency >= 1 then
			return
		end
		bldg.Transparency = 1
		bldg.CanCollide = false
		bldg.CanQuery = false
		for _, d in ipairs(details) do
			d.Transparency = 1
		end

		local exp = Instance.new("Explosion")
		exp.Position = bldg.Position
		exp.BlastRadius = 28
		exp.BlastPressure = 0
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = Workspace

		local dmg = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?
		local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
		if dmg and vehiclesFolder then
			for _, car in ipairs(vehiclesFolder:GetChildren()) do
				if car:IsA("Model") and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
					if car.PrimaryPart and (car.PrimaryPart.Position - bldg.Position).Magnitude <= 30 then
						dmg:Fire(car, 45)
					end
				end
			end
		end

		task.delay(22, function()
			if bldg.Parent then
				bldg:SetAttribute("Detonated", false)
				bldg.Transparency = 0
				bldg.CanCollide = true
				bldg.CanQuery = true
				for _, d in ipairs(details) do
					d.Transparency = 0
				end
			end
		end)
	end)
end

local function makeKnockable(part: BasePart, origCF: CFrame)
	local knocked = false
	part.Touched:Connect(function(hit: BasePart)
		if knocked then
			return
		end
		local car = findVehicleModel(hit)
		if car and car.PrimaryPart and car.PrimaryPart.AssemblyLinearVelocity.Magnitude > 16 then
			knocked = true
			part.Anchored = false
			local push = (part.Position - car.PrimaryPart.Position).Unit * 900 + Vector3.new(0, 600, 0)
			part:ApplyImpulse(push)
			task.delay(20, function()
				if part.Parent then
					part.Anchored = true
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
					part.CFrame = origCF
					knocked = false
				end
			end)
		end
	end)
end

local function createTree(pos: Vector3, isSnowy: boolean, parent: Instance)
	local trunkCF = CFrame.new(pos.X, 4.0, pos.Z)
	local trunk = createBlock({
		Name = "TreeTrunk",
		Size = Vector3.new(2.0, 8, 2.0),
		CFrame = trunkCF,
		Color = Color3.fromRGB(105, 70, 42),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	trunk.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0.1)
	local top = createBlock({
		Name = "TreeTop",
		Size = Vector3.new(8, 9, 8),
		CFrame = CFrame.new(pos.X, 11, pos.Z),
		Color = if isSnowy then Color3.fromRGB(220, 235, 242) else Color3.fromRGB(48, 125, 55),
		Material = if isSnowy then Enum.Material.Snow else Enum.Material.Grass,
		Anchored = false,
		CanCollide = false,
		Massless = true,
		Parent = trunk,
	})
	local w = Instance.new("WeldConstraint")
	w.Part0 = trunk
	w.Part1 = top
	w.Parent = trunk
	makeKnockable(trunk, trunkCF)
end

local function createCactus(pos: Vector3, parent: Instance)
	local bodyCF = CFrame.new(pos.X, 4.0, pos.Z)
	local body = createBlock({
		Name = "Cactus",
		Size = Vector3.new(1.8, 8, 1.8),
		CFrame = bodyCF,
		Color = Color3.fromRGB(58, 138, 62),
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	body.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0.1)
	local arm = createBlock({
		Name = "CactusArm",
		Size = Vector3.new(5.0, 1.4, 1.4),
		CFrame = CFrame.new(pos.X, 5.0, pos.Z),
		Color = Color3.fromRGB(58, 138, 62),
		Material = Enum.Material.Grass,
		Anchored = false,
		CanCollide = false,
		Massless = true,
		Parent = body,
	})
	local w = Instance.new("WeldConstraint")
	w.Part0 = body
	w.Part1 = arm
	w.Parent = body
	makeKnockable(body, bodyCF)
end

local function createLake(pos: Vector3, size: Vector3, isFrozen: boolean, parent: Instance)
	createBlock({
		Name = "ArenaLake",
		Size = size,
		CFrame = CFrame.new(pos.X, 0.2, pos.Z),
		Color = if isFrozen then Color3.fromRGB(165, 220, 245) else Color3.fromRGB(45, 135, 210),
		Material = if isFrozen then Enum.Material.Ice else Enum.Material.Glass,
		CanCollide = false,
		Transparency = if isFrozen then 0.15 else 0.35,
		Parent = parent,
	})
end

local function createRoadSign(pos: Vector3, text: string, color: Color3, parent: Instance)
	local post = createBlock({
		Name = "SignPost",
		Size = Vector3.new(0.8, 8, 0.8),
		CFrame = CFrame.new(pos.X, 4, pos.Z),
		Color = Color3.fromRGB(130, 134, 140),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local board = createBlock({
		Name = "SignBoard",
		Size = Vector3.new(10, 4.5, 0.6),
		CFrame = CFrame.new(pos.X, 8.5, pos.Z),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = post,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Text = text
	lbl.Parent = gui
end

local function populateScenery(arena: Folder, arenaId: string)
	local isDesert = arenaId == "GhostTown" or arenaId == "AircraftGraveyard" or arenaId == "Canyonlands" or arenaId == "OilFields" or arenaId == "SandFactory"
	local isSnow = arenaId == "SkiResort"

	-- Carreteras cruzadas para conectar la arena grande (1200x1200)
	if arenaId ~= "SkiResort" and arenaId ~= "HooverDam" then
		createBlock({ Name = "RoadNS", Size = Vector3.new(36, 0.2, 1140), CFrame = CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(52, 54, 60), Material = Enum.Material.Asphalt, CanCollide = false, Parent = arena })
		createBlock({ Name = "RoadEW", Size = Vector3.new(1140, 0.2, 36), CFrame = CFrame.new(0, 0.12, 0), Color = Color3.fromRGB(52, 54, 60), Material = Enum.Material.Asphalt, CanCollide = false, Parent = arena })
	end

	-- 8 edificios decorativos 3D explosivos distribuidos por el mapa (1200x1200)
	local buildingSpots = {
		{ Pos = Vector3.new(-260, 0, -250), Size = Vector3.new(28, 18, 24), Color = Color3.fromRGB(165, 95, 65), Text = "DINER" },
		{ Pos = Vector3.new(260, 0, -250), Size = Vector3.new(26, 20, 26), Color = Color3.fromRGB(185, 65, 55), Text = "V8 GAS" },
		{ Pos = Vector3.new(-270, 0, 260), Size = Vector3.new(30, 16, 22), Color = Color3.fromRGB(145, 115, 78), Text = "GARAGE" },
		{ Pos = Vector3.new(270, 0, 260), Size = Vector3.new(24, 22, 24), Color = Color3.fromRGB(120, 125, 135), Text = "DEPOT" },
		{ Pos = Vector3.new(-420, 0, 60), Size = Vector3.new(24, 16, 22), Color = Color3.fromRGB(150, 85, 58), Text = "MOTEL" },
		{ Pos = Vector3.new(420, 0, -60), Size = Vector3.new(24, 18, 22), Color = Color3.fromRGB(95, 115, 135), Text = "SHOP" },
		{ Pos = Vector3.new(-60, 0, -430), Size = Vector3.new(26, 16, 20), Color = Color3.fromRGB(170, 130, 75), Text = "SALOON" },
		{ Pos = Vector3.new(60, 0, 430), Size = Vector3.new(28, 18, 22), Color = Color3.fromRGB(110, 135, 105), Text = "STATION" },
	}
	for _, b in ipairs(buildingSpots) do
		createExplosiveBuilding(b.Pos, b.Size, b.Color, Enum.Material.WoodPlanks, arena, b.Text)
	end

	-- Lagos / Oasis
	if arenaId == "ValleyFarms" or arenaId == "SkiResort" or arenaId == "Canyonlands" or arenaId == "GhostTown" then
		createLake(Vector3.new(-230, 0, 180), Vector3.new(130, 0.6, 100), isSnow, arena)
		createLake(Vector3.new(280, 0, -180), Vector3.new(100, 0.6, 85), isSnow, arena)
	end

	-- Letreros de carretera
	createRoadSign(Vector3.new(-170, 0, -170), "ROUTE 66", Color3.fromRGB(35, 115, 65), arena)
	createRoadSign(Vector3.new(170, 0, 170), "V8 ARENA", Color3.fromRGB(195, 55, 45), arena)
	createRoadSign(Vector3.new(-350, 0, 200), "CAUTION", Color3.fromRGB(215, 155, 30), arena)
	createRoadSign(Vector3.new(350, 0, -200), "DANGER", Color3.fromRGB(185, 45, 45), arena)

	-- Árboles pequeños derribables o cactus por todo el mapa
	for i = 1, 28 do
		local ang = (i / 28) * math.pi * 2
		local r = 160 + (i % 5) * 90
		local p = Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		if isDesert then
			createCactus(p, arena)
		elseif arenaId ~= "SecretBase" and arenaId ~= "CasinoCity" then
			createTree(p, isSnow, arena)
		end
	end
end

-- ==========================================
-- CONSTRUCTORES DE LAS 10 ARENAS
-- ==========================================
local arenaBuilders: { [string]: (arena: Folder, token: number) -> () } = {}

-- 1. Ski Resort (Colorado): Nieve, rampas, cabaña y 3 pinos que disparan avalancha
arenaBuilders.SkiResort = function(arena, token)
	createRamp("SkiRamp1", Vector3.new(28, 10, 36), CFrame.new(-45, 5, -50), Color3.fromRGB(240, 248, 255), arena, Enum.Material.Snow)
	createRamp("SkiRamp2", Vector3.new(28, 10, 36), CFrame.new(45, 5, 50) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(240, 248, 255), arena, Enum.Material.Snow)
	createBlock({ Name = "SkiLodge", Size = Vector3.new(30, 14, 22), CFrame = CFrame.new(-95, 7, -95), Color = Color3.fromRGB(130, 82, 50), Material = Enum.Material.WoodPlanks, Parent = arena })

	local treesShot = 0
	local avalancheCooldown = false
	for i, pos in ipairs({ Vector3.new(-30, 10, -110), Vector3.new(0, 10, -115), Vector3.new(30, 10, -110) }) do
		local tree = createBlock({ Name = "AvalanchePine_" .. i, Size = Vector3.new(6, 20, 6), CFrame = CFrame.new(pos), Color = Color3.fromRGB(35, 95, 50), Material = Enum.Material.Grass, Parent = arena })
		tree:SetAttribute("IsShootableTrigger", true)
		tree:SetAttribute("Triggered", false)
		tree:GetAttributeChangedSignal("Triggered"):Connect(function()
			if tree:GetAttribute("Triggered") then
				tree:SetAttribute("Triggered", false)
				tree.Color = Color3.fromRGB(255, 195, 80)
				treesShot += 1
				if treesShot >= 3 and not avalancheCooldown then
					avalancheCooldown = true
					treesShot = 0
					for b = -2, 2 do
						local ball = Instance.new("Part")
						ball.Name = "AvalancheBoulder"
						ball.Shape = Enum.PartType.Ball
						ball.Size = Vector3.new(16, 16, 16)
						ball.Color = Color3.fromRGB(245, 250, 255)
						ball.Material = Enum.Material.Snow
						ball.Position = Vector3.new(b * 35, 14, -120)
						ball.Parent = arena
						ball.AssemblyLinearVelocity = Vector3.new(0, 0, 95)
						ball.Touched:Connect(function(hit)
							local car = findVehicleModel(hit)
							local dmg = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?
							if car and dmg and not car:GetAttribute("Destroyed") then
								dmg:Fire(car, 35)
							end
						end)
						task.delay(6, function()
							if ball.Parent then
								ball:Destroy()
							end
						end)
					end
					task.delay(8, function()
						avalancheCooldown = false
					end)
				end
			end
		end)
	end
	createExplosiveBarrel(Vector3.new(0, 2.2, 0), arena)
	createExplosiveBarrel(Vector3.new(75, 2.2, -75), arena)
end

-- 2. Valley Farms (California): Granero, silos y cercas/tractores destructibles
arenaBuilders.ValleyFarms = function(arena)
	createBlock({ Name = "RedBarn", Size = Vector3.new(34, 18, 26), CFrame = CFrame.new(-80, 9, -70), Color = Color3.fromRGB(175, 42, 38), Material = Enum.Material.WoodPlanks, Parent = arena })
	for i, sPos in ipairs({ Vector3.new(85, 14, -85), Vector3.new(105, 14, -85) }) do
		local silo = createBlock({ Name = "FarmSilo_" .. i, Size = Vector3.new(12, 28, 12), CFrame = CFrame.new(sPos), Color = Color3.fromRGB(195, 200, 205), Material = Enum.Material.Metal, Parent = arena })
		silo.Shape = Enum.PartType.Cylinder
		silo.CFrame = CFrame.new(sPos) * CFrame.Angles(0, 0, math.rad(90))
	end
	createRamp("HayRamp1", Vector3.new(22, 7, 26), CFrame.new(0, 3.5, -40), Color3.fromRGB(215, 185, 75), arena, Enum.Material.Grass)
	createRamp("HayRamp2", Vector3.new(22, 7, 26), CFrame.new(0, 3.5, 40) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(215, 185, 75), arena, Enum.Material.Grass)
	createBreakableCluster(Vector3.new(-25, 0, 25), arena, Color3.fromRGB(165, 118, 68), Enum.Material.WoodPlanks)
	createBreakableCluster(Vector3.new(35, 0, -25), arena, Color3.fromRGB(165, 118, 68), Enum.Material.WoodPlanks)
	createExplosiveBarrel(Vector3.new(-60, 2.2, -65), arena)
	createExplosiveBarrel(Vector3.new(75, 2.2, 75), arena)
end

-- 3. Aircraft Graveyard (Arizona): Fuselajes y alas como rampas
arenaBuilders.AircraftGraveyard = function(arena)
	for i, pos in ipairs({ Vector3.new(-65, 6, -55), Vector3.new(65, 6, 55), Vector3.new(0, 6, 0) }) do
		local fuselage = createBlock({ Name = "PlaneFuselage_" .. i, Size = Vector3.new(12, 10, 48), CFrame = CFrame.new(pos) * CFrame.Angles(0, i * 0.6, 0), Color = Color3.fromRGB(175, 180, 185), Material = Enum.Material.Metal, Parent = arena })
		createRamp("PlaneWing_" .. i, Vector3.new(26, 7, 22), fuselage.CFrame * CFrame.new(18, -2.5, 0), Color3.fromRGB(160, 165, 170), arena, Enum.Material.Metal)
	end
	createExplosiveBarrel(Vector3.new(-40, 2.2, 40), arena)
	createExplosiveBarrel(Vector3.new(40, 2.2, -40), arena)
	createBreakableCluster(Vector3.new(-90, 0, 80), arena, Color3.fromRGB(150, 120, 80), Enum.Material.WoodPlanks)
end

-- 4. Canyonlands (Utah): Mesas rocosas, puente y círculo de piedra teletransportador
arenaBuilders.Canyonlands = function(arena)
	createBlock({ Name = "CanyonMesaW", Size = Vector3.new(45, 10, 50), CFrame = CFrame.new(-75, 5, 0), Color = Color3.fromRGB(165, 85, 55), Material = Enum.Material.Rock, Parent = arena })
	createBlock({ Name = "CanyonMesaE", Size = Vector3.new(45, 10, 50), CFrame = CFrame.new(75, 5, 0), Color = Color3.fromRGB(165, 85, 55), Material = Enum.Material.Rock, Parent = arena })
	createBlock({ Name = "CanyonBridge", Size = Vector3.new(105, 2, 18), CFrame = CFrame.new(0, 9, 0), Color = Color3.fromRGB(145, 95, 65), Material = Enum.Material.WoodPlanks, Parent = arena })
	createRamp("MesaRampW", Vector3.new(20, 10, 28), CFrame.new(-75, 5, 39), Color3.fromRGB(155, 80, 50), arena, Enum.Material.Rock)
	createRamp("MesaRampE", Vector3.new(20, 10, 28), CFrame.new(75, 5, -39) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(155, 80, 50), arena, Enum.Material.Rock)

	-- Círculo de piedra teletransportador
	local telePad = createBlock({ Name = "StoneCircleTeleporter", Size = Vector3.new(14, 1, 14), CFrame = CFrame.new(0, 0.5, -95), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = arena })
	local lastTeleport: { [Model]: number } = {}
	telePad.Touched:Connect(function(hit)
		local car = findVehicleModel(hit)
		if car and car.PrimaryPart then
			local now = os.clock()
			if not lastTeleport[car] or now - lastTeleport[car] > 3 then
				lastTeleport[car] = now
				car:PivotTo(CFrame.new(0, 14, 0))
			end
		end
	end)
	createExplosiveBarrel(Vector3.new(0, 12.2, 0), arena)
end

-- 5. Oil Fields (Nuevo México): Torres petroleras y tanques inflamables en cadena
arenaBuilders.OilFields = function(arena)
	for i, pos in ipairs({ Vector3.new(-75, 14, -75), Vector3.new(75, 14, -75), Vector3.new(-75, 14, 75), Vector3.new(75, 14, 75) }) do
		createBlock({ Name = "OilDerrick_" .. i, Size = Vector3.new(12, 28, 12), CFrame = CFrame.new(pos), Color = Color3.fromRGB(65, 65, 70), Material = Enum.Material.Metal, Parent = arena })
		createExplosiveBarrel(pos + Vector3.new(14, -10, 0), arena, 1.8, Color3.fromRGB(230, 120, 30))
		createExplosiveBarrel(pos + Vector3.new(-14, -10, 0), arena, 1.8, Color3.fromRGB(230, 120, 30))
	end
	createRamp("OilRamp1", Vector3.new(22, 7, 26), CFrame.new(0, 3.5, -30), Color3.fromRGB(95, 95, 100), arena, Enum.Material.Metal)
	createRamp("OilRamp2", Vector3.new(22, 7, 26), CFrame.new(0, 3.5, 30) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(95, 95, 100), arena, Enum.Material.Metal)
end

-- 6. Casino City (Nevada): Ciudad nocturna con hoteles, neón y calles amplias
arenaBuilders.CasinoCity = function(arena)
	local neonColors = { Color3.fromRGB(255, 65, 175), Color3.fromRGB(65, 225, 255), Color3.fromRGB(255, 210, 55), Color3.fromRGB(130, 255, 95) }
	for i, pos in ipairs({ Vector3.new(-90, 18, -90), Vector3.new(90, 18, -90), Vector3.new(-90, 18, 90), Vector3.new(90, 18, 90) }) do
		createBlock({ Name = "CasinoHotel_" .. i, Size = Vector3.new(34, 36, 34), CFrame = CFrame.new(pos), Color = Color3.fromRGB(45, 42, 62), Material = Enum.Material.SmoothPlastic, Parent = arena })
		createBlock({ Name = "NeonSign_" .. i, Size = Vector3.new(28, 5, 2), CFrame = CFrame.new(pos + Vector3.new(0, 6, if pos.Z < 0 then 18 else -18)), Color = neonColors[i], Material = Enum.Material.Neon, Parent = arena })
	end
	createRamp("StripRamp1", Vector3.new(24, 7, 28), CFrame.new(0, 3.5, -50), Color3.fromRGB(70, 72, 85), arena)
	createRamp("StripRamp2", Vector3.new(24, 7, 28), CFrame.new(0, 3.5, 50) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(70, 72, 85), arena)
	createBreakableCluster(Vector3.new(-35, 0, 0), arena, Color3.fromRGB(255, 80, 190), Enum.Material.Neon)
	createBreakableCluster(Vector3.new(35, 0, 0), arena, Color3.fromRGB(80, 225, 255), Enum.Material.Neon)
end

-- 7. Ghost Town (Nuevo México): Pueblo oeste + locomotora activa + tornado
arenaBuilders.GhostTown = function(arena, token)
	for i, pos in ipairs({ Vector3.new(-80, 7, -70), Vector3.new(80, 7, -70), Vector3.new(-80, 7, 70) }) do
		createBlock({ Name = "Saloon_" .. i, Size = Vector3.new(24, 14, 20), CFrame = CFrame.new(pos), Color = Color3.fromRGB(135, 95, 58), Material = Enum.Material.WoodPlanks, Parent = arena })
	end
	createBlock({ Name = "RailTrack", Size = Vector3.new(1140, 0.5, 8), CFrame = CFrame.new(0, 0.25, 0), Color = Color3.fromRGB(65, 55, 50), Material = Enum.Material.Metal, CanCollide = false, Parent = arena })

	-- Locomotora activa recorriendo la vía
	local train = createBlock({ Name = "GhostTrain", Size = Vector3.new(22, 10, 9), CFrame = CFrame.new(-130, 5, 0), Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal, Parent = arena })
	train.Touched:Connect(function(hit)
		local car = findVehicleModel(hit)
		local dmg = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?
		if car and car.PrimaryPart and not car:GetAttribute("Destroyed") then
			car.PrimaryPart:ApplyImpulse(Vector3.new(0, 8000, 10000))
			if dmg then
				dmg:Fire(car, 25)
			end
		end
	end)

	-- Tornado activo
	local tornado = createBlock({ Name = "Tornado", Size = Vector3.new(16, 42, 16), CFrame = CFrame.new(55, 21, 55), Color = Color3.fromRGB(190, 175, 150), Material = Enum.Material.Sand, CanCollide = false, Transparency = 0.45, Parent = arena })
	tornado.Shape = Enum.PartType.Cylinder
	tornado.CFrame = CFrame.new(55, 21, 55) * CFrame.Angles(0, 0, math.rad(90))
	tornado.Touched:Connect(function(hit)
		local car = findVehicleModel(hit)
		if car and car.PrimaryPart then
			car.PrimaryPart:ApplyImpulse(Vector3.new(0, 12000, 0))
		end
	end)

	task.spawn(function()
		local t = 0
		while arena.Parent and arenaToken == token do
			t += 0.04
			local trainX = math.sin(t * 0.7) * 500
			train.CFrame = CFrame.new(trainX, 5, 0)
			tornado.CFrame = CFrame.new(math.cos(t * 0.5) * 185, 21, math.sin(t * 0.5) * 185 + 35) * CFrame.Angles(0, 0, math.rad(90))
			task.wait(0.04)
		end
	end)
end

-- 8. Hoover Dam (Arizona - Nevada): Presa, cuenca de agua e interruptor eléctrico
arenaBuilders.HooverDam = function(arena)
	createBlock({ Name = "DamWall", Size = Vector3.new(1100, 18, 28), CFrame = CFrame.new(0, 9, -360), Color = Color3.fromRGB(165, 168, 172), Material = Enum.Material.Concrete, Parent = arena })
	local water = createBlock({ Name = "DamWater", Size = Vector3.new(360, 1.5, 190), CFrame = CFrame.new(0, 0.75, 65), Color = Color3.fromRGB(45, 130, 200), Material = Enum.Material.Glass, CanCollide = false, Transparency = 0.35, Parent = arena })

	local switch = createBlock({ Name = "ElectricSwitch", Size = Vector3.new(6, 10, 6), CFrame = CFrame.new(-100, 5, 35), Color = Color3.fromRGB(255, 215, 45), Material = Enum.Material.Neon, Parent = arena })
	switch:SetAttribute("IsShootableTrigger", true)
	switch:SetAttribute("Triggered", false)

	local electrified = false
	switch:GetAttributeChangedSignal("Triggered"):Connect(function()
		if switch:GetAttribute("Triggered") and not electrified then
			switch:SetAttribute("Triggered", false)
			electrified = true
			water.Color = Color3.fromRGB(120, 235, 255)
			for _ = 1, 8 do
				local dmg = ServerScriptService:FindFirstChild("DamageVehicleEvent") :: BindableEvent?
				local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
				if dmg and vehiclesFolder then
					for _, car in ipairs(vehiclesFolder:GetChildren()) do
						if car:IsA("Model") and car.PrimaryPart and not car:GetAttribute("Destroyed") then
							local p = car.PrimaryPart.Position
							if math.abs(p.X) <= 90 and p.Z >= -20 and p.Z <= 90 then
								dmg:Fire(car, 10)
							end
						end
					end
				end
				task.wait(0.5)
			end
			water.Color = Color3.fromRGB(45, 130, 200)
			electrified = false
		end
	end)
	createRamp("DamRamp", Vector3.new(24, 7, 28), CFrame.new(0, 3.5, -55), Color3.fromRGB(150, 152, 156), arena)
end

-- 9. Sand Factory (Utah - Extra): Plataforma elevada y poste que baja el ascensor
arenaBuilders.SandFactory = function(arena)
	createBlock({ Name = "UpperDeck", Size = Vector3.new(90, 2, 70), CFrame = CFrame.new(0, 14, 0), Color = Color3.fromRGB(130, 120, 105), Material = Enum.Material.Metal, Parent = arena })
	createRamp("ConveyorRamp", Vector3.new(22, 14, 42), CFrame.new(0, 7, 56), Color3.fromRGB(115, 110, 100), arena, Enum.Material.Metal)

	local elevator = createBlock({ Name = "CargoElevator", Size = Vector3.new(24, 2, 24), CFrame = CFrame.new(0, 13, -47), Color = Color3.fromRGB(230, 175, 45), Material = Enum.Material.DiamondPlate, Parent = arena })
	local post = createBlock({ Name = "ElevatorPost", Size = Vector3.new(5, 12, 5), CFrame = CFrame.new(-35, 6, -47), Color = Color3.fromRGB(255, 95, 45), Material = Enum.Material.Neon, Parent = arena })
	post:SetAttribute("IsShootableTrigger", true)
	post:SetAttribute("Triggered", false)

	local isDown = false
	post:GetAttributeChangedSignal("Triggered"):Connect(function()
		if post:GetAttribute("Triggered") then
			post:SetAttribute("Triggered", false)
			isDown = not isDown
			elevator.CFrame = CFrame.new(0, if isDown then 1 else 13, -47)
		end
	end)
	createExplosiveBarrel(Vector3.new(0, 17.2, 0), arena)
end

-- 10. Secret Base (Nevada - Extra): Área 51, platillo central y propulsores alienígenas
arenaBuilders.SecretBase = function(arena)
	local saucer = createBlock({ Name = "AlienSaucerProp", Size = Vector3.new(8, 38, 38), CFrame = CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 245, 220), Material = Enum.Material.Neon, Parent = arena })
	saucer.Shape = Enum.PartType.Cylinder

	for i, pos in ipairs({ Vector3.new(-80, 10, -80), Vector3.new(80, 10, -80), Vector3.new(-80, 10, 80), Vector3.new(80, 10, 80) }) do
		createBlock({ Name = "HangarPillar_" .. i, Size = Vector3.new(18, 20, 18), CFrame = CFrame.new(pos), Color = Color3.fromRGB(50, 55, 65), Material = Enum.Material.Metal, Parent = arena })
	end

	for i, bPos in ipairs({ Vector3.new(-50, 0.5, 0), Vector3.new(50, 0.5, 0) }) do
		local boost = createBlock({ Name = "AlienBoost_" .. i, Size = Vector3.new(14, 1, 14), CFrame = CFrame.new(bPos), Color = Color3.fromRGB(185, 75, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = arena })
		boost.Touched:Connect(function(hit)
			local car = findVehicleModel(hit)
			if car and car.PrimaryPart then
				car.PrimaryPart:ApplyImpulse(car.PrimaryPart.CFrame.LookVector * 8000 + Vector3.new(0, 3500, 0))
			end
		end)
	end
	createExplosiveBarrel(Vector3.new(0, 2.2, -55), arena, 1.2, Color3.fromRGB(160, 85, 255))
	createExplosiveBarrel(Vector3.new(0, 2.2, 55), arena, 1.2, Color3.fromRGB(160, 85, 255))
end

local function buildArena(arenaId: string)
	local cfg = Config.ARENAS[arenaId] or Config.ARENAS.GhostTown
	arenaToken += 1
	local myToken = arenaToken

	local old = Workspace:FindFirstChild("TestArena")
	if old then
		old:Destroy()
	end

	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	local currentArenaVal = matchState and matchState:FindFirstChild("CurrentArena") :: StringValue?
	if currentArenaVal then
		currentArenaVal.Value = cfg.Id
	end

	Lighting.ClockTime = cfg.ClockTime or 14

	local arena = Instance.new("Folder")
	arena.Name = "TestArena"
	arena.Parent = Workspace

	local half = Config.ARENA_SIZE / 2
	local wallH = Config.WALL_HEIGHT

	createBlock({
		Name = "ArenaFloor",
		Size = Vector3.new(Config.ARENA_SIZE, 2, Config.ARENA_SIZE),
		CFrame = CFrame.new(0, -1, 0),
		Color = cfg.FloorColor,
		Material = cfg.FloorMaterial,
		Parent = arena,
	})

	local wallThickness = 6
	local wallSpecs = {
		{ Name = "WallNorth", Size = Vector3.new(Config.ARENA_SIZE + wallThickness * 2, wallH, wallThickness), Pos = Vector3.new(0, wallH / 2, -half - wallThickness / 2) },
		{ Name = "WallSouth", Size = Vector3.new(Config.ARENA_SIZE + wallThickness * 2, wallH, wallThickness), Pos = Vector3.new(0, wallH / 2, half + wallThickness / 2) },
		{ Name = "WallEast", Size = Vector3.new(wallThickness, wallH, Config.ARENA_SIZE), Pos = Vector3.new(half + wallThickness / 2, wallH / 2, 0) },
		{ Name = "WallWest", Size = Vector3.new(wallThickness, wallH, Config.ARENA_SIZE), Pos = Vector3.new(-half - wallThickness / 2, wallH / 2, 0) },
	}
	for _, spec in ipairs(wallSpecs) do
		createBlock({
			Name = spec.Name,
			Size = spec.Size,
			CFrame = CFrame.new(spec.Pos),
			Color = cfg.WallColor,
			Material = Enum.Material.Slate,
			Parent = arena,
		})
	end

	local builder = arenaBuilders[cfg.Id]
	if builder then
		builder(arena, myToken)
	end
	populateScenery(arena, cfg.Id)
end

buildArenaEvent.Event:Connect(function(arenaId: string)
	if typeof(arenaId) == "string" then
		buildArena(arenaId)
	end
end)

buildArena("GhostTown")
