--!strict
-- StarterPlayer/StarterPlayerScripts/RetroHUDClient.client.luau
-- Tablero retro años 70 estilo Vigilante 8: velocidad, integridad, slots de armas y mira Lock-On.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Paleta de colores Retro Años 70 (Naranja cálido, crema, cromo y verde neón)
local COLORS = {
	PanelBg = Color3.fromRGB(28, 22, 18),        -- Marrón oscuro tablero clásico
	BorderChrome = Color3.fromRGB(210, 195, 165), -- Borde beige/cromo retro
	AccentOrange = Color3.fromRGB(245, 125, 25),  -- Naranja años 70
	HealthGreen = Color3.fromRGB(85, 215, 75),    -- Verde saludable
	HealthWarn = Color3.fromRGB(245, 195, 35),    -- Amarillo precaución
	HealthCrit = Color3.fromRGB(235, 45, 45),     -- Rojo daño crítico
	LockRed = Color3.fromRGB(255, 35, 35),        -- Mira Lock-On
	TextCream = Color3.fromRGB(250, 240, 215),    -- Texto crema
}

-- =========================================================================
-- 1. CONSTRUCCIÓN DE LA INTERFAZ RETRO (ScreenGui)
-- =========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VigilanteRetroHUD"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false -- Oculto hasta que el jugador suba a un auto
screenGui.Parent = playerGui

-- Helper para estilizar contenedores estilo tablero de los 70
local function createRetroFrame(name: string, size: UDim2, pos: UDim2, anchor: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = COLORS.PanelBg
	frame.BackgroundTransparency = 0.15
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.BorderChrome
	stroke.Thickness = 2.5
	stroke.Parent = frame

	return frame
end

-- PANEL INFERIOR IZQUIERDO: Integridad del Vehículo y Velocímetro (junto al radar sin taparlo)
local statsPanel = createRetroFrame("StatsPanel", UDim2.new(0, 260, 0, 105), UDim2.new(0, 182, 1, -20), Vector2.new(0, 1))

local vehicleNameLabel = Instance.new("TextLabel")
vehicleNameLabel.Size = UDim2.new(1, -20, 0, 24)
vehicleNameLabel.Position = UDim2.new(0, 10, 0, 6)
vehicleNameLabel.BackgroundTransparency = 1
vehicleNameLabel.Font = Enum.Font.LuckiestGuy
vehicleNameLabel.TextColor3 = COLORS.AccentOrange
vehicleNameLabel.TextSize = 18
vehicleNameLabel.TextXAlignment = Enum.TextXAlignment.Left
vehicleNameLabel.Text = "VEHICLE READY"
vehicleNameLabel.Parent = statsPanel

-- Barra de Vida (Chassis Integrity)
local hpBg = Instance.new("Frame")
hpBg.Size = UDim2.new(1, -20, 0, 18)
hpBg.Position = UDim2.new(0, 10, 0, 34)
hpBg.BackgroundColor3 = Color3.fromRGB(15, 12, 10)
hpBg.Parent = statsPanel
Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 4)

local hpFill = Instance.new("Frame")
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = COLORS.HealthGreen
hpFill.Parent = hpBg
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 4)

local hpText = Instance.new("TextLabel")
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Font = Enum.Font.GothamBold
hpText.TextColor3 = COLORS.TextCream
hpText.TextSize = 12
hpText.Text = "ARMOR: 100%"
hpText.Parent = hpBg

-- Velocímetro Digital Retro (MPH)
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 36)
speedLabel.Position = UDim2.new(0, 10, 0, 58)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.Code
speedLabel.TextColor3 = COLORS.TextCream
speedLabel.TextSize = 26
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Text = "000 MPH"
speedLabel.Parent = statsPanel

-- PANEL INFERIOR DERECHO: Slots de Armas (encima del HUD de velocidad/turbo para no solaparse)
local weaponsPanel = createRetroFrame("WeaponsPanel", UDim2.new(0, 270, 0, 105), UDim2.new(1, -20, 1, -200), Vector2.new(1, 1))

local function createWeaponSlot(title: string, yPos: number, isSpecial: boolean): TextLabel
	local slotFrame = Instance.new("Frame")
	slotFrame.Size = UDim2.new(1, -16, 0, 26)
	slotFrame.Position = UDim2.new(0, 8, 0, yPos)
	slotFrame.BackgroundColor3 = if isSpecial then Color3.fromRGB(35, 65, 30) else Color3.fromRGB(45, 38, 32)
	slotFrame.Parent = weaponsPanel
	Instance.new("UICorner", slotFrame).CornerRadius = UDim.new(0, 4)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = if isSpecial then Color3.fromRGB(140, 255, 120) else COLORS.TextCream
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = title .. ": EMPTY"
	label.Parent = slotFrame

	return label
end

local specialSlotLabel = createWeaponSlot("[CLICK] SPECIAL", 8, true)
local leftSlotLabel = createWeaponSlot("[E] LEFT", 40, false)
local rightSlotLabel = createWeaponSlot("[Q] RIGHT", 72, false)

