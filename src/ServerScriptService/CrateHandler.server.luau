local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local pickupFolder = Instance.new("Folder")
pickupFolder.Name = "Pickups"
pickupFolder.Parent = Workspace

type PickupType = "Repair" | "SpecialCrate" | "Interceptor" | "Rockets" | "Mortar" | "Cannon" | "Mines"

type PickupStyle = {
	Color: Color3,
	Label: string,
}

local STYLES: { [PickupType]: PickupStyle } = {
	Repair = {
		Color = Color3.fromRGB(115, 240, 255),
		Label = "+45 HP",
	},
	SpecialCrate = {
		Color = Color3.fromRGB(45, 255, 85),
		Label = "ESPECIAL +4",
	},
	Interceptor = {
		Color = Config.WEAPONS.CATALOG.Interceptor.Color,
		Label = "MISILES x" .. Config.WEAPONS.CATALOG.Interceptor.Ammo,
	},
	Rockets = {
		Color = Config.WEAPONS.CATALOG.Rockets.Color,
		Label = "COHETES x" .. Config.WEAPONS.CATALOG.Rockets.Ammo,
	},
	Mortar = {
		Color = Config.WEAPONS.CATALOG.Mortar.Color,
		Label = "MORTERO x" .. Config.WEAPONS.CATALOG.Mortar.Ammo,
	},
	Cannon = {
		Color = Config.WEAPONS.CATALOG.Cannon.Color,
		Label = "CAÑÓN x" .. Config.WEAPONS.CATALOG.Cannon.Ammo,
	},
	Mines = {
		Color = Config.WEAPONS.CATALOG.Mines.Color,
		Label = "MINAS x" .. Config.WEAPONS.CATALOG.Mines.Ammo,
	},
}

local activePads: { Part } = {}

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

local function giveWeaponToCar(car: Model, weaponId: string)
	local cfg = Config.WEAPONS.CATALOG[weaponId]
	if not cfg then
		return
	end

	local activeSlot = (car:GetAttribute("ActiveSlot") :: number?) or 1

	-- 1. Si ya tiene esta arma en algún slot, recargar munición
	for slot = 1, Config.WEAPONS.MAX_SLOTS do
		local w = car:GetAttribute("Slot" .. slot .. "Weapon")
		if w == weaponId then
			local curAmmo = (car:GetAttribute("Slot" .. slot .. "Ammo") :: number?) or 0
			car:SetAttribute("Slot" .. slot .. "Ammo", math.min(cfg.Ammo * 2, curAmmo + cfg.Ammo))
			return
		end
	end

	-- 2. Si hay un slot vacío, guardarla ahí y seleccionarlo
	for slot = 1, Config.WEAPONS.MAX_SLOTS do
		local w = car:GetAttribute("Slot" .. slot .. "Weapon")
		if not w or w == "" then
			car:SetAttribute("Slot" .. slot .. "Weapon", weaponId)
			car:SetAttribute("Slot" .. slot .. "Ammo", cfg.Ammo)
			car:SetAttribute("ActiveSlot", slot)
			return
		end
	end

	-- 3. Si los 3 slots están llenos, reemplazar el slot activo
	car:SetAttribute("Slot" .. activeSlot .. "Weapon", weaponId)
	car:SetAttribute("Slot" .. activeSlot .. "Ammo", cfg.Ammo)
end

