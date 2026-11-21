local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local I18n = require(Shared:WaitForChild("I18n"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local flipRemote = Remotes:WaitForChild("FlipVehicle") :: RemoteEvent
local firePrimary = Remotes:WaitForChild("FirePrimary") :: RemoteEvent
local fireSpecial = Remotes:WaitForChild("FireSpecial") :: RemoteEvent
local fireExclusiveSpecial = Remotes:WaitForChild("FireExclusiveSpecial") :: RemoteEvent
local selectWeaponSlot = Remotes:WaitForChild("SelectWeaponSlot") :: RemoteEvent
local bulletEffect = Remotes:WaitForChild("BulletEffect") :: RemoteEvent
local selectVehicleRemote = Remotes:WaitForChild("SelectVehicle") :: RemoteEvent
local selectArenaRemote = Remotes:WaitForChild("SelectArena") :: RemoteEvent
local returnToGarageRemote = Remotes:WaitForChild("ReturnToGarage") :: RemoteEvent
local killFeedRemote = Remotes:WaitForChild("KillFeed") :: RemoteEvent

local matchState = ReplicatedStorage:WaitForChild("MatchState")
local phaseVal = matchState:WaitForChild("Phase") :: StringValue
local timeLeftVal = matchState:WaitForChild("TimeLeft") :: IntValue
local winnerVal = matchState:WaitForChild("WinnerText") :: StringValue

local activeCar: Model? = nil
local activeSeat: VehicleSeat? = nil
local lockedTarget: Model? = nil
local turboEnergy = Config.VEHICLE.TURBO_MAX
local lastFireClient = 0

-- Retícula 3D de fijado de objetivo (Lock-on)
local lockGui = Instance.new("BillboardGui")
lockGui.Name = "LockOnReticle"
lockGui.Size = UDim2.new(0, 86, 0, 86)
lockGui.AlwaysOnTop = true
lockGui.Enabled = false
lockGui.Parent = player:WaitForChild("PlayerGui")

local lockBox = Instance.new("Frame")
lockBox.Size = UDim2.fromScale(1, 1)
lockBox.BackgroundTransparency = 1
lockBox.Parent = lockGui

local lockStroke = Instance.new("UIStroke")
lockStroke.Color = Color3.fromRGB(255, 65, 55)
lockStroke.Thickness = 2.5
lockStroke.Parent = lockBox

local lockLabel = Instance.new("TextLabel")
lockLabel.Size = UDim2.new(1, 0, 0, 18)
lockLabel.Position = UDim2.new(0, 0, 1, 2)
lockLabel.BackgroundTransparency = 1
lockLabel.Font = Enum.Font.GothamBlack
lockLabel.TextColor3 = Color3.fromRGB(255, 85, 65)
lockLabel.TextStrokeTransparency = 0.2
lockLabel.TextSize = 12
lockLabel.Text = "[ TARGET ]"
lockLabel.Parent = lockBox

-- ==========================================
-- HUD BÁSICO DE CONDUCCIÓN (Fase 1)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "V8_StarterHUD"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local isTouch = UserInputService.TouchEnabled

local container = Instance.new("Frame")
container.Name = "StatsPanel"
container.Size = if isTouch then UDim2.new(0, 224, 0, 134) else UDim2.new(0, 310, 0, 168)
container.Position = if isTouch then UDim2.new(1, -234, 0, 44) else UDim2.new(1, -330, 1, -188)
container.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
container.BackgroundTransparency = 0.25
container.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = container

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Size = UDim2.new(0.5, -10, 0, 32)
speedLabel.Position = UDim2.new(0, 10, 0, 8)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamBlack
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.TextSize = 22
speedLabel.Text = "0 KM/H"
speedLabel.Parent = container

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "HealthLabel"
healthLabel.Size = UDim2.new(0.5, -10, 0, 32)
healthLabel.Position = UDim2.new(0.5, 0, 0, 8)
healthLabel.BackgroundTransparency = 1
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextColor3 = Color3.fromRGB(95, 225, 115)
healthLabel.TextXAlignment = Enum.TextXAlignment.Right
healthLabel.TextSize = 18
healthLabel.Text = "HP 100"
healthLabel.Parent = container

local healthBg = Instance.new("Frame")
healthBg.Name = "HealthBg"
healthBg.Size = UDim2.new(1, -20, 0, 14)
healthBg.Position = UDim2.new(0, 10, 0, 44)
healthBg.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
healthBg.BorderSizePixel = 0
healthBg.Parent = container

local healthBgCorner = Instance.new("UICorner")
healthBgCorner.CornerRadius = UDim.new(0, 4)
healthBgCorner.Parent = healthBg

local healthFill = Instance.new("Frame")
healthFill.Name = "HealthFill"
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = Color3.fromRGB(80, 215, 100)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBg

local healthFillCorner = Instance.new("UICorner")
healthFillCorner.CornerRadius = UDim.new(0, 4)
healthFillCorner.Parent = healthFill

local turboBg = Instance.new("Frame")
turboBg.Name = "TurboBg"
turboBg.Size = UDim2.new(1, -20, 0, 12)
turboBg.Position = UDim2.new(0, 10, 0, 64)
turboBg.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
turboBg.BorderSizePixel = 0
turboBg.Parent = container

local turboBgCorner = Instance.new("UICorner")
turboBgCorner.CornerRadius = UDim.new(0, 4)
turboBgCorner.Parent = turboBg

local turboFill = Instance.new("Frame")
turboFill.Name = "TurboFill"
turboFill.Size = UDim2.fromScale(1, 1)
turboFill.BackgroundColor3 = Color3.fromRGB(60, 185, 255)
turboFill.BorderSizePixel = 0
turboFill.Parent = turboBg

local turboFillCorner = Instance.new("UICorner")
turboFillCorner.CornerRadius = UDim.new(0, 4)
turboFillCorner.Parent = turboFill

local slotLabels: { TextButton } = {}
for s = 1, 3 do
	local slotLbl = Instance.new("TextButton")
	slotLbl.Name = "Slot" .. s
	slotLbl.Size = UDim2.new(0.31, 0, 0, 22)
	slotLbl.Position = UDim2.new(0.025 + (s - 1) * 0.325, 0, 0, 82)
	slotLbl.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
	slotLbl.BackgroundTransparency = 0.2
	slotLbl.Font = Enum.Font.GothamBold
	slotLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
	slotLbl.TextScaled = true
	slotLbl.Text = s .. ": ---"
	slotLbl.Parent = container

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 4)
	sc.Parent = slotLbl

	slotLbl.MouseButton1Click:Connect(function()
		if activeCar then
			selectWeaponSlot:FireServer(s)
		end
	end)

	slotLabels[s] = slotLbl
end

local exclusiveLabel = Instance.new("TextLabel")
exclusiveLabel.Name = "ExclusiveLabel"
exclusiveLabel.Size = UDim2.new(1, -20, 0, 24)
exclusiveLabel.Position = UDim2.new(0, 10, 0, 110)
exclusiveLabel.BackgroundColor3 = Color3.fromRGB(24, 38, 30)
exclusiveLabel.BackgroundTransparency = 0.2
exclusiveLabel.Font = Enum.Font.GothamBlack
exclusiveLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
exclusiveLabel.TextSize = 13
exclusiveLabel.Text = "[X] ESPECIAL: 0 (Caja Verde)"
exclusiveLabel.Parent = container

local exCorner = Instance.new("UICorner")
exCorner.CornerRadius = UDim.new(0, 4)
exCorner.Parent = exclusiveLabel

local controlsHint = Instance.new("TextLabel")
controlsHint.Name = "ControlsHint"
controlsHint.Size = UDim2.new(1, -20, 0, 26)
controlsHint.Position = UDim2.new(0, 10, 0, 138)
controlsHint.BackgroundTransparency = 1
controlsHint.Font = Enum.Font.Gotham
controlsHint.TextColor3 = Color3.fromRGB(200, 205, 215)
controlsHint.TextXAlignment = Enum.TextXAlignment.Left
controlsHint.TextSize = 10
controlsHint.Text = "1-3: Arma | Q: Disparar | X: Especial | R: Enderezar"
controlsHint.Visible = not isTouch
controlsHint.Parent = container

-- ==========================================
-- RADAR SONAR CIRCULAR (Enemigos cercanos)
-- ==========================================
local radarFrame = Instance.new("Frame")
radarFrame.Name = "SonarRadar"
radarFrame.Size = if isTouch then UDim2.new(0, 96, 0, 96) else UDim2.new(0, 152, 0, 152)
radarFrame.Position = if isTouch then UDim2.new(0, 12, 0, 48) else UDim2.new(0, 20, 1, -172)
radarFrame.BackgroundColor3 = Color3.fromRGB(10, 28, 18)
radarFrame.BackgroundTransparency = 0.2
radarFrame.Parent = screenGui

local radarCorner = Instance.new("UICorner")
radarCorner.CornerRadius = UDim.new(1, 0)
radarCorner.Parent = radarFrame

local radarStroke = Instance.new("UIStroke")
radarStroke.Color = Color3.fromRGB(65, 225, 115)
radarStroke.Thickness = 2
radarStroke.Parent = radarFrame

local innerRing = Instance.new("Frame")
innerRing.Size = UDim2.fromScale(0.5, 0.5)
innerRing.Position = UDim2.fromScale(0.25, 0.25)
innerRing.BackgroundTransparency = 1
innerRing.Parent = radarFrame

local irCorner = Instance.new("UICorner")
irCorner.CornerRadius = UDim.new(1, 0)
irCorner.Parent = innerRing

local irStroke = Instance.new("UIStroke")
irStroke.Color = Color3.fromRGB(45, 145, 80)
irStroke.Thickness = 1
irStroke.Parent = innerRing

local crossH = Instance.new("Frame")
crossH.Size = UDim2.new(1, 0, 0, 1)
crossH.Position = UDim2.new(0, 0, 0.5, 0)
crossH.BackgroundColor3 = Color3.fromRGB(45, 145, 80)
crossH.BackgroundTransparency = 0.4
crossH.BorderSizePixel = 0
crossH.Parent = radarFrame

local crossV = Instance.new("Frame")
crossV.Size = UDim2.new(0, 1, 1, 0)
crossV.Position = UDim2.new(0.5, 0, 0, 0)
crossV.BackgroundColor3 = Color3.fromRGB(45, 145, 80)
crossV.BackgroundTransparency = 0.4
crossV.BorderSizePixel = 0
crossV.Parent = radarFrame

local playerDot = Instance.new("Frame")
playerDot.Size = UDim2.new(0, 8, 0, 8)
playerDot.Position = UDim2.new(0.5, -4, 0.5, -4)
playerDot.BackgroundColor3 = Color3.fromRGB(95, 255, 145)
playerDot.ZIndex = 3
playerDot.Parent = radarFrame

local pdCorner = Instance.new("UICorner")
pdCorner.CornerRadius = UDim.new(1, 0)
pdCorner.Parent = playerDot

local radarBlips: { Frame } = {}

-- ==========================================
-- CONTROLES TÁCTILES PARA MOBILE (TouchEnabled)
-- ==========================================
local touchFiring = false
local touchTurbo = false

local touchPanel = Instance.new("Frame")
touchPanel.Name = "TouchControls"
touchPanel.Size = UDim2.new(0, 204, 0, 128)
touchPanel.Position = UDim2.new(1, -304, 1, -138)
touchPanel.BackgroundTransparency = 1
touchPanel.Visible = isTouch
touchPanel.Parent = screenGui

local function makeTouchBtn(name: string, text: string, pos: UDim2, size: UDim2, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.18
	btn.Font = Enum.Font.GothamBlack
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Text = text
	btn.Parent = touchPanel

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = btn
	return btn
end

local btnFire = makeTouchBtn("BtnFire", "FIRE", UDim2.new(0, 108, 0, 60), UDim2.new(0, 92, 0, 62), Color3.fromRGB(220, 65, 50))
btnFire.MouseButton1Down:Connect(function()
	touchFiring = true
end)
btnFire.MouseButton1Up:Connect(function()
	touchFiring = false
end)
btnFire.MouseLeave:Connect(function()
	touchFiring = false
end)

local btnTurbo = makeTouchBtn("BtnTurbo", "TURBO", UDim2.new(0, 136, 0, 4), UDim2.new(0, 64, 0, 48), Color3.fromRGB(45, 160, 240))
btnTurbo.MouseButton1Down:Connect(function()
	touchTurbo = true
end)
btnTurbo.MouseButton1Up:Connect(function()
	touchTurbo = false
end)
btnTurbo.MouseLeave:Connect(function()
	touchTurbo = false
end)

local btnWpn = makeTouchBtn("BtnWpn", "ARMA", UDim2.new(0, 8, 0, 60), UDim2.new(0, 92, 0, 62), Color3.fromRGB(235, 155, 40))
btnWpn.MouseButton1Click:Connect(function()
	if activeCar then
		fireSpecial:FireServer(false, lockedTarget)
	end
end)

local btnSpec = makeTouchBtn("BtnSpec", "ESP", UDim2.new(0, 8, 0, 4), UDim2.new(0, 58, 0, 48), Color3.fromRGB(55, 200, 95))
btnSpec.MouseButton1Click:Connect(function()
	if activeCar then
		fireExclusiveSpecial:FireServer(lockedTarget)
	end
end)

local btnFlip = makeTouchBtn("BtnFlip", "FLIP", UDim2.new(0, 72, 0, 4), UDim2.new(0, 58, 0, 48), Color3.fromRGB(95, 105, 125))
btnFlip.MouseButton1Click:Connect(function()
	if activeCar then
		flipRemote:FireServer()
	end
end)

-- ==========================================
-- HUD DE PARTIDA, KILL FEED Y GARAJE (Fase 5)
-- ==========================================
local matchGui = Instance.new("ScreenGui")
matchGui.Name = "V8_MatchHUD"
matchGui.ResetOnSpawn = false
matchGui.Parent = player:WaitForChild("PlayerGui")

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = if isTouch then UDim2.new(0, 224, 0, 30) else UDim2.new(0, 440, 0, 42)
topBar.Position = if isTouch then UDim2.new(1, -234, 0, 8) else UDim2.new(0.5, -220, 0, 14)
topBar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
topBar.BackgroundTransparency = 0.2
topBar.Parent = matchGui

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 8)
topCorner.Parent = topBar

local matchLabel = Instance.new("TextLabel")
matchLabel.Size = UDim2.new(1, -8, 1, 0)
matchLabel.Position = UDim2.new(0, 4, 0, 0)
matchLabel.BackgroundTransparency = 1
matchLabel.Font = Enum.Font.GothamBlack
matchLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
matchLabel.TextScaled = isTouch
matchLabel.TextSize = 16
matchLabel.Text = "03:00  |  BAJAS: 0"
matchLabel.Parent = topBar

local killFeedLabel = Instance.new("TextLabel")
killFeedLabel.Name = "KillFeedLabel"
killFeedLabel.Size = UDim2.new(0, 380, 0, 32)
killFeedLabel.Position = UDim2.new(0.5, -190, 0, 62)
killFeedLabel.BackgroundColor3 = Color3.fromRGB(25, 20, 20)
killFeedLabel.BackgroundTransparency = 0.3
killFeedLabel.Font = Enum.Font.GothamBold
killFeedLabel.TextColor3 = Color3.fromRGB(255, 200, 75)
killFeedLabel.TextSize = 15
killFeedLabel.Text = ""
killFeedLabel.Visible = false
killFeedLabel.Parent = matchGui

local kfCorner = Instance.new("UICorner")
kfCorner.CornerRadius = UDim.new(0, 6)
kfCorner.Parent = killFeedLabel

local winnerBanner = Instance.new("TextLabel")
winnerBanner.Name = "WinnerBanner"
winnerBanner.Size = UDim2.new(0, 480, 0, 64)
winnerBanner.Position = UDim2.new(0.5, -240, 0.25, 0)
winnerBanner.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
winnerBanner.BackgroundTransparency = 0.15
winnerBanner.Font = Enum.Font.GothamBlack
winnerBanner.TextColor3 = Color3.fromRGB(255, 215, 65)
winnerBanner.TextScaled = true
winnerBanner.Visible = false
winnerBanner.Parent = matchGui

local wbCorner = Instance.new("UICorner")
wbCorner.CornerRadius = UDim.new(0, 10)
wbCorner.Parent = winnerBanner

local garageBtn = Instance.new("TextButton")
garageBtn.Name = "GarageButton"
garageBtn.Size = if isTouch then UDim2.new(0, 96, 0, 32) else UDim2.new(0, 150, 0, 38)
garageBtn.Position = if isTouch then UDim2.new(0, 12, 0, 8) else UDim2.new(0, 16, 0, 16)
garageBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
garageBtn.Font = Enum.Font.GothamBold
garageBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
garageBtn.TextSize = if isTouch then 12 else 14
garageBtn.Text = "Garaje [M]"
garageBtn.Parent = matchGui

local gbCorner = Instance.new("UICorner")
gbCorner.CornerRadius = UDim.new(0, 8)
gbCorner.Parent = garageBtn

local arenaBtn = Instance.new("TextButton")
arenaBtn.Name = "ArenaButton"
arenaBtn.Size = if isTouch then UDim2.new(0, 88, 0, 32) else UDim2.new(0, 150, 0, 38)
arenaBtn.Position = if isTouch then UDim2.new(0, 114, 0, 8) else UDim2.new(0, 176, 0, 16)
arenaBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
arenaBtn.Font = Enum.Font.GothamBold
arenaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
arenaBtn.TextSize = if isTouch then 12 else 14
arenaBtn.Text = "Mapas [N]"
arenaBtn.Parent = matchGui

local abCorner = Instance.new("UICorner")
abCorner.CornerRadius = UDim.new(0, 8)
abCorner.Parent = arenaBtn

local langBtn = Instance.new("TextButton")
langBtn.Name = "LangButton"
langBtn.Size = if isTouch then UDim2.new(0, 40, 0, 32) else UDim2.new(0, 62, 0, 38)
langBtn.Position = if isTouch then UDim2.new(0, 208, 0, 8) else UDim2.new(0, 336, 0, 16)
langBtn.BackgroundColor3 = Color3.fromRGB(38, 44, 62)
langBtn.Font = Enum.Font.GothamBlack
langBtn.TextColor3 = Color3.fromRGB(255, 215, 85)
langBtn.TextSize = 14
langBtn.Text = string.upper(I18n.Lang)
langBtn.Parent = matchGui

local lbCorner = Instance.new("UICorner")
lbCorner.CornerRadius = UDim.new(0, 8)
lbCorner.Parent = langBtn

local garageFrame = Instance.new("Frame")
garageFrame.Name = "GarageFrame"
garageFrame.AnchorPoint = Vector2.new(0.5, 0.5)
garageFrame.Size = UDim2.fromScale(0.9, 0.84)
garageFrame.Position = UDim2.fromScale(0.5, 0.5)
garageFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
garageFrame.BackgroundTransparency = 0.05
garageFrame.Visible = true
garageFrame.Parent = matchGui

local gfConstraint = Instance.new("UISizeConstraint")
gfConstraint.MaxSize = Vector2.new(640, 460)
gfConstraint.Parent = garageFrame

local gfCorner = Instance.new("UICorner")
gfCorner.CornerRadius = UDim.new(0, 12)
gfCorner.Parent = garageFrame

local gfTitle = Instance.new("TextLabel")
gfTitle.Size = UDim2.new(1, 0, 0, 38)
gfTitle.BackgroundTransparency = 1
gfTitle.Font = Enum.Font.GothamBlack
gfTitle.TextColor3 = Color3.fromRGB(255, 210, 80)
gfTitle.TextSize = 18
gfTitle.Text = "ELIGE TU VEHÍCULO DE VIGILANTE 8 (13)"
gfTitle.Parent = garageFrame

local garageScroll = Instance.new("ScrollingFrame")
garageScroll.Name = "GarageScroll"
garageScroll.Size = UDim2.new(1, -24, 1, -50)
garageScroll.Position = UDim2.new(0, 12, 0, 42)
garageScroll.BackgroundTransparency = 1
garageScroll.ScrollBarThickness = 6
garageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
garageScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
garageScroll.Parent = garageFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 190, 0, 248)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.Parent = garageScroll

