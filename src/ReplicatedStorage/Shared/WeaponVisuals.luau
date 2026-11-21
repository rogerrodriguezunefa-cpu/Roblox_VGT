local Config = require(script.Parent:WaitForChild("Config"))
local WeaponVisuals = {}
local currentScale = Config.VEHICLE.SCALE or 1.35

local function addLegoPart(parent: Instance, chassis: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * currentScale
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = chassis.CFrame * (CFrame.new(offset.Position * currentScale) * (offset - offset.Position))
	p.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function buildRocketsPod(folder: Instance, chassis: BasePart)
	-- Caja lanzacohetes frontal gris oscuro (Bull's Eye Rockets)
	addLegoPart(folder, chassis, "RocketsPodBase", Vector3.new(2.8, 1.8, 2.0), CFrame.new(0, 1.8, -6.2), Color3.fromRGB(75, 78, 84))
	for row = 0, 1 do
		for col = -1, 1 do
			addLegoPart(folder, chassis, "RocketTube", Vector3.new(0.6, 0.6, 2.1), CFrame.new(col * 0.8, 1.4 + row * 0.8, -6.3), Color3.fromRGB(25, 25, 28))
		end
	end
end

local function buildInterceptorRack(folder: Instance, chassis: BasePart)
	-- 3 misiles con punta amarilla en el lateral derecho (Interceptor Missiles)
	addLegoPart(folder, chassis, "MissileRack", Vector3.new(0.6, 1.6, 2.6), CFrame.new(4.7, 1.2, 2.0), Color3.fromRGB(245, 200, 45))
	for _, mOff in ipairs({ Vector3.new(5.2, 1.6, 2.0), Vector3.new(5.2, 0.8, 2.4), Vector3.new(5.2, 0.8, 1.6) }) do
		addLegoPart(folder, chassis, "MissileBody", Vector3.new(0.7, 0.7, 2.6), CFrame.new(mOff) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(165, 170, 175), Enum.Material.Plastic, Enum.PartType.Cylinder)
		addLegoPart(folder, chassis, "MissileTip", Vector3.new(0.72, 0.72, 0.9), CFrame.new(mOff + Vector3.new(0, 0, -1.5)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(245, 200, 45), Enum.Material.Plastic, Enum.PartType.Cylinder)
	end
end

local function buildBruiserCannon(folder: Instance, chassis: BasePart)
	-- Torreta amarilla y gris en el techo con cañón negro largo (Bruiser Cannon)
	addLegoPart(folder, chassis, "CannonMount", Vector3.new(1.8, 1.2, 1.8), CFrame.new(0, 3.6, 1.0), Color3.fromRGB(130, 134, 140))
	addLegoPart(folder, chassis, "CannonHead", Vector3.new(2.2, 1.1, 3.2), CFrame.new(0, 4.4, 0.8), Color3.fromRGB(245, 200, 45))
	addLegoPart(folder, chassis, "CannonTop", Vector3.new(1.8, 0.5, 2.2), CFrame.new(0, 5.1, 1.2), Color3.fromRGB(210, 214, 220))
	addLegoPart(folder, chassis, "CannonBarrel", Vector3.new(0.45, 0.45, 4.6), CFrame.new(0, 4.4, -3.0), Color3.fromRGB(25, 25, 28))
	addLegoPart(folder, chassis, "CannonMuzzle", Vector3.new(0.8, 0.8, 0.6), CFrame.new(0, 4.4, -5.4), Color3.fromRGB(245, 200, 45))
end

local function buildMortarLauncher(folder: Instance, chassis: BasePart)
	-- Mortero grande en el lateral izquierdo (Sky Hammer Mortar)
	addLegoPart(folder, chassis, "MortarDrum", Vector3.new(2.0, 2.0, 3.2), CFrame.new(-5.2, 1.7, 0.5) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(165, 170, 175), Enum.Material.Plastic, Enum.PartType.Cylinder)
	addLegoPart(folder, chassis, "MortarRing", Vector3.new(2.2, 2.2, 0.6), CFrame.new(-5.2, 2.2, -0.8) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(245, 200, 45), Enum.Material.Plastic, Enum.PartType.Cylinder)
end

local function buildMinesDispenser(folder: Instance, chassis: BasePart)
	-- Bandeja amarilla trasera dispensadora de minas (Roadkill Mines)
	addLegoPart(folder, chassis, "MineTray", Vector3.new(3.2, 0.7, 2.0), CFrame.new(0, 0.6, 7.8), Color3.fromRGB(245, 200, 45))
	addLegoPart(folder, chassis, "MineDisc", Vector3.new(0.5, 1.6, 1.6), CFrame.new(0, 1.0, 7.9) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 175, 180), Enum.Material.Plastic, Enum.PartType.Cylinder)
end

local function buildExclusiveMount(folder: Instance, chassis: BasePart)
	-- Arma especial exclusiva sobre el capó (ej. cañón/emisor Gridlock)
	addLegoPart(folder, chassis, "ExclusiveBarrel", Vector3.new(0.9, 0.9, 3.2), CFrame.new(-1.5, 2.1, -3.5), Color3.fromRGB(165, 170, 175))
	addLegoPart(folder, chassis, "ExclusiveCore", Vector3.new(1.1, 1.1, 0.7), CFrame.new(-1.5, 2.1, -5.0), Color3.fromRGB(65, 225, 255), Enum.Material.Neon)
end

function WeaponVisuals.Refresh(car: Model)
	local chassis = car.PrimaryPart
	if not chassis then
		return
	end
	currentScale = (car:GetAttribute("VehicleScale") :: number?) or Config.VEHICLE.SCALE or 1.35

	local old = car:FindFirstChild("MountedWeapons")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "MountedWeapons"
	folder.Parent = car

	local equipped: { [string]: boolean } = {}
	for slot = 1, 3 do
		local wId = car:GetAttribute("Slot" .. slot .. "Weapon") :: string?
		local ammo = (car:GetAttribute("Slot" .. slot .. "Ammo") :: number?) or 0
		if wId and ammo > 0 then
			equipped[wId] = true
		end
	end

	if equipped.Rockets then
		buildRocketsPod(folder, chassis)
	end
	if equipped.Interceptor then
		buildInterceptorRack(folder, chassis)
	end
	if equipped.Cannon then
		buildBruiserCannon(folder, chassis)
	end
	if equipped.Mortar then
		buildMortarLauncher(folder, chassis)
	end
	if equipped.Mines then
		buildMinesDispenser(folder, chassis)
	end

	local exAmmo = (car:GetAttribute("ExclusiveSpecialAmmo") :: number?) or 0
	if exAmmo > 0 then
		buildExclusiveMount(folder, chassis)
	end
end

return WeaponVisuals
