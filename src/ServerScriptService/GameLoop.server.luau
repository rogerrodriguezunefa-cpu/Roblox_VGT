local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local VehicleFactory = require(Shared:WaitForChild("VehicleFactory"))
local BotAIService = require(game:GetService("ServerScriptService"):WaitForChild("BotAIService"))

-- Carpeta de eventos remotos
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local flipRemote = Instance.new("RemoteEvent")
flipRemote.Name = "FlipVehicle"
flipRemote.Parent = remotes

local selectVehicleRemote = Instance.new("RemoteEvent")
selectVehicleRemote.Name = "SelectVehicle"
selectVehicleRemote.Parent = remotes

local selectArenaRemote = Instance.new("RemoteEvent")
selectArenaRemote.Name = "SelectArena"
selectArenaRemote.Parent = remotes

local returnToGarageRemote = Instance.new("RemoteEvent")
returnToGarageRemote.Name = "ReturnToGarage"
returnToGarageRemote.Parent = remotes

-- Estado de la partida replicado a los clientes
local matchState = Instance.new("Folder")
matchState.Name = "MatchState"
matchState.Parent = ReplicatedStorage

local phaseVal = Instance.new("StringValue")
phaseVal.Name = "Phase"
phaseVal.Value = "EnPartida"
phaseVal.Parent = matchState

local timeLeftVal = Instance.new("IntValue")
timeLeftVal.Name = "TimeLeft"
timeLeftVal.Value = Config.MATCH.ROUND_DURATION
timeLeftVal.Parent = matchState

local winnerVal = Instance.new("StringValue")
winnerVal.Name = "WinnerText"
winnerVal.Value = ""
winnerVal.Parent = matchState

local currentArenaVal = Instance.new("StringValue")
currentArenaVal.Name = "CurrentArena"
currentArenaVal.Value = "GhostTown"
currentArenaVal.Parent = matchState

-- Carpeta de vehículos activos
local vehiclesFolder = Instance.new("Folder")
vehiclesFolder.Name = "ActiveVehicles"
vehiclesFolder.Parent = Workspace

local playerCars: { [Player]: Model } = {}
local playerSelectedVehicle: { [Player]: string } = {}
local playerHasSelected: { [Player]: boolean } = {}
local lastFlipTime: { [Player]: number } = {}

local function setNetworkOwnerRecursive(model: Model, owner: Player?)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") and not desc.Anchored then
			pcall(function()
				desc:SetNetworkOwner(owner)
			end)
		end
	end
end

local function flipCar(car: Model)
	local chassis = car.PrimaryPart
	if not chassis then
		return
	end
	local pos = chassis.Position
	local look = chassis.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	end
	local uprightCFrame = CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 0) + flatLook.Unit)
	car:PivotTo(uprightCFrame)
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end

flipRemote.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if lastFlipTime[player] and now - lastFlipTime[player] < 2.0 then
		return
	end
	lastFlipTime[player] = now

	local car = playerCars[player]
	if car and car.Parent then
		flipCar(car)
	end
end)

local function spawnPlayerCar(player: Player, character: Model)
	-- Eliminar auto anterior si existía
	if playerCars[player] then
		playerCars[player]:Destroy()
		playerCars[player] = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	local spawnAngle = math.random() * math.pi * 2
	local spawnPos = Vector3.new(math.cos(spawnAngle) * 58, 5, math.sin(spawnAngle) * 58)
	local spawnCF = CFrame.lookAt(spawnPos, Vector3.new(0, 5, 0))

	local selectedId = playerSelectedVehicle[player] or "Rattler"
	local car = VehicleFactory.CreateCar({
		Name = player.Name .. "_Car",
		CFrame = spawnCF,
		IsBot = false,
		OwnerName = player.Name,
		VehicleType = selectedId,
	})
	car.Parent = vehiclesFolder
	playerCars[player] = car

	local handledDestruction = false
	local function onCarDestroyed()
		if handledDestruction then
			return
		end
		handledDestruction = true
		task.delay(4, function() -- Tiempo para ver la explosión de bloques
			if player.Parent and playerCars[player] == car then
				returnToGarageRemote:FireClient(player)
				player:LoadCharacter()
			end
		end)
	end

	car:GetAttributeChangedSignal("IsDestroyed"):Connect(function()
		if car:GetAttribute("IsDestroyed") == true then
			onCarDestroyed()
		end
	end)

	car:GetAttributeChangedSignal("Destroyed"):Connect(function()
		if car:GetAttribute("Destroyed") then
			onCarDestroyed()
		end
	end)

	-- Dar propiedad de red al jugador para conducción sin lag
	setNetworkOwnerRecursive(car, player)

	local seat = car:WaitForChild("DriverSeat") :: VehicleSeat
	local chassis = car.PrimaryPart :: BasePart
	local enterPrompt = chassis:FindFirstChild("EnterPrompt") :: ProximityPrompt?

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupied = seat.Occupant ~= nil
		if enterPrompt then
			enterPrompt.Enabled = not occupied
		end
		if not occupied then
			-- Frenar suavemente si el conductor salió del auto
			local motors = car:FindFirstChild("DriveMotors")
			if motors then
				for _, hinge in ipairs(motors:GetChildren()) do
					if hinge:IsA("HingeConstraint") then
						hinge.AngularVelocity = 0
					end
				end
			end
		end
	end)

	if enterPrompt then
		enterPrompt.Triggered:Connect(function(triggerPlayer: Player)
			if seat.Occupant ~= nil then
				return
			end
			local char = triggerPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				setNetworkOwnerRecursive(car, triggerPlayer)
				seat:Sit(hum)
			end
		end)
	end

	task.wait(0.2)
	if humanoid.Health > 0 and seat.Parent then
		seat:Sit(humanoid)
	end