local langUpdaters: { () -> () } = {}

local function addStatBar(parent: Instance, yPos: number, labelKey: string, ratio: number, barColor: Color3)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.45, -7, 0, 14)
	lbl.Position = UDim2.new(0, 7, 0, yPos)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.fromRGB(190, 195, 210)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextSize = 10
	lbl.Text = I18n.T(labelKey)
	lbl.Parent = parent

	table.insert(langUpdaters, function()
		lbl.Text = I18n.T(labelKey)
	end)

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(0.55, -7, 0, 10)
	bg.Position = UDim2.new(0.45, 0, 0, yPos + 2)
	bg.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
	bg.BorderSizePixel = 0
	bg.Parent = parent

	local bgC = Instance.new("UICorner")
	bgC.CornerRadius = UDim.new(0, 3)
	bgC.Parent = bg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0.05, 1), 1)
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local fC = Instance.new("UICorner")
	fC.CornerRadius = UDim.new(0, 3)
	fC.Parent = fill
end

for _, vId in ipairs(Config.VEHICLE_ORDER) do
	local vCfg = Config.VEHICLE_TYPES[vId]
	if not vCfg or not vCfg.Enabled then
		continue
	end
	local card = Instance.new("TextButton")
	card.Name = "Card_" .. vId
	card.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	card.Text = ""
	card.Parent = garageScroll

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = card

	-- Vista previa 3D del vehículo LEGO en ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview3D"
	viewport.Size = UDim2.new(1, -14, 0, 76)
	viewport.Position = UDim2.new(0, 7, 0, 7)
	viewport.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	viewport.Ambient = Color3.fromRGB(190, 195, 210)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, 1)
	viewport.Parent = card

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 6)
	vpCorner.Parent = viewport

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local previewCar = VehicleFactory.CreateCar({
		Name = "Preview_" .. vId,
		CFrame = CFrame.new(0, 0, 0),
		IsBot = false,
		VehicleType = vId,
	})
	for _, desc in ipairs(previewCar:GetDescendants()) do
		if desc:IsA("ProximityPrompt") or desc:IsA("BillboardGui") then
			desc:Destroy()
		end
	end
	previewCar.Parent = world

	local vpCam = Instance.new("Camera")
	local vScale = vCfg.Scale or Config.VEHICLE.SCALE or 1.35
	vpCam.CFrame = CFrame.lookAt(Vector3.new(11.5, 5.2, -13.5) * vScale, Vector3.new(0, 1.0 * vScale, 0))
	vpCam.Parent = viewport
	viewport.CurrentCamera = vpCam

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -14, 0, 20)
	nameLbl.Position = UDim2.new(0, 7, 0, 86)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Text = vCfg.DisplayName
	nameLbl.Parent = card

	local charLbl = Instance.new("TextLabel")
	charLbl.Size = UDim2.new(1, -14, 0, 15)
	charLbl.Position = UDim2.new(0, 7, 0, 106)
	charLbl.BackgroundTransparency = 1
	charLbl.Font = Enum.Font.GothamBold
	charLbl.TextColor3 = Color3.fromRGB(255, 205, 85)
	charLbl.TextSize = 11
	charLbl.Text = vCfg.Character
	charLbl.Parent = card

	local statsLbl = Instance.new("TextLabel")
	statsLbl.Size = UDim2.new(1, -14, 0, 48)
	statsLbl.Position = UDim2.new(0, 7, 0, 122)
	statsLbl.BackgroundTransparency = 1
	statsLbl.Font = Enum.Font.Gotham
	statsLbl.TextColor3 = Color3.fromRGB(195, 200, 215)
	statsLbl.TextWrapped = true
	statsLbl.TextYAlignment = Enum.TextYAlignment.Top
	statsLbl.TextSize = 10
	statsLbl.Text = string.format("%s\n%s", vCfg.SpecialName, I18n.T("DESC_" .. vId))
	statsLbl.Parent = card

	table.insert(langUpdaters, function()
		statsLbl.Text = string.format("%s\n%s", vCfg.SpecialName, I18n.T("DESC_" .. vId))
	end)

	addStatBar(card, 176, "STAT_SPEED", vCfg.MaxSpeed / 85, Color3.fromRGB(60, 185, 255))
	addStatBar(card, 196, "STAT_ARMOR", vCfg.MaxHealth / 170, Color3.fromRGB(80, 215, 110))
	addStatBar(card, 216, "STAT_SPECIAL", (vCfg.SpecialPower or 70) / 100, Color3.fromRGB(255, 115, 55))

	card.MouseButton1Click:Connect(function()
		garageFrame.Visible = false
		selectVehicleRemote:FireServer(vId)
	end)