-- MIRA DE FIJACIÓN DE OBJETIVO (LOCK-ON RETICLE EN PANTALLA)
local lockReticle = Instance.new("Frame")
lockReticle.Name = "LockOnReticle"
lockReticle.Size = UDim2.new(0, 74, 0, 74)
lockReticle.AnchorPoint = Vector2.new(0.5, 0.5)
lockReticle.BackgroundTransparency = 1
lockReticle.Visible = false
lockReticle.Parent = screenGui

local reticleStroke = Instance.new("UIStroke")
reticleStroke.Color = COLORS.LockRed
reticleStroke.Thickness = 3
reticleStroke.Parent = lockReticle

local lockText = Instance.new("TextLabel")
lockText.Size = UDim2.new(1, 40, 0, 18)
lockText.Position = UDim2.new(0.5, 0, 1, 4)
lockText.AnchorPoint = Vector2.new(0.5, 0)
lockText.BackgroundTransparency = 1
lockText.Font = Enum.Font.Code
lockText.TextColor3 = COLORS.LockRed
lockText.TextSize = 14
lockText.Text = "[ TARGET LOCKED ]"
lockText.Parent = lockReticle

-- =========================================================================
-- 2. ACTUALIZACIÓN EN TIEMPO REAL
-- =========================================================================
local function getPlayerVehicle(): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		return humanoid.SeatPart:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function updateWeaponLabel(equippedFolder: Instance?, mountName: string, prefix: string, label: TextLabel)
	local weapon = if equippedFolder then equippedFolder:FindFirstChild(mountName) else nil
	if weapon then
		local wId = (weapon:GetAttribute("WeaponId") :: string?) or "WEAPON"
		local ammo = (weapon:GetAttribute("Ammo") :: number?) or 0
		label.Text = string.format("%s: %s [%d]", prefix, string.upper(wId), ammo)
	else
		label.Text = prefix .. ": EMPTY"
	end
end

-- Buscar enemigo frente a la cámara para dibujar la mira roja
local function findScreenTarget(myVehicle: Model, camera: Camera): Model?
	local bestTarget: Model? = nil
	local bestScore = -1
	local camLook = camera.CFrame.LookVector

	for _, vehicle in ipairs(CollectionService:GetTagged("CombatVehicle")) do
		if vehicle:IsA("Model") and vehicle ~= myVehicle and vehicle.PrimaryPart and ((vehicle:GetAttribute("Health") :: number?) or 0) > 0 then
			local toTarget = vehicle.PrimaryPart.Position - camera.CFrame.Position
			if toTarget.Magnitude > 0.001 and toTarget.Magnitude <= 250 then
				local dot = camLook:Dot(toTarget.Unit)
				if dot >= 0.85 and dot > bestScore then
					bestScore = dot
					bestTarget = vehicle
				end
			end
		end
	end
	return bestTarget
end

RunService.RenderStepped:Connect(function(dt: number)
	local myVehicle = getPlayerVehicle()
	local camera = workspace.CurrentCamera
	if not myVehicle or not myVehicle.PrimaryPart or not camera then
		screenGui.Enabled = false
		return
	end

	screenGui.Enabled = true
	vehicleNameLabel.Text = string.upper(myVehicle.Name)

	-- 1. Actualizar Barra de Salud y Color
	local hp = (myVehicle:GetAttribute("Health") :: number?) or 100
	local maxHp = math.max(1, (myVehicle:GetAttribute("MaxHealth") :: number?) or 100)
	local ratio = math.clamp(hp / maxHp, 0, 1)

	hpFill.Size = UDim2.new(ratio, 0, 1, 0)
	hpText.Text = string.format("ARMOR: %d%%", math.floor(ratio * 100))

	if ratio > 0.5 then
		hpFill.BackgroundColor3 = COLORS.HealthGreen
	elseif ratio > 0.25 then
		hpFill.BackgroundColor3 = COLORS.HealthWarn
	else
		hpFill.BackgroundColor3 = COLORS.HealthCrit
	end

	-- 2. Actualizar Velocímetro (Conversión de Studs/s a MPH arcade)
	local speedStuds = myVehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude
	local mph = math.floor(speedStuds * 0.85)
	speedLabel.Text = string.format("%03d MPH", mph)

	-- 3. Actualizar Slots de Armas Equipadas
	local equipped = myVehicle:FindFirstChild("EquippedWeapons")
	updateWeaponLabel(equipped, "RoofMount", "[CLICK] SPECIAL", specialSlotLabel)
	updateWeaponLabel(equipped, "LeftSideMount", "[E] LEFT", leftSlotLabel)
	updateWeaponLabel(equipped, "RightSideMount", "[Q] RIGHT", rightSlotLabel)

	-- 4. Posicionar Mira Lock-On sobre el enemigo en pantalla
	local target = findScreenTarget(myVehicle, camera)
	if target and target.PrimaryPart then
		local screenPos, onScreen = camera:WorldToViewportPoint(target.PrimaryPart.Position)
		if onScreen then
			lockReticle.Visible = true
			lockReticle.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
			lockReticle.Rotation = (lockReticle.Rotation + 90 * dt) % 360 -- Giro táctico continuo
		else
			lockReticle.Visible = false
		end
	else
		lockReticle.Visible = false
	end
end)
