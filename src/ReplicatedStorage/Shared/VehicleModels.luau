local Config = require(script.Parent:WaitForChild("Config"))

local VehicleModels = {}
local currentScale = Config.VEHICLE.SCALE or 1.35

local function scaleCF(cf: CFrame): CFrame
	return CFrame.new(cf.Position * currentScale) * (cf - cf.Position)
end

local function getDetachableFolder(model: Model): Folder
	local f = model:FindFirstChild("DetachableParts") :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = "DetachableParts"
		f.Parent = model
	end
	return f
end

local function weld(partA: BasePart, partB: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = partA
	w.Part1 = partB
	w.Parent = partA
	return w
end

local function addLego(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * currentScale
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Massless = true
	p.Transparency = transparency or 0
	p.CFrame = chassis.CFrame * scaleCF(offset)
	p.Parent = getDetachableFolder(model)
	weld(chassis, p)
	return p
end

local function addWedge(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size * currentScale
	w.Color = color
	w.Material = material or Enum.Material.Plastic
	w.TopSurface = Enum.SurfaceType.Studs
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CanCollide = false
	w.Massless = true
	w.Transparency = transparency or 0
	w.CFrame = chassis.CFrame * scaleCF(offset)
	w.Parent = getDetachableFolder(model)
	weld(chassis, w)
	return w
end

local DARK_GLASS = Color3.fromRGB(28, 34, 44)
local CHROME = Color3.fromRGB(190, 196, 205)
local DARK_METAL = Color3.fromRGB(40, 42, 48)

local function addCurvedArch(model: Model, chassis: BasePart, x: number, zCenter: number, archColor: Color3)
	-- Paso de rueda biselado de 3 piezas (cuña delantera + arco superior liso + cuña trasera)
	addLego(model, chassis, "ArchTop", Vector3.new(1.85, 0.5, 2.2), CFrame.new(x, 1.0, zCenter), archColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "ArchFrontSlope", Vector3.new(1.85, 0.85, 1.2), CFrame.new(x, 0.82, zCenter - 1.65), archColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "ArchRearSlope", Vector3.new(1.85, 0.85, 1.2), CFrame.new(x, 0.82, zCenter + 1.65) * CFrame.Angles(0, math.rad(180), 0), archColor, Enum.Material.SmoothPlastic)
end

local function addWideBodyWithWheelArches(model: Model, chassis: BasePart, carColor: Color3)
	-- Ensancha la carrocería (ancho total ~9.3) con pasos de rueda curvos/biselados
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 3.8
		addLego(model, chassis, "DoorPanel", Vector3.new(1.7, 1.8, 4.8), CFrame.new(x, 0.0, 0.0), carColor)
		-- Bisel curvo superior en la puerta
		addWedge(model, chassis, "DoorBevel", Vector3.new(4.8, 0.45, 0.65), CFrame.new(x + side * 0.45, 1.05, 0.0) * CFrame.Angles(0, math.rad(if side < 0 then 90 else -90), 0), carColor, Enum.Material.SmoothPlastic)
		addLego(model, chassis, "FrontCorner", Vector3.new(1.7, 1.8, 1.2), CFrame.new(x, 0.0, -6.6), carColor)
		addWedge(model, chassis, "FrontNoseCurve", Vector3.new(1.7, 0.7, 1.2), CFrame.new(x, 1.0, -6.5), carColor, Enum.Material.SmoothPlastic)
		addLego(model, chassis, "RearCorner", Vector3.new(1.7, 1.8, 1.2), CFrame.new(x, 0.0, 6.6), carColor)
		addWedge(model, chassis, "RearTailCurve", Vector3.new(1.7, 0.7, 1.2), CFrame.new(x, 1.0, 6.5) * CFrame.Angles(0, math.rad(180), 0), carColor, Enum.Material.SmoothPlastic)
		addCurvedArch(model, chassis, x, -4.4, carColor)
		addCurvedArch(model, chassis, x, 4.4, carColor)
	end
end

local builders: { [string]: (model: Model, chassis: BasePart, carColor: Color3) -> () } = {}

-- 1. Rattler (Chassey Blue)
builders.Rattler = function(model, chassis, carColor)
	local yellow = Color3.fromRGB(245, 200, 45)
	addLego(model, chassis, "FrontStripe", Vector3.new(2.2, 1.5, 0.4), CFrame.new(0, 0.1, -7.1), yellow)
	addLego(model, chassis, "HoodStripe", Vector3.new(2.2, 0.25, 5.2), CFrame.new(0, 1.0, -4.4), yellow)
	addLego(model, chassis, "HoodBlower", Vector3.new(2.2, 0.65, 2.2), CFrame.new(0, 1.4, -3.6), yellow)

	for _, xOff in ipairs({ -3.6, 3.6 }) do
		addLego(model, chassis, "FenderPod", Vector3.new(1.8, 1.0, 2.4), CFrame.new(xOff, 1.2, -5.8), carColor)
		addLego(model, chassis, "RoundLamp", Vector3.new(0.6, 1.2, 1.2), CFrame.new(xOff, 1.2, -7.1) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(245, 250, 255), Enum.Material.Glass, Enum.PartType.Cylinder, 0.25)
		addLego(model, chassis, "SideExhaust", Vector3.new(0.9, 0.9, 3.6), CFrame.new(xOff * 1.25, -0.7, 0.2) * CFrame.Angles(0, math.rad(90), 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	addWedge(model, chassis, "NoseSlopeCenter", Vector3.new(5.8, 0.55, 1.8), CFrame.new(0, 1.05, -6.2), carColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "NoseStripeSlope", Vector3.new(2.2, 0.58, 1.8), CFrame.new(0, 1.08, -6.2), yellow, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "LegoWindshield", Vector3.new(5.4, 1.8, 2.2), CFrame.new(0, 1.8, -1.2), DARK_GLASS, Enum.Material.Glass, 0.48)
	-- Cabina hueca con ventanas abiertas y bordes biselados para ver al piloto adentro
	addLego(model, chassis, "CabinRoof", Vector3.new(5.4, 0.45, 4.4), CFrame.new(0, 2.6, 2.0), carColor, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "RoofStripe", Vector3.new(2.2, 0.52, 4.45), CFrame.new(0, 2.6, 2.0), yellow, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "RoofBevelL", Vector3.new(4.4, 0.45, 0.7), CFrame.new(-3.0, 2.6, 2.0) * CFrame.Angles(0, math.rad(90), 0), carColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "RoofBevelR", Vector3.new(4.4, 0.45, 0.7), CFrame.new(3.0, 2.6, 2.0) * CFrame.Angles(0, math.rad(-90), 0), carColor, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "PillarL", Vector3.new(0.6, 1.7, 1.6), CFrame.new(-2.6, 1.7, 3.4), carColor)
	addLego(model, chassis, "PillarR", Vector3.new(0.6, 1.7, 1.6), CFrame.new(2.6, 1.7, 3.4), carColor)
	addWedge(model, chassis, "RearSlope", Vector3.new(5.2, 1.2, 2.8), CFrame.new(0, 1.45, 5.2) * CFrame.Angles(0, math.rad(180), 0), carColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "RearStripe", Vector3.new(2.2, 1.25, 2.85), CFrame.new(0, 1.47, 5.2) * CFrame.Angles(0, math.rad(180), 0), yellow, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "TailStripe", Vector3.new(2.2, 1.4, 0.4), CFrame.new(0, 0.2, 7.1), yellow)
end

-- 2. Clydesdale (Slick Clyde) - Diseño LEGO fiel: SUV marrón 4x4 con franja crema, defensa gris y bobina eléctrica en el techo
builders.Clydesdale = function(model, chassis, carColor)
	local cream = Color3.fromRGB(225, 210, 165)
	addLego(model, chassis, "Bullbar", Vector3.new(7.4, 1.8, 0.7), CFrame.new(0, 0.7, -7.3), CHROME, Enum.Material.Metal)
	addLego(model, chassis, "Pinstripe", Vector3.new(9.2, 0.3, 14.0), CFrame.new(0, 0.85, 0), cream)
	addWedge(model, chassis, "Windshield", Vector3.new(7.8, 1.8, 1.8), CFrame.new(0, 2.0, -2.5), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "SUVRoof", Vector3.new(8.2, 0.45, 9.4), CFrame.new(0, 3.1, 2.2), carColor, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "SUVRear", Vector3.new(8.2, 2.0, 5.8), CFrame.new(0, 2.0, 4.0), carColor)
	addLego(model, chassis, "RoofRack", Vector3.new(6.8, 0.4, 7.0), CFrame.new(0, 3.55, 2.2), CHROME, Enum.Material.Metal)
	-- Bobina eléctrica plateada en el techo (Lightning Bolt)
	addLego(model, chassis, "LightningCoil", Vector3.new(1.8, 1.8, 4.4), CFrame.new(0, 4.3, 2.2) * CFrame.Angles(0, math.rad(90), 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
end

-- 3. Strider (Sheila) - Diseño LEGO fiel: Buggy Baja rojo/blanco con jaula negra, motor trasero y doble gatling
builders.Strider = function(model, chassis, carColor)
	local white = Color3.fromRGB(242, 244, 248)
	local black = Color3.fromRGB(28, 30, 34)
	addWedge(model, chassis, "NoseSlope", Vector3.new(5.4, 1.0, 4.4), CFrame.new(0, 1.0, -4.6), carColor, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "WhitePanelL", Vector3.new(0.6, 1.3, 5.0), CFrame.new(-3.1, 1.2, 0.2), white)
	addLego(model, chassis, "WhitePanelR", Vector3.new(0.6, 1.3, 5.0), CFrame.new(3.1, 1.2, 0.2), white)
	addLego(model, chassis, "CageRoof", Vector3.new(5.2, 0.4, 4.8), CFrame.new(0, 2.9, 0.4), black)
	for _, xOff in ipairs({ -2.4, 2.4 }) do
		addLego(model, chassis, "CagePillarF", Vector3.new(0.45, 2.0, 0.45), CFrame.new(xOff, 1.9, -1.7), black)
		addLego(model, chassis, "CagePillarR", Vector3.new(0.45, 2.0, 0.45), CFrame.new(xOff, 1.9, 2.5), black)
		addLego(model, chassis, "FenderCurve", Vector3.new(1.6, 0.5, 3.2), CFrame.new(xOff * 1.5, 0.9, -4.4), carColor, Enum.Material.SmoothPlastic)
	end
	addLego(model, chassis, "RearEngine", Vector3.new(3.8, 1.8, 3.0), CFrame.new(0, 1.5, 5.0), CHROME, Enum.Material.Metal)
	-- Doble ametralladora rotativa Tantrum Gun en el techo
	addLego(model, chassis, "GatlingBase", Vector3.new(2.2, 1.0, 2.4), CFrame.new(0, 3.6, 0.4), DARK_METAL)
	addLego(model, chassis, "GatlingL", Vector3.new(0.55, 0.55, 4.0), CFrame.new(-0.7, 3.8, -2.0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
	addLego(model, chassis, "GatlingR", Vector3.new(0.55, 0.55, 4.0), CFrame.new(0.7, 3.8, -2.0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
end

-- 4. Jefferson (John Torque) - Diseño LEGO fiel: Muscle azul marino con techo gris y maletero abierto con subwoofers dorados
builders.Jefferson = function(model, chassis, carColor)
	local gold = Color3.fromRGB(235, 190, 55)
	local roofGray = Color3.fromRGB(115, 120, 128)
	addWedge(model, chassis, "NoseSlope", Vector3.new(5.8, 0.5, 2.0), CFrame.new(0, 1.05, -6.0), carColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "Windshield", Vector3.new(5.6, 1.8, 2.0), CFrame.new(0, 1.8, -1.2), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "CabinRoof", Vector3.new(5.8, 0.45, 4.2), CFrame.new(0, 2.6, 1.6), roofGray, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "PillarL", Vector3.new(0.6, 1.7, 1.6), CFrame.new(-2.6, 1.7, 3.0), roofGray)
	addLego(model, chassis, "PillarR", Vector3.new(0.6, 1.7, 1.6), CFrame.new(2.6, 1.7, 3.0), roofGray)
	-- Maletero abierto con 2 subwoofers dorados (Bass Quake) y placa 70 MSCL
	addLego(model, chassis, "SubL", Vector3.new(0.6, 2.0, 2.0), CFrame.new(-1.8, 1.3, 5.4) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	addLego(model, chassis, "SubR", Vector3.new(0.6, 2.0, 2.0), CFrame.new(1.8, 1.3, 5.4) * CFrame.Angles(0, 0, math.rad(90)), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	addLego(model, chassis, "AmpCenter", Vector3.new(1.6, 0.8, 1.8), CFrame.new(0, 1.2, 5.4), gold, Enum.Material.Metal)
	addLego(model, chassis, "TrunkLid", Vector3.new(5.4, 0.35, 3.2), CFrame.new(0, 2.6, 5.4) * CFrame.Angles(math.rad(-35), 0, 0), carColor)
end

-- 5. Van (Dave) - Diseño LEGO fiel: marrón/beige con franja crema, ojo de buey, escalera, repuesto y placa I <3 UFO
builders.Van = function(model, chassis, carColor)
	local tan = Color3.fromRGB(165, 140, 102)
	local cream = Color3.fromRGB(222, 206, 158)
	local white = Color3.fromRGB(240, 242, 245)

	-- Base ancha tono arena con pasos de rueda
	addWideBodyWithWheelArches(model, chassis, tan)
	chassis.Color = carColor

	-- Capó marrón inclinado, parrilla gris y franja crema continua
	addLego(model, chassis, "CreamBelt", Vector3.new(9.2, 0.35, 14.2), CFrame.new(0, 1.1, 0), cream)
	addWedge(model, chassis, "VanHood", Vector3.new(8.6, 1.0, 3.2), CFrame.new(0, 1.7, -5.2), carColor)
	addLego(model, chassis, "VanGrille", Vector3.new(4.2, 1.2, 0.5), CFrame.new(0, 0.4, -7.1), CHROME, Enum.Material.Metal)

	-- Cabina delantera abierta para ver al piloto + parabrisas translúcido
	addWedge(model, chassis, "VanWindshield", Vector3.new(8.0, 1.9, 1.8), CFrame.new(0, 2.7, -2.9), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "VanRoof", Vector3.new(8.8, 0.45, 10.6), CFrame.new(0, 3.85, 1.8), carColor)
	addLego(model, chassis, "VanRoofRearTrim", Vector3.new(8.85, 0.45, 1.2), CFrame.new(0, 3.85, 6.5), cream)

	-- Caja trasera cerrada marrón con ojo de buey negro en cada lado
	addLego(model, chassis, "VanCargoBox", Vector3.new(8.8, 2.5, 7.6), CFrame.new(0, 2.4, 3.3), carColor)
	for _, side in ipairs({ -1, 1 }) do
		addLego(model, chassis, "Porthole", Vector3.new(0.4, 1.6, 1.6), CFrame.new(side * 4.5, 2.6, 5.2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(22, 24, 28), Enum.Material.Glass, Enum.PartType.Cylinder)
	end

	-- Antena parabólica blanca en el techo
	addLego(model, chassis, "DishArm", Vector3.new(0.5, 1.4, 0.5), CFrame.new(1.2, 4.7, 4.0), white)
	addLego(model, chassis, "RadarDish", Vector3.new(0.5, 2.4, 2.4), CFrame.new(1.2, 5.5, 3.6) * CFrame.Angles(math.rad(-25), 0, 0), white, Enum.Material.Plastic, Enum.PartType.Cylinder)

	-- Trasera: escalera gris izquierda, llanta de repuesto derecha y placa I ♥ UFO
	for y = 0.4, 3.4, 0.75 do
		addLego(model, chassis, "LadderRung", Vector3.new(1.8, 0.25, 0.4), CFrame.new(-2.4, y, 7.3), CHROME, Enum.Material.Metal)
	end
	addLego(model, chassis, "SpareTire", Vector3.new(1.1, 2.8, 2.8), CFrame.new(1.8, 1.8, 7.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(28, 28, 30), Enum.Material.Rubber, Enum.PartType.Cylinder)
	addLego(model, chassis, "SpareRim", Vector3.new(1.18, 1.7, 1.7), CFrame.new(1.8, 1.8, 7.4) * CFrame.Angles(0, math.rad(90), 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)

	local plate = addLego(model, chassis, "UFOPlate", Vector3.new(2.6, 1.0, 0.3), CFrame.new(0.6, 0.4, 7.15), white)
	local pGui = Instance.new("SurfaceGui")
	pGui.Face = Enum.NormalId.Back
	pGui.Parent = plate
	local pTxt = Instance.new("TextLabel")
	pTxt.Size = UDim2.fromScale(1, 1)
	pTxt.BackgroundTransparency = 1
	pTxt.Font = Enum.Font.GothamBlack
	pTxt.TextScaled = true
	pTxt.TextColor3 = Color3.fromRGB(25, 25, 28)
	pTxt.Text = "I ♥ UFO"
	pTxt.Parent = pGui
end

-- 6. MothTruck (Convoy) - Diseño LEGO fiel: tráiler naranja/blanco con escapes cromados y rack amarillo de neumáticos
builders.MothTruck = function(model, chassis, carColor)
	local white = Color3.fromRGB(242, 244, 248)
	local yellow = Color3.fromRGB(245, 200, 45)
	addLego(model, chassis, "HeavyGrille", Vector3.new(4.8, 2.6, 0.6), CFrame.new(0, 1.2, -7.1), CHROME, Enum.Material.Metal)
	addLego(model, chassis, "TruckHood", Vector3.new(5.4, 1.6, 3.2), CFrame.new(0, 1.6, -5.0), carColor, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "TruckCab", Vector3.new(6.8, 3.4, 4.2), CFrame.new(0, 2.6, -1.8), carColor)
	addLego(model, chassis, "CabStripe", Vector3.new(7.0, 1.1, 3.8), CFrame.new(0, 2.0, -1.8), white)
	addLego(model, chassis, "Windshield", Vector3.new(6.0, 1.4, 0.4), CFrame.new(0, 3.0, -4.0), DARK_GLASS, Enum.Material.Glass, 0.45)
	addLego(model, chassis, "TrailerDeck", Vector3.new(8.2, 0.8, 7.6), CFrame.new(0, 1.3, 3.8), Color3.fromRGB(45, 48, 54))
	for _, xOff in ipairs({ -3.7, 3.7 }) do
		addLego(model, chassis, "Stack", Vector3.new(0.7, 4.8, 0.7), CFrame.new(xOff, 3.8, 0.2), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
		addLego(model, chassis, "RackRail", Vector3.new(0.5, 1.8, 5.8), CFrame.new(xOff * 0.75, 2.6, 4.2), yellow)
		addLego(model, chassis, "SpikedTireCargo", Vector3.new(1.5, 3.6, 3.6), CFrame.new(xOff * 0.45, 3.4, 4.2), Color3.fromRGB(24, 24, 28), Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
end

-- 7. Glenn4x4 (Loki) - Diseño LEGO fiel: pickup militar camuflada con 3 misiles amarillos en la caja trasera
builders.Glenn4x4 = function(model, chassis, carColor)
	local desertTan = Color3.fromRGB(165, 152, 112)
	local yellow = Color3.fromRGB(245, 200, 45)
	addLego(model, chassis, "FrontGuard", Vector3.new(7.2, 1.8, 0.6), CFrame.new(0, 0.8, -7.3), desertTan)
	addLego(model, chassis, "CamoPatch1", Vector3.new(3.0, 0.35, 3.4), CFrame.new(-1.4, 1.0, -4.6), desertTan)
	addWedge(model, chassis, "Windshield", Vector3.new(7.2, 1.8, 1.6), CFrame.new(0, 1.9, -2.2), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "JeepRoof", Vector3.new(7.6, 0.45, 3.8), CFrame.new(0, 3.0, -0.2), carColor)
	addLego(model, chassis, "CamoRoof", Vector3.new(3.0, 0.5, 2.0), CFrame.new(1.6, 3.0, -0.2), desertTan)
	-- Rack lanzador con 3 misiles grandes en la caja trasera
	for _, xOff in ipairs({ -1.8, 0, 1.8 }) do
		addLego(model, chassis, "ScatterMslBody", Vector3.new(0.85, 0.85, 4.2), CFrame.new(xOff, 3.2, 4.0) * CFrame.Angles(math.rad(18), 0, 0), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
		addLego(model, chassis, "ScatterMslTip", Vector3.new(0.88, 0.88, 1.2), CFrame.new(xOff, 3.9, 2.0) * CFrame.Angles(math.rad(18), 0, 0), yellow, Enum.Material.Plastic, Enum.PartType.Cylinder)
	end
	addLego(model, chassis, "SpareTire", Vector3.new(1.2, 3.0, 3.0), CFrame.new(0, 1.5, 7.3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(28, 28, 30), Enum.Material.Rubber, Enum.PartType.Cylinder)
end

-- 8. Palomino (Houston 3) - Diseño LEGO fiel: muscle car carmesí con franjas negras, parrilla cromada y Death Ray
builders.Palomino = function(model, chassis, carColor)
	local black = Color3.fromRGB(26, 28, 32)
	addLego(model, chassis, "BlackSkirt", Vector3.new(9.3, 0.5, 13.8), CFrame.new(0, -0.6, 0), black)
	addLego(model, chassis, "ChromeGrille", Vector3.new(5.6, 1.1, 0.4), CFrame.new(0, 0.2, -7.1), CHROME, Enum.Material.Metal)
	addLego(model, chassis, "StripeL", Vector3.new(1.1, 0.25, 13.6), CFrame.new(-1.3, 1.0, 0), black, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "StripeR", Vector3.new(1.1, 0.25, 13.6), CFrame.new(1.3, 1.0, 0), black, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "HoodScoop", Vector3.new(2.2, 0.8, 2.4), CFrame.new(0, 1.35, -3.8), carColor, Enum.Material.SmoothPlastic)
	addWedge(model, chassis, "Windshield", Vector3.new(5.6, 1.8, 2.2), CFrame.new(0, 1.8, -1.2), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "CabinRoof", Vector3.new(5.8, 0.45, 4.2), CFrame.new(0, 2.6, 1.8), carColor, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "DeathRayPod", Vector3.new(1.2, 1.2, 3.6), CFrame.new(0, 3.7, 1.4), CHROME, Enum.Material.Metal, Enum.PartType.Cylinder)
	addLego(model, chassis, "DeathRayTip", Vector3.new(1.0, 1.0, 1.2), CFrame.new(0, 3.7, -0.8), Color3.fromRGB(70, 225, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	addLego(model, chassis, "Ducktail", Vector3.new(6.8, 0.7, 1.0), CFrame.new(0, 1.4, 6.6), carColor)
end

-- 9. Leprechaun (Boogie) - Diseño LEGO fiel: compacto verde lima/dorado con bola disco en el techo
builders.Leprechaun = function(model, chassis, carColor)
	local gold = Color3.fromRGB(215, 175, 85)
	addLego(model, chassis, "GoldGrille", Vector3.new(5.6, 1.1, 0.4), CFrame.new(0, 0.2, -7.1), gold)
	addLego(model, chassis, "GoldHood", Vector3.new(2.4, 0.25, 4.8), CFrame.new(0, 1.0, -4.4), gold, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "GoldDoorL", Vector3.new(0.3, 1.3, 4.6), CFrame.new(-4.7, 0.3, 0), gold)
	addLego(model, chassis, "GoldDoorR", Vector3.new(0.3, 1.3, 4.6), CFrame.new(4.7, 0.3, 0), gold)
	addWedge(model, chassis, "Windshield", Vector3.new(5.6, 1.8, 2.0), CFrame.new(0, 1.8, -1.2), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "DiscoRoof", Vector3.new(5.8, 0.45, 5.2), CFrame.new(0, 2.6, 2.0), carColor, Enum.Material.SmoothPlastic)
	-- Bola disco cromada en el techo (Disco Inferno)
	addLego(model, chassis, "DiscoStand", Vector3.new(0.8, 1.0, 0.8), CFrame.new(0, 3.2, 2.0), DARK_METAL)
	addLego(model, chassis, "DiscoBallProp", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 4.3, 2.0), CHROME, Enum.Material.Metal, Enum.PartType.Ball)
end

-- 10. StagPickup (Beezwax) - Diseño LEGO fiel: pickup verde con cámper blanco/salvia y colmena amarilla
builders.StagPickup = function(model, chassis, carColor)
	local white = Color3.fromRGB(242, 244, 248)
	local sage = Color3.fromRGB(112, 145, 118)
	local honey = Color3.fromRGB(240, 175, 40)

	-- Capó curvo verde, faros redondos y parachoques gris
	addWedge(model, chassis, "HoodSlope", Vector3.new(8.8, 0.5, 2.2), CFrame.new(0, 1.05, -6.0), carColor, Enum.Material.SmoothPlastic)
	for _, xOff in ipairs({ -3.2, 3.2 }) do
		addLego(model, chassis, "RoundLamp", Vector3.new(0.5, 1.1, 1.1), CFrame.new(xOff, 0.4, -7.1) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(245, 250, 255), Enum.Material.Glass, Enum.PartType.Cylinder, 0.25)
	end

	-- Cabina abierta con parabrisas translúcido
	addWedge(model, chassis, "Windshield", Vector3.new(7.4, 1.9, 1.8), CFrame.new(0, 1.9, -2.2), DARK_GLASS, Enum.Material.Glass, 0.48)

	-- Cámper blanco que sobresale sobre la cabina con franja verde salvia y ventanas oscuras
	addLego(model, chassis, "CamperOverhang", Vector3.new(8.6, 1.3, 4.4), CFrame.new(0, 3.6, -1.0), white)
	addLego(model, chassis, "CamperBody", Vector3.new(8.6, 3.1, 6.4), CFrame.new(0, 2.7, 4.2), white)
	addLego(model, chassis, "CamperSageStripe", Vector3.new(8.75, 0.9, 6.5), CFrame.new(0, 2.6, 4.2), sage)
	addLego(model, chassis, "CamperSideWin", Vector3.new(8.8, 0.9, 1.8), CFrame.new(0, 2.6, 4.8), DARK_GLASS, Enum.Material.Glass, 0.4)
	addLego(model, chassis, "CamperRearDoor", Vector3.new(2.2, 2.4, 0.4), CFrame.new(0, 1.8, 7.45), white)

	-- Colmena dorada característica colgada en el lateral derecho
	addLego(model, chassis, "HiveArm", Vector3.new(0.8, 0.35, 0.35), CFrame.new(4.5, 2.5, 4.2), Color3.fromRGB(95, 55, 32))
	addLego(model, chassis, "Beehive", Vector3.new(1.5, 1.9, 1.5), CFrame.new(4.9, 3.1, 4.2), honey, Enum.Material.Plastic, Enum.PartType.Cylinder)
end

-- 11. SchoolBus (Molo) - Diseño LEGO fiel: autobús grande amarillo con techo blanco, ventanas, parrilla y carteles
builders.SchoolBus = function(model, chassis, carColor)
	local black = Color3.fromRGB(30, 30, 34)
	local white = Color3.fromRGB(242, 244, 248)

	-- Laterales bajos anchos con pasos de rueda y franja negra inferior
	addWideBodyWithWheelArches(model, chassis, carColor)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 4.7
		addLego(model, chassis, "BusLowerStripe", Vector3.new(0.25, 0.55, 5.2), CFrame.new(x, 0.2, 0.0), black)
		addLego(model, chassis, "BusMidPanel", Vector3.new(0.3, 0.85, 14.0), CFrame.new(x * 0.96, 1.35, 0), carColor)
		addLego(model, chassis, "BusUpperStripe", Vector3.new(0.32, 0.3, 14.0), CFrame.new(x * 0.96, 1.9, 0), black)
		-- Ventanas laterales translúcidas con pilares negros
		addLego(model, chassis, "SideGlass", Vector3.new(0.2, 1.5, 12.6), CFrame.new(side * 4.45, 2.8, 0.2), DARK_GLASS, Enum.Material.Glass, nil, 0.45)
		for z = -5.5, 6.5, 2.0 do
			addLego(model, chassis, "WinMullion", Vector3.new(0.3, 1.6, 0.35), CFrame.new(side * 4.5, 2.8, z), black)
		end
	end

	-- Techo blanco característico y bordes amarillos
	addLego(model, chassis, "WhiteRoof", Vector3.new(7.4, 0.55, 11.2), CFrame.new(0, 3.85, 0.2), white)
	addLego(model, chassis, "RoofCapF", Vector3.new(8.6, 0.65, 2.0), CFrame.new(0, 3.8, -6.2), carColor)
	addLego(model, chassis, "RoofCapR", Vector3.new(8.6, 0.65, 2.2), CFrame.new(0, 3.8, 6.4), carColor)

	-- Frente chato con parrilla gris, parabrisas partido y cartel SCHOOL BUS
	addLego(model, chassis, "FrontGrille", Vector3.new(4.2, 1.7, 0.5), CFrame.new(0, 0.6, -7.2), CHROME, Enum.Material.Metal)
	addLego(model, chassis, "FrontWindshield", Vector3.new(8.2, 1.6, 0.3), CFrame.new(0, 2.7, -7.0), DARK_GLASS, Enum.Material.Glass, nil, 0.45)
	addLego(model, chassis, "FrontCenterPost", Vector3.new(0.4, 1.7, 0.4), CFrame.new(0, 2.7, -7.0), carColor)

	local frontSign = addLego(model, chassis, "FrontHeader", Vector3.new(8.4, 0.85, 0.6), CFrame.new(0, 3.7, -7.0), carColor)
	local fGui = Instance.new("SurfaceGui")
	fGui.Face = Enum.NormalId.Front
	fGui.Parent = frontSign
	local fTxt = Instance.new("TextLabel")
	fTxt.Size = UDim2.fromScale(1, 1)
	fTxt.BackgroundTransparency = 1
	fTxt.Font = Enum.Font.GothamBlack
	fTxt.TextScaled = true
	fTxt.TextColor3 = black
	fTxt.Text = "SCHOOL BUS"
	fTxt.Parent = fGui

	-- Parte trasera con letrero SCHOOL BUS / PREPARE TO STOP y luces rojas
	local rearPanel = addLego(model, chassis, "RearPanel", Vector3.new(8.4, 2.6, 0.5), CFrame.new(0, 2.0, 7.1), carColor)
	local rGui = Instance.new("SurfaceGui")
	rGui.Face = Enum.NormalId.Back
	rGui.Parent = rearPanel
	local rTxt = Instance.new("TextLabel")
	rTxt.Size = UDim2.fromScale(1, 1)
	rTxt.BackgroundTransparency = 1
	rTxt.Font = Enum.Font.GothamBlack
	rTxt.TextScaled = true
	rTxt.TextColor3 = black
	rTxt.Text = "SCHOOL BUS\nPREPARE TO STOP!"
	rTxt.Parent = rGui

	for _, xOff in ipairs({ -3.2, 3.2 }) do
		addLego(model, chassis, "BusTailLight", Vector3.new(0.9, 0.9, 0.4), CFrame.new(xOff, 1.2, 7.35), Color3.fromRGB(220, 35, 35), Enum.Material.Neon, Enum.PartType.Cylinder)
	end

	-- Señal roja STOP lateral
	local stopSign = addLego(model, chassis, "StopSign", Vector3.new(0.25, 1.3, 1.3), CFrame.new(-4.85, 1.6, -4.6), Color3.fromRGB(215, 35, 35))
	local sGui = Instance.new("SurfaceGui")
	sGui.Face = Enum.NormalId.Left
	sGui.Parent = stopSign
	local sTxt = Instance.new("TextLabel")
	sTxt.Size = UDim2.fromScale(1, 1)
	sTxt.BackgroundTransparency = 1
	sTxt.Font = Enum.Font.GothamBlack
	sTxt.TextScaled = true
	sTxt.TextColor3 = white
	sTxt.Text = "STOP"
	sTxt.Parent = sGui
end

-- 12. Manta (Sid Burn) - Diseño LEGO fiel: trompa amarilla/roja, flamas laterales naranja/amarillo y cola negra
builders.Manta = function(model, chassis, _carColor)
	local black = Color3.fromRGB(28, 30, 34)
	local yellow = Color3.fromRGB(245, 205, 45)
	local orange = Color3.fromRGB(240, 120, 35)
	local red = Color3.fromRGB(210, 45, 40)

	-- Capó amarillo curvo con acento rojo y zona negra frente al parabrisas
	addWedge(model, chassis, "YellowNoseSlope", Vector3.new(9.0, 0.7, 2.2), CFrame.new(0, 1.05, -6.0), yellow, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "YellowNose", Vector3.new(6.2, 0.35, 2.8), CFrame.new(0, 1.0, -4.2), yellow, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "RedNoseStripe", Vector3.new(2.2, 0.42, 1.4), CFrame.new(0, 1.02, -4.4), red, Enum.Material.SmoothPlastic)
	addLego(model, chassis, "BlackCowl", Vector3.new(5.8, 0.35, 2.0), CFrame.new(0, 1.0, -2.4), black)

	-- Carrocería ancha curva con degradado de flamas (Rojo -> Naranja -> Amarillo -> Negro)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 3.8
		addLego(model, chassis, "FrontCornerY", Vector3.new(1.7, 1.8, 1.2), CFrame.new(x, 0.0, -6.6), yellow)
		addCurvedArch(model, chassis, x, -4.4, red)
		addLego(model, chassis, "FlameDoorFront", Vector3.new(1.7, 1.8, 1.6), CFrame.new(x, 0.0, -1.8), red)
		addLego(model, chassis, "FlameDoorMid", Vector3.new(1.7, 1.8, 1.8), CFrame.new(x, 0.0, 0.0), orange)
		addLego(model, chassis, "FlameDoorYel", Vector3.new(1.7, 1.8, 1.8), CFrame.new(x, 0.0, 1.8), yellow)
		addWedge(model, chassis, "DoorBevel", Vector3.new(4.8, 0.45, 0.65), CFrame.new(x + side * 0.45, 1.05, 0.0) * CFrame.Angles(0, math.rad(if side < 0 then 90 else -90), 0), orange, Enum.Material.SmoothPlastic)
		addCurvedArch(model, chassis, x, 4.4, black)
		addLego(model, chassis, "RearCornerBlack", Vector3.new(1.7, 1.8, 1.2), CFrame.new(x, 0.0, 6.6), black)
		addWedge(model, chassis, "RearTailCurve", Vector3.new(1.7, 0.7, 1.2), CFrame.new(x, 1.0, 6.5) * CFrame.Angles(0, math.rad(180), 0), black, Enum.Material.SmoothPlastic)
	end

	-- Cabina negra hueca con ventanas abiertas para ver al piloto
	addWedge(model, chassis, "Windshield", Vector3.new(5.6, 1.8, 2.2), CFrame.new(0, 1.8, -1.2), DARK_GLASS, Enum.Material.Glass, 0.48)
	addLego(model, chassis, "CabinRoof", Vector3.new(6.0, 0.45, 4.2), CFrame.new(0, 2.6, 1.8), black)
	addLego(model, chassis, "PillarL", Vector3.new(0.6, 1.7, 1.6), CFrame.new(-2.6, 1.7, 3.1), black)
	addLego(model, chassis, "PillarR", Vector3.new(0.6, 1.7, 1.6), CFrame.new(2.6, 1.7, 3.1), black)
	addWedge(model, chassis, "RearGlass", Vector3.new(3.6, 1.1, 2.2), CFrame.new(0, 1.45, 4.8) * CFrame.Angles(0, math.rad(180), 0), DARK_GLASS, Enum.Material.Glass, 0.25)
	addLego(model, chassis, "RearDeck", Vector3.new(6.4, 0.7, 2.2), CFrame.new(0, 1.1, 5.8), black)

	-- Franja trasera tricolor (Rojo - Naranja - Amarillo - Naranja - Rojo)
	addLego(model, chassis, "TailR1", Vector3.new(1.4, 1.3, 0.4), CFrame.new(-2.8, 0.4, 7.1), red)
	addLego(model, chassis, "TailO1", Vector3.new(1.4, 1.3, 0.4), CFrame.new(-1.4, 0.4, 7.1), orange)
	addLego(model, chassis, "TailY", Vector3.new(1.4, 1.3, 0.4), CFrame.new(0, 0.4, 7.1), yellow)
	addLego(model, chassis, "TailO2", Vector3.new(1.4, 1.3, 0.4), CFrame.new(1.4, 0.4, 7.1), orange)
	addLego(model, chassis, "TailR2", Vector3.new(1.4, 1.3, 0.4), CFrame.new(2.8, 0.4, 7.1), red)
end

-- 13. LuxoSaucer (Y The Alien) - Diseño LEGO fiel: platillo gris metálico con tomas negras, espina dorsal y base flotante
builders.LuxoSaucer = function(model, chassis, carColor)
	local medGray = Color3.fromRGB(130, 134, 140)
	local black = Color3.fromRGB(26, 28, 32)

	-- Casco principal tipo platillo en capas (con ranura oscura en el borde)
	addLego(model, chassis, "SaucerLower", Vector3.new(1.1, 12.6, 12.6), CFrame.new(0, 0.2, -0.5) * CFrame.Angles(0, 0, math.rad(90)), carColor, Enum.Material.Plastic, Enum.PartType.Cylinder)
	addLego(model, chassis, "SaucerSlit", Vector3.new(0.45, 13.8, 13.8), CFrame.new(0, 0.9, -0.5) * CFrame.Angles(0, 0, math.rad(90)), black, Enum.Material.Plastic, Enum.PartType.Cylinder)
	addLego(model, chassis, "SaucerUpper", Vector3.new(1.3, 13.2, 13.2), CFrame.new(0, 1.5, -0.5) * CFrame.Angles(0, 0, math.rad(90)), carColor, Enum.Material.Plastic, Enum.PartType.Cylinder)
	addLego(model, chassis, "SaucerCap", Vector3.new(0.8, 9.6, 9.6), CFrame.new(0, 2.3, -0.4) * CFrame.Angles(0, 0, math.rad(90)), carColor, Enum.Material.Plastic, Enum.PartType.Cylinder)

	-- Espina dorsal central y rejilla trasera
	addLego(model, chassis, "DorsalSpine", Vector3.new(2.2, 1.4, 8.6), CFrame.new(0, 2.9, 2.4), medGray)
	addLego(model, chassis, "RearGrille", Vector3.new(2.4, 2.0, 1.0), CFrame.new(0, 1.9, 6.8), medGray)
	addLego(model, chassis, "RearBumper", Vector3.new(3.0, 1.1, 1.0), CFrame.new(0, 0.6, 7.0), carColor)

	-- Dos bahías laterales curvas negras en la parte trasera
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 5.2
		addLego(model, chassis, "PodFrame", Vector3.new(2.2, 3.2, 4.8), CFrame.new(x, 1.2, 3.2), medGray)
		addLego(model, chassis, "PodBlackCore", Vector3.new(1.8, 2.5, 4.0), CFrame.new(side * 5.6, 1.2, 3.2), black)
	end

	-- Base flotante translúcida debajo del platillo
	addLego(model, chassis, "HoverPillar", Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, -0.9, 0), Color3.fromRGB(220, 235, 245), Enum.Material.Glass, nil, 0.55)
	addLego(model, chassis, "HoverDisc", Vector3.new(0.35, 8.0, 8.0), CFrame.new(0, -1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 235, 245), Enum.Material.Glass, Enum.PartType.Cylinder, 0.65)
end

function VehicleModels.Build(vehicleId: string, model: Model, chassis: BasePart, carColor: Color3)
	currentScale = (model:GetAttribute("VehicleScale") :: number?) or Config.VEHICLE.SCALE or 1.35
	if vehicleId == "LuxoSaucer" then
		chassis.Transparency = 1
	elseif vehicleId ~= "Strider" and vehicleId ~= "Manta" and vehicleId ~= "SchoolBus" and vehicleId ~= "Van" then
		addWideBodyWithWheelArches(model, chassis, carColor)
	end
	if vehicleId == "Manta" then
		chassis.Color = Color3.fromRGB(28, 30, 34)
	end
	local builder = builders[vehicleId] or builders.Rattler
	builder(model, chassis, carColor)
end

return VehicleModels