end

local arenaFrame = Instance.new("Frame")
arenaFrame.Name = "ArenaFrame"
arenaFrame.AnchorPoint = Vector2.new(0.5, 0.5)
arenaFrame.Size = UDim2.fromScale(0.9, 0.8)
arenaFrame.Position = UDim2.fromScale(0.5, 0.5)
arenaFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
arenaFrame.BackgroundTransparency = 0.06
arenaFrame.Visible = false
arenaFrame.Parent = matchGui

local afConstraint = Instance.new("UISizeConstraint")
afConstraint.MaxSize = Vector2.new(620, 400)
afConstraint.Parent = arenaFrame

local afCorner = Instance.new("UICorner")
afCorner.CornerRadius = UDim.new(0, 12)
afCorner.Parent = arenaFrame

local afTitle = Instance.new("TextLabel")
afTitle.Size = UDim2.new(1, 0, 0, 38)
afTitle.BackgroundTransparency = 1
afTitle.Font = Enum.Font.GothamBlack
afTitle.TextColor3 = Color3.fromRGB(115, 220, 255)
afTitle.TextSize = 18
afTitle.Text = "ELIGE LA ARENA DE COMBATE (10)"
afTitle.Parent = arenaFrame

local arenaScroll = Instance.new("ScrollingFrame")
arenaScroll.Name = "ArenaScroll"
arenaScroll.Size = UDim2.new(1, -24, 1, -50)
arenaScroll.Position = UDim2.new(0, 12, 0, 42)
arenaScroll.BackgroundTransparency = 1
arenaScroll.ScrollBarThickness = 6
arenaScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
arenaScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
arenaScroll.Parent = arenaFrame