local function createPickup(pickupType: PickupType, position: Vector3)
	local style = STYLES[pickupType]

	local pad = Instance.new("Part")
	pad.Name = "Pickup_" .. pickupType
	pad.Size = Vector3.new(4.2, 4.2, 4.2)
	pad.CFrame = CFrame.new(position)
	pad.Anchored = true
	pad.CanCollide = false
	pad.Material = Enum.Material.Neon
	pad.Color = style.Color
	pad:SetAttribute("PickupType", pickupType)
	pad:SetAttribute("Available", true)
	pad:SetAttribute("BaseY", position.Y)
	pad.Parent = pickupFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LabelGui"
	billboard.Size = UDim2.new(0, 128, 0, 28)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pad
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = style.Color
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = style.Label
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label

	pad.Touched:Connect(function(hit: BasePart)
		if not pad:GetAttribute("Available") then
			return
		end
		local car = findVehicleModel(hit)
		if not car or car:GetAttribute("Destroyed") or car:GetAttribute("IsBot") then
			return
		end

		local consumed = false
		if pickupType == "Repair" then
			local hp = (car:GetAttribute("Health") :: number?) or Config.VEHICLE.MAX_HEALTH
			local maxHp = (car:GetAttribute("MaxHealth") :: number?) or Config.VEHICLE.MAX_HEALTH
			if hp < maxHp then
				car:SetAttribute("Health", math.min(maxHp, hp + Config.WEAPONS.REPAIR_AMOUNT))
				consumed = true
			end
		elseif pickupType == "SpecialCrate" then
			local cur = (car:GetAttribute("ExclusiveSpecialAmmo") :: number?) or 0
			car:SetAttribute("ExclusiveSpecialAmmo", math.min(8, cur + 4))
			consumed = true
		else
			giveWeaponToCar(car, pickupType)
			consumed = true
		end

		if consumed then
			pad:SetAttribute("Available", false)
			pad.Transparency = 1
			billboard.Enabled = false

			task.delay(Config.WEAPONS.PICKUP_RESPAWN, function()
				if pad.Parent then
					pad:SetAttribute("Available", true)
					pad.Transparency = 0
					billboard.Enabled = true
				end
			end)
		end
	end)

	table.insert(activePads, pad)
end

-- Distribuir las 5 armas estándar, reparaciones y cajas verdes bien separadas en la arena (1200x1200)
local spawnLayout: { { Type: PickupType, Pos: Vector3 } } = {
	{ Type = "SpecialCrate", Pos = Vector3.new(0, 10.5, 0) },
	{ Type = "SpecialCrate", Pos = Vector3.new(-360, 4.5, -340) },
	{ Type = "SpecialCrate", Pos = Vector3.new(360, 4.5, 340) },
	{ Type = "Interceptor", Pos = Vector3.new(-210, 4.5, -60) },
	{ Type = "Interceptor", Pos = Vector3.new(280, 4.5, 220) },
	{ Type = "Rockets", Pos = Vector3.new(210, 4.5, -60) },
	{ Type = "Rockets", Pos = Vector3.new(-280, 4.5, 240) },
	{ Type = "Mortar", Pos = Vector3.new(0, 4.5, -260) },
	{ Type = "Mortar", Pos = Vector3.new(-380, 4.5, 80) },
	{ Type = "Cannon", Pos = Vector3.new(0, 4.5, 260) },
	{ Type = "Cannon", Pos = Vector3.new(380, 4.5, -80) },
	{ Type = "Mines", Pos = Vector3.new(-160, 4.5, -380) },
	{ Type = "Mines", Pos = Vector3.new(160, 4.5, 380) },
	{ Type = "Repair", Pos = Vector3.new(-340, 4.5, -120) },
	{ Type = "Repair", Pos = Vector3.new(340, 4.5, 120) },
	{ Type = "Repair", Pos = Vector3.new(0, 4.5, 440) },
}

for _, item in ipairs(spawnLayout) do
	createPickup(item.Type, item.Pos)
end

-- Animación de giro y flotación
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for i, pad in ipairs(activePads) do
		if pad.Parent and pad:GetAttribute("Available") then
			local baseY = (pad:GetAttribute("BaseY") :: number?) or 4.5
			local bob = math.sin(t * 2.5 + i) * 0.6
			pad.CFrame = CFrame.new(pad.Position.X, baseY + bob, pad.Position.Z)
				* CFrame.Angles(0, t * 2.0, math.rad(25))
		end
	end
end)