end

selectVehicleRemote.OnServerEvent:Connect(function(player: Player, vehicleId: string)
	local vCfg = if typeof(vehicleId) == "string" then Config.VEHICLE_TYPES[vehicleId] else nil
	if not vCfg or not vCfg.Enabled then
		return
	end
	playerSelectedVehicle[player] = vehicleId
	playerHasSelected[player] = true
	if player.Character then
		spawnPlayerCar(player, player.Character)
	end
end)

selectArenaRemote.OnServerEvent:Connect(function(_player: Player, arenaId: string)
	if typeof(arenaId) ~= "string" or not Config.ARENAS[arenaId] then
		return
	end
	local buildEvt = game:GetService("ServerScriptService"):FindFirstChild("BuildArenaEvent") :: BindableEvent?
	if buildEvt then
		buildEvt:Fire(arenaId)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			spawnPlayerCar(p, p.Character)
		end
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	playerSelectedVehicle[player] = "Rattler"

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local kills = Instance.new("IntValue")
	kills.Name = "Eliminaciones"
	kills.Value = 0
	kills.Parent = leaderstats

	local deaths = Instance.new("IntValue")
	deaths.Name = "Muertes"
	deaths.Value = 0
	deaths.Parent = leaderstats

	local damageDealt = Instance.new("IntValue")
	damageDealt.Name = "Daño"
	damageDealt.Value = 0
	damageDealt.Parent = leaderstats

	player.CharacterAdded:Connect(function(character: Model)
		if playerHasSelected[player] then
			spawnPlayerCar(player, character)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if playerCars[player] then
		playerCars[player]:Destroy()
		playerCars[player] = nil
	end
	playerSelectedVehicle[player] = nil
	playerHasSelected[player] = nil
	lastFlipTime[player] = nil
end)

-- ==========================================
-- GESTOR DE RONDAS (Fase 5)
-- ==========================================
task.spawn(function()
	while true do
		phaseVal.Value = "EnPartida"
		winnerVal.Value = ""
		for t = Config.MATCH.ROUND_DURATION, 1, -1 do
			timeLeftVal.Value = t
			task.wait(1)
		end

		-- Calcular ganador de la ronda (1° más bajas, 2° menos muertes, 3° más daño)
		phaseVal.Value = "FinRonda"
		local bestPlayer: Player? = nil
		local bestKills = -1
		local bestDeaths = math.huge
		local bestDamage = -1

		for _, p in ipairs(Players:GetPlayers()) do
			local ls = p:FindFirstChild("leaderstats")
			local kVal = ls and ls:FindFirstChild("Eliminaciones") :: IntValue?
			local dVal = ls and ls:FindFirstChild("Muertes") :: IntValue?
			local dmgVal = ls and ls:FindFirstChild("Daño") :: IntValue?

			local k = if kVal then kVal.Value else 0
			local d = if dVal then dVal.Value else 0
			local dmg = if dmgVal then dmgVal.Value else 0

			local isBetter = false
			if k > bestKills then
				isBetter = true
			elseif k == bestKills then
				if d < bestDeaths then
					isBetter = true
				elseif d == bestDeaths and dmg > bestDamage then
					isBetter = true
				end
			end

			if isBetter then
				bestPlayer = p
				bestKills = k
				bestDeaths = d
				bestDamage = dmg
			end
		end

		if bestPlayer and (bestKills > 0 or bestDamage > 0) then
			winnerVal.Value = string.format(
				"¡Ganador: %s! (%d bajas | %d muertes | %d daño)",
				bestPlayer.Name,
				bestKills,
				bestDeaths,
				bestDamage
			)
		else
			winnerVal.Value = "¡Fin de la ronda!"
		end

		for t = Config.MATCH.INTERMISSION, 1, -1 do
			timeLeftVal.Value = t
			task.wait(1)
		end

		-- Reiniciar puntajes y autos para la nueva ronda
		for _, p in ipairs(Players:GetPlayers()) do
			local ls = p:FindFirstChild("leaderstats")
			local k = ls and ls:FindFirstChild("Eliminaciones") :: IntValue?
			local d = ls and ls:FindFirstChild("Muertes") :: IntValue?
			local dmg = ls and ls:FindFirstChild("Daño") :: IntValue?
			if k then
				k.Value = 0
			end
			if d then
				d.Value = 0
			end
			if dmg then
				dmg.Value = 0
			end
			if p.Character then
				spawnPlayerCar(p, p.Character)
			end
		end
	end
end)

-- ==========================================
-- BOTS SIMPLES DE PRUEBA (Fase 1)
-- ==========================================
type BotState = {
	Model: Model,
	SteerDir: number,
	NextDecision: number,
	ReverseUntil: number,
	UpsideDownSince: number?,
}

local bots: { BotState } = {}

local function applyWheelControl(car: Model, throttle: number, steer: number, speed: number)
	local motors = car:FindFirstChild("DriveMotors")
	if motors then
		for _, hinge in ipairs(motors:GetChildren()) do
			if hinge:IsA("HingeConstraint") then
				hinge.AngularVelocity = -throttle * speed
			end
		end
	end

	local servos = car:FindFirstChild("SteerServos")
	if servos then
		for _, servo in ipairs(servos:GetChildren()) do
			if servo:IsA("HingeConstraint") then
				servo.TargetAngle = -steer * Config.VEHICLE.STEER_ANGLE
			end
		end
	end
end

local function spawnBot(index: number)
	local botColors = {
		Color3.fromRGB(50, 130, 210),
		Color3.fromRGB(65, 185, 95),
		Color3.fromRGB(210, 165, 45),
		Color3.fromRGB(160, 75, 200),
	}
	local angle = (index / math.max(1, Config.BOT_COUNT)) * math.pi * 2
	local radius = 85
	local spawnPos = Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
	local spawnCF = CFrame.lookAt(spawnPos, Vector3.new(0, 5, 0))

	local botTypes = { "Rattler", "Manta", "Van", "StagPickup" }
	local botDrivers = { "Sid Burn", "Molo", "Boogie", "Chassey Blue" }
	local driverName = botDrivers[((index - 1) % #botDrivers) + 1]
	local botCar = VehicleFactory.CreateCar({
		Name = driverName .. " [" .. index .. "]",
		CFrame = spawnCF,
		IsBot = true,
		OwnerName = driverName,
		VehicleType = botTypes[((index - 1) % #botTypes) + 1],
	})
	botCar.Parent = vehiclesFolder
	setNetworkOwnerRecursive(botCar, nil)
	BotAIService.StartBotAI(botCar)

	local botEntry: BotState = {
		Model = botCar,
		SteerDir = if index % 2 == 0 then 1 else -1,
		NextDecision = os.clock() + math.random(2, 4),
		ReverseUntil = 0,
		UpsideDownSince = nil,
	}
	table.insert(bots, botEntry)

	local botDestroyedHandled = false
	local function onBotDestroyed()
		if botDestroyedHandled then
			return
		end
		botDestroyedHandled = true
		local idx = table.find(bots, botEntry)
		if idx then
			table.remove(bots, idx)
		end
		task.delay(Config.BOT_RESPAWN_DELAY, function()
			if Config.BOTS_ENABLED then
				spawnBot(index)
			end
		end)
	end

	botCar:GetAttributeChangedSignal("IsDestroyed"):Connect(function()
		if botCar:GetAttribute("IsDestroyed") == true then
			onBotDestroyed()
		end
	end)

	botCar:GetAttributeChangedSignal("Destroyed"):Connect(function()
		if botCar:GetAttribute("Destroyed") then
			onBotDestroyed()
		end
	end)
end

if Config.BOTS_ENABLED then
	for i = 1, Config.BOT_COUNT do
		spawnBot(i)
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, bot in ipairs(bots) do
			local car = bot.Model
			local chassis = car.PrimaryPart
			if not car.Parent or not chassis then
				continue
			end

			-- Auto-enderezar si el bot quedó volcado
			if chassis.CFrame.UpVector.Y < 0.2 then
				if not bot.UpsideDownSince then
					bot.UpsideDownSince = now
				elseif now - bot.UpsideDownSince > 2.0 then
					flipCar(car)
					bot.UpsideDownSince = nil
				end
			else
				bot.UpsideDownSince = nil
			end

			-- Raycast frontal para esquivar muros y pilares
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = { car }

			local origin = chassis.Position + Vector3.new(0, 0.5, 0)
			local forward = chassis.CFrame.LookVector
			local hit = Workspace:Raycast(origin, forward * 28, rayParams)

			if hit then
				if hit.Distance < 10 and now > bot.ReverseUntil then
					bot.ReverseUntil = now + 1.1
					bot.SteerDir = -bot.SteerDir
				end
				applyWheelControl(car, if now < bot.ReverseUntil then -1 else 0.7, bot.SteerDir, Config.BOT_SPEED)
			elseif now < bot.ReverseUntil then
				applyWheelControl(car, -0.9, -bot.SteerDir, Config.BOT_SPEED)
			else
				if now > bot.NextDecision then
					bot.NextDecision = now + math.random(2, 5)
					local choices = { -0.6, 0, 0.6 }
					bot.SteerDir = choices[math.random(1, #choices)]
				end
				applyWheelControl(car, 1, bot.SteerDir, Config.BOT_SPEED)
			end
		end
	end)
end