local arenaGrid = Instance.new("UIGridLayout")
arenaGrid.CellSize = UDim2.new(0, 184, 0, 132)
arenaGrid.CellPadding = UDim2.new(0, 10, 0, 10)
arenaGrid.Parent = arenaScroll

for _, aId in ipairs(Config.ARENA_ORDER) do
	local aCfg = Config.ARENAS[aId]
	local card = Instance.new("TextButton")
	card.Name = "Arena_" .. aId
	card.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	card.Text = ""
	card.Parent = arenaScroll

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = card

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(1, -14, 0, 10)
	swatch.Position = UDim2.new(0, 7, 0, 7)
	swatch.BackgroundColor3 = aCfg.FloorColor
	swatch.BorderSizePixel = 0
	swatch.Parent = card

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 4)
	sCorner.Parent = swatch

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -14, 0, 22)
	nameLbl.Position = UDim2.new(0, 7, 0, 20)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Text = aCfg.DisplayName
	nameLbl.Parent = card

	local locLbl = Instance.new("TextLabel")
	locLbl.Size = UDim2.new(1, -14, 0, 16)
	locLbl.Position = UDim2.new(0, 7, 0, 42)
	locLbl.BackgroundTransparency = 1
	locLbl.Font = Enum.Font.GothamBold
	locLbl.TextColor3 = if aCfg.Unlockable then Color3.fromRGB(255, 165, 75) else Color3.fromRGB(120, 225, 255)
	locLbl.TextSize = 11
	locLbl.Text = aCfg.Location
	locLbl.Parent = card

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -14, 0, 66)
	descLbl.Position = UDim2.new(0, 7, 0, 60)
	descLbl.BackgroundTransparency = 1
	descLbl.Font = Enum.Font.Gotham
	descLbl.TextColor3 = Color3.fromRGB(195, 200, 215)
	descLbl.TextWrapped = true
	descLbl.TextYAlignment = Enum.TextYAlignment.Top
	descLbl.TextSize = 11
	descLbl.Text = I18n.T("ARENA_" .. aId)
	descLbl.Parent = card

	table.insert(langUpdaters, function()
		descLbl.Text = I18n.T("ARENA_" .. aId)
	end)

	card.MouseButton1Click:Connect(function()
		arenaFrame.Visible = false
		selectArenaRemote:FireServer(aId)
	end)
end

local function refreshLanguage()
	langBtn.Text = string.upper(I18n.Lang)
	garageBtn.Text = I18n.T("GARAGE_BTN")
	arenaBtn.Text = I18n.T("MAPS_BTN")
	gfTitle.Text = I18n.T("CHOOSE_VEHICLE")
	afTitle.Text = I18n.T("CHOOSE_ARENA")
	controlsHint.Text = I18n.T("CONTROLS_HINT")
	for _, fn in ipairs(langUpdaters) do
		fn()
	end
end

refreshLanguage()

langBtn.MouseButton1Click:Connect(function()
	I18n.Toggle()
	refreshLanguage()
end)

arenaBtn.MouseButton1Click:Connect(function()
	arenaFrame.Visible = not arenaFrame.Visible
	if arenaFrame.Visible then
		garageFrame.Visible = false
	end
end)

garageBtn.MouseButton1Click:Connect(function()
	garageFrame.Visible = not garageFrame.Visible
	if garageFrame.Visible then
		arenaFrame.Visible = false
	end
end)

killFeedRemote.OnClientEvent:Connect(function(attackerName: string, victimName: string)
	local msg = string.format(I18n.T("KILLED_MSG"), attackerName, victimName)
	killFeedLabel.Text = msg
	killFeedLabel.Visible = true
	task.delay(3.5, function()
		if killFeedLabel.Text == msg then
			killFeedLabel.Visible = false
		end
	end)
end)

-- ==========================================
-- DETECCIÓN DE ASIENTO Y CONTROLES
-- ==========================================
local function onSeated(active: boolean, seatPart: BasePart?)
	local camera = Workspace.CurrentCamera
	if active and seatPart and seatPart:IsA("VehicleSeat") then
		local car = seatPart.Parent
		if car and car:IsA("Model") and car:GetAttribute("IsVehicle") then
			activeCar = car
			activeSeat = seatPart
			screenGui.Enabled = true
			if camera then
				camera.CameraType = Enum.CameraType.Scriptable
			end
			return
		end
	end

	activeCar = nil
	activeSeat = nil
	screenGui.Enabled = false
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(onSeated)
	if humanoid.SeatPart then
		onSeated(true, humanoid.SeatPart)
	end
end

if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.DPadLeft then
		garageFrame.Visible = not garageFrame.Visible
		if garageFrame.Visible then
			arenaFrame.Visible = false
		end
		return
	elseif input.KeyCode == Enum.KeyCode.N or input.KeyCode == Enum.KeyCode.DPadRight then
		arenaFrame.Visible = not arenaFrame.Visible
		if arenaFrame.Visible then
			garageFrame.Visible = false
		end
		return
	end
	if not activeCar then
		return
	end
	if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.DPadUp then
		flipRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.One then
		selectWeaponSlot:FireServer(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		selectWeaponSlot:FireServer(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		selectWeaponSlot:FireServer(3)
	elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
		local curSlot = (activeCar:GetAttribute("ActiveSlot") :: number?) or 1
		selectWeaponSlot:FireServer((curSlot % 3) + 1)
	elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonY then
		fireExclusiveSpecial:FireServer(lockedTarget)
	elseif input.KeyCode == Enum.KeyCode.Q or input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonX then
		local wantsCombo = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		fireSpecial:FireServer(wantsCombo, lockedTarget)
	end
end)

-- ==========================================
-- BUCLE DE CONDUCCIÓN Y CÁMARA ARCADE
-- ==========================================
RunService.RenderStepped:Connect(function(dt: number)
	-- Actualizar barra superior de partida (siempre visible)
	local totalSec = timeLeftVal.Value
	local mins = math.floor(totalSec / 60)
	local secs = totalSec % 60
	local ls = player:FindFirstChild("leaderstats")
	local killsVal = ls and ls:FindFirstChild("Eliminaciones") :: IntValue?
	local deathsVal = ls and ls:FindFirstChild("Muertes") :: IntValue?
	local dmgVal = ls and ls:FindFirstChild("Daño") :: IntValue?
	local kills = if killsVal then killsVal.Value else 0
	local deaths = if deathsVal then deathsVal.Value else 0
	local dmg = if dmgVal then dmgVal.Value else 0

	if phaseVal.Value == "FinRonda" then
		matchLabel.Text = string.format(I18n.T("NEW_ROUND") .. "  |  %d / %d / %d", totalSec, kills, deaths, dmg)
		winnerBanner.Text = winnerVal.Value
		winnerBanner.Visible = true
	else
		matchLabel.Text = string.format("%02d:%02d  |  %s: %d  |  %s: %d  |  %s: %d", mins, secs, I18n.T("KILLS"), kills, I18n.T("DEATHS"), deaths, I18n.T("DAMAGE"), dmg)
		winnerBanner.Visible = false
	end

	if not activeCar or not activeSeat or not activeCar.Parent then
		return
	end

	local chassis = activeCar.PrimaryPart
	if not chassis then
		return
	end

	local throttle = activeSeat.ThrottleFloat
	local steer = activeSeat.SteerFloat

	if not UserInputService:GetFocusedTextBox() then
		local keyThrottle = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			keyThrottle += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			keyThrottle -= 1
		end
		if keyThrottle ~= 0 then
			throttle = keyThrottle
		end

		local keySteer = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			keySteer += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			keySteer -= 1
		end
		if keySteer ~= 0 then
			steer = keySteer
		end
	end

	-- Soporte de gatillos R2/L2 en Consola (Gamepad)
	if UserInputService.GamepadEnabled then
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then
			throttle = 1
		elseif UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2) then
			throttle = -1
		end
	end

	local wantsTurbo = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB)
		or touchTurbo
	local isTurbo = false
	if wantsTurbo and math.abs(throttle) > 0.1 and turboEnergy > 1 then
		isTurbo = true
		turboEnergy = math.max(0, turboEnergy - Config.VEHICLE.TURBO_DRAIN * dt)
	else
		turboEnergy = math.min(Config.VEHICLE.TURBO_MAX, turboEnergy + Config.VEHICLE.TURBO_REGEN * dt)
	end

	local baseMaxSpeed = (activeCar:GetAttribute("MaxSpeed") :: number?) or Config.VEHICLE.MAX_SPEED
	local baseSteerAngle = (activeCar:GetAttribute("SteerAngle") :: number?) or Config.VEHICLE.STEER_ANGLE
	local targetSpeed = baseMaxSpeed * (if isTurbo then Config.VEHICLE.TURBO_MULTIPLIER else 1)

	-- Actualizar motores de las ruedas
	local motors = activeCar:FindFirstChild("DriveMotors")
	if motors then
		for _, hinge in ipairs(motors:GetChildren()) do
			if hinge:IsA("HingeConstraint") then
				hinge.AngularVelocity = -throttle * targetSpeed
			end
		end
	end

	-- Actualizar dirección delantera (mantiene buen giro incluso a alta velocidad)
	local vel = chassis.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local speedFactor = math.clamp(speed / 95, 0, 1)
	local dynamicSteerAngle = baseSteerAngle * (1 - 0.25 * speedFactor)

	local servos = activeCar:FindFirstChild("SteerServos")
	if servos then
		for _, servo in ipairs(servos:GetChildren()) do
			if servo:IsA("HingeConstraint") then
				servo.TargetAngle = -steer * dynamicSteerAngle
			end
		end
	end

	-- Agarre lateral activo (evita derrapes excesivos en curvas rápidas)
	if speed > 12 then
		local lateralVel = chassis.CFrame.RightVector:Dot(vel)
		local gripStrength = math.clamp(dt * 6.5, 0, 0.45)
		chassis:ApplyImpulse(-chassis.CFrame.RightVector * lateralVel * chassis.AssemblyMass * gripStrength)
	end

	-- Empuje extra suave durante Turbo
	if isTurbo and throttle > 0 then
		chassis:ApplyImpulse(chassis.CFrame.LookVector * Config.VEHICLE.TURBO_FORCE * dt)
	end

	-- Actualizar HUD (velocidad, vida y turbo)
	local studsPerSec = chassis.AssemblyLinearVelocity.Magnitude
	local kmh = math.floor(studsPerSec * 1.1)
	speedLabel.Text = string.format("%d KM/H", kmh)

	local hp = (activeCar:GetAttribute("Health") :: number?) or Config.VEHICLE.MAX_HEALTH
	local maxHp = (activeCar:GetAttribute("MaxHealth") :: number?) or Config.VEHICLE.MAX_HEALTH
	local hpRatio = math.clamp(hp / math.max(1, maxHp), 0, 1)
	healthLabel.Text = string.format("HP %d", math.ceil(hp))
	healthFill.Size = UDim2.fromScale(hpRatio, 1)
	if hpRatio > 0.5 then
		healthFill.BackgroundColor3 = Color3.fromRGB(80, 215, 100)
		healthLabel.TextColor3 = Color3.fromRGB(95, 225, 115)
	elseif hpRatio > 0.25 then
		healthFill.BackgroundColor3 = Color3.fromRGB(235, 190, 45)
		healthLabel.TextColor3 = Color3.fromRGB(245, 200, 60)
	else
		healthFill.BackgroundColor3 = Color3.fromRGB(225, 55, 55)
		healthLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
	end

	turboFill.Size = UDim2.fromScale(turboEnergy / Config.VEHICLE.TURBO_MAX, 1)
	turboFill.BackgroundColor3 = if isTurbo
		then Color3.fromRGB(255, 165, 50)
		else Color3.fromRGB(60, 185, 255)

	local activeSlot = (activeCar:GetAttribute("ActiveSlot") :: number?) or 1
	for s = 1, 3 do
		local slotLbl = slotLabels[s]
		local wId = activeCar:GetAttribute("Slot" .. s .. "Weapon") :: string?
		local wAmmo = (activeCar:GetAttribute("Slot" .. s .. "Ammo") :: number?) or 0
		local isSelected = (s == activeSlot)

		if wId and wAmmo > 0 then
			local wCfg = Config.WEAPONS.CATALOG[wId]
			local shortName = if wCfg then wCfg.ShortName else wId
			slotLbl.Text = string.format("%d:%s x%d", s, shortName, wAmmo)
			slotLbl.TextColor3 = if wCfg then wCfg.Color else Color3.fromRGB(255, 255, 255)
		else
			slotLbl.Text = s .. ": ---"
			slotLbl.TextColor3 = Color3.fromRGB(130, 135, 150)
		end

		slotLbl.BackgroundColor3 = if isSelected
			then Color3.fromRGB(58, 66, 88)
			else Color3.fromRGB(28, 32, 42)
	end

	local vId = (activeCar:GetAttribute("VehicleType") :: string?) or "Rattler"
	local vCfg = Config.VEHICLE_TYPES[vId]
	local exName = if vCfg then string.upper(vCfg.SpecialName) else "ESPECIAL"
	local exAmmo = (activeCar:GetAttribute("ExclusiveSpecialAmmo") :: number?) or 0
	if exAmmo > 0 then
		exclusiveLabel.Text = string.format("[X] %s: %d", exName, exAmmo)
		exclusiveLabel.TextColor3 = Color3.fromRGB(80, 245, 120)
	else
		exclusiveLabel.Text = string.format("[X] %s: 0 (%s)", exName, I18n.T("GREEN_CRATE"))
		exclusiveLabel.TextColor3 = Color3.fromRGB(140, 155, 145)
	end

	-- Actualizar fijado de objetivo (Lock-on) al enemigo más cercano al frente
	lockedTarget = nil
	local vehiclesDir = Workspace:FindFirstChild("ActiveVehicles")
	if vehiclesDir then
		local bestScore = math.huge
		local bestDist = 0
		local forward = chassis.CFrame.LookVector
		for _, otherCar in ipairs(vehiclesDir:GetChildren()) do
			if otherCar:IsA("Model") and otherCar ~= activeCar and otherCar:GetAttribute("IsVehicle") and not otherCar:GetAttribute("Destroyed") then
				local otherChassis = otherCar.PrimaryPart
				if otherChassis then
					local offset = otherChassis.Position - chassis.Position
					local dist = offset.Magnitude
					if dist <= 220 and dist > 2 then
						local dot = forward:Dot(offset.Unit)
						if dot >= 0.60 then
							local score = dist * (1.6 - dot * 0.6)
							if score < bestScore then
								bestScore = score
								bestDist = math.floor(dist)
								lockedTarget = otherCar
							end
						end
					end
				end
			end
		end
		if lockedTarget and lockedTarget.PrimaryPart then
			lockGui.Adornee = lockedTarget.PrimaryPart
			lockGui.Enabled = true
			lockLabel.Text = string.format("[ TARGET %dm ]", bestDist)
		else
			lockGui.Enabled = false
			lockGui.Adornee = nil
		end
	else
		lockGui.Enabled = false
		lockGui.Adornee = nil
	end

	-- Disparo de ametralladora (PC: Clic izq/F, Consola: R1/RB, Mobile: botón FIRE)
	local isFiring = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or UserInputService:IsKeyDown(Enum.KeyCode.F)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR1)
		or touchFiring
	if isFiring and not UserInputService:GetFocusedTextBox() then
		local now = os.clock()
		if now - lastFireClient >= Config.COMBAT.MG_FIRE_RATE then
			lastFireClient = now
			firePrimary:FireServer(lockedTarget)
		end
	end

	-- Cámara de persecución arcade (estilo Vigilante 8)
	local camera = Workspace.CurrentCamera
	if camera then
		local look = chassis.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude < 0.01 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end

		local speedZoom = math.clamp(studsPerSec / 60, 0, 1) * 6
		local camPos = chassis.Position - flatLook * (28 + speedZoom) + Vector3.new(0, 11.5, 0)
		local lookTarget = chassis.Position + flatLook * 14 + Vector3.new(0, 3.0, 0)
		local goalCF = CFrame.lookAt(camPos, lookTarget)

		camera.CFrame = camera.CFrame:Lerp(goalCF, math.clamp(dt * 8, 0, 1))
	end

	-- Actualizar puntos enemigos en el Radar Sonar
	for _, b in ipairs(radarBlips) do
		b.Visible = false
	end
	local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
	if vehiclesFolder then
		local blipIdx = 0
		local maxRange = 360
		for _, otherCar in ipairs(vehiclesFolder:GetChildren()) do
			if otherCar:IsA("Model") and otherCar ~= activeCar and otherCar:GetAttribute("IsVehicle") and not otherCar:GetAttribute("Destroyed") then
				local otherChassis = otherCar.PrimaryPart
				if otherChassis then
					blipIdx += 1
					local blip = radarBlips[blipIdx]
					if not blip then
						blip = Instance.new("Frame")
						blip.Size = UDim2.new(0, 8, 0, 8)
						blip.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
						blip.ZIndex = 4
						blip.Parent = radarFrame
						local bc = Instance.new("UICorner")
						bc.CornerRadius = UDim.new(1, 0)
						bc.Parent = blip
						radarBlips[blipIdx] = blip
					end
					local localOffset = chassis.CFrame:VectorToObjectSpace(otherChassis.Position - chassis.Position)
					local nx = localOffset.X / maxRange
					local nz = localOffset.Z / maxRange
					local mag = math.sqrt(nx * nx + nz * nz)
					if mag > 0.92 then
						nx = (nx / mag) * 0.92
						nz = (nz / mag) * 0.92
					end
					blip.Position = UDim2.new(0.5 + nx * 0.48, -4, 0.5 + nz * 0.48, -4)
					blip.Visible = true
				end
			end
		end
	end
end)

-- ==========================================
-- EFECTOS VISUALES DE DISPAROS
-- ==========================================
bulletEffect.OnClientEvent:Connect(function(startPos: Vector3, endPos: Vector3, hitVehicle: boolean)
	local dist = (endPos - startPos).Magnitude
	if dist < 0.1 then
		return
	end

	local beam = Instance.new("Part")
	beam.Name = "BulletTracer"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 215, 80)
	beam.Size = Vector3.new(0.18, 0.18, dist)
	beam.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = Workspace
	Debris:AddItem(beam, 0.06)

	if hitVehicle then
		local spark = Instance.new("Part")
		spark.Name = "HitSpark"
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.Shape = Enum.PartType.Ball
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 110, 30)
		spark.Size = Vector3.new(1.8, 1.8, 1.8)
		spark.Position = endPos
		spark.Parent = Workspace
		Debris:AddItem(spark, 0.09)
	end
end)

returnToGarageRemote.OnClientEvent:Connect(function()
	arenaFrame.Visible = false
	garageFrame.Visible = true
end)
