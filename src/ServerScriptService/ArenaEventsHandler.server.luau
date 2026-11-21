--!strict
-- ServerScriptService/ArenaEventsHandler.server.luau
-- Detecta automáticamente los elementos interactivos del mapa cargado y activa su mecánica de Vigilante 8.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local VehicleHealthService = require(ServerScriptService:WaitForChild("VehicleHealthService"))
local ArenaDestructionService = require(ServerScriptService:WaitForChild("ArenaDestructionService"))

-- Helper para detectar vehículo
local function getVehicleFromPart(part: BasePart): Model?
	local current: Instance? = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") and current:HasTag("CombatVehicle") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- =========================================================================
-- 1. OIL FIELDS: Tanques de combustible con explosión en cadena
-- Etiqueta requerida: "ExplosiveTank"
-- =========================================================================
local function detonateTank(tank: Instance)
	if tank:GetAttribute("Exploded") then
		return
	end
	tank:SetAttribute("Exploded", true)

	local pos = if tank:IsA("Model") then tank:GetPivot().Position else (tank :: BasePart).Position

	local exp = Instance.new("Explosion")
	exp.Position = pos
	exp.BlastRadius = 28
	exp.BlastPressure = 0
	exp.DestroyJointRadiusPercent = 0
	exp.Parent = workspace

	-- Dañar autos y edificios cercanos
	ArenaDestructionService.DamageStructuresInRadius(pos, 28, 100)

	local nearbyParts = workspace:GetPartBoundsInRadius(pos, 28)
	local hitVehicles: { [Model]: boolean } = {}

	for _, part in ipairs(nearbyParts) do
		local v = getVehicleFromPart(part)
		if v and not hitVehicles[v] then
			hitVehicles[v] = true
			VehicleHealthService.ApplyDamage(v, 45, pos)
		end

		-- Reacción en cadena: detonar otros tanques cercanos tras 0.25s
		local otherTank: Instance = part:FindFirstAncestorWhichIsA("Model") or part
		if otherTank ~= tank and otherTank:HasTag("ExplosiveTank") and not otherTank:GetAttribute("Exploded") then
			task.delay(0.25, function()
				detonateTank(otherTank)
			end)
		end
	end

	ArenaDestructionService.DestroyStructure(tank, pos, 60)
end

local function setupExplosiveTank(tank: Instance)
	if tank:GetAttribute("Health") == nil then
		tank:SetAttribute("Health", 30)
	end
	-- Se detona al recibir impacto de proyectil o embestida fuerte
	tank:GetAttributeChangedSignal("Health"):Connect(function()
		if ((tank:GetAttribute("Health") :: number?) or 1) <= 0 then
			detonateTank(tank)
		end
	end)
end

for _, tank in ipairs(CollectionService:GetTagged("ExplosiveTank")) do
	setupExplosiveTank(tank)
end
CollectionService:GetInstanceAddedSignal("ExplosiveTank"):Connect(setupExplosiveTank)

-- =========================================================================
-- 2. SKI RESORT: Avalancha al derribar 3 árboles clave
-- Etiquetas: "AvalancheTree" (los 3 árboles) y "AvalancheBoulder" (rocas/nieve)
-- =========================================================================
local destroyedTrees = 0
local avalancheTriggered = false

local function triggerAvalanche()
	if avalancheTriggered then
		return
	end
	avalancheTriggered = true

	for _, boulder in ipairs(CollectionService:GetTagged("AvalancheBoulder")) do
		if boulder:IsA("BasePart") then
			boulder.Anchored = false
			boulder.CanCollide = true
			-- Empujar ladera abajo en dirección -Z (ajustar según la pendiente del mapa)
			boulder.AssemblyLinearVelocity = Vector3.new(0, -10, -85)

			boulder.Touched:Connect(function(hit: BasePart)
				local v = getVehicleFromPart(hit)
				if v and not v:GetAttribute("AvalancheHit") then
					v:SetAttribute("AvalancheHit", true)
					VehicleHealthService.ApplyDamage(v, 50, boulder.Position)
					task.delay(2, function()
						if v then
							v:SetAttribute("AvalancheHit", false)
						end
					end)
				end
			end)
		end
	end
end

local function setupAvalancheTree(tree: Instance)
	local counted = false
	local function onTreeDestroyed()
		if counted then
			return
		end
		counted = true
		destroyedTrees += 1
		if destroyedTrees >= 3 then
			triggerAvalanche()
		end
	end

	tree:GetAttributeChangedSignal("IsDestroyed"):Connect(function()
		if tree:GetAttribute("IsDestroyed") then
			onTreeDestroyed()
		end
	end)
	tree.AncestryChanged:Connect(function(_, parent)
		if not parent then
			onTreeDestroyed()
		end
	end)
end

for _, tree in ipairs(CollectionService:GetTagged("AvalancheTree")) do
	setupAvalancheTree(tree)
end
CollectionService:GetInstanceAddedSignal("AvalancheTree"):Connect(setupAvalancheTree)

-- =========================================================================
-- 3. CANYONLANDS: Círculo de piedras teletransportador
-- Etiquetas: "AlienTeleporter" (portal) y "TeleporterExit" (puntos de salida)
-- =========================================================================
local function setupAlienTeleporter(portal: Instance)
	if not portal:IsA("BasePart") then
		return
	end
	portal.Touched:Connect(function(hit: BasePart)
		local exits = CollectionService:GetTagged("TeleporterExit")
		if #exits == 0 then
			return
		end
		local vehicle = getVehicleFromPart(hit)
		if vehicle and vehicle.PrimaryPart and not vehicle:GetAttribute("TeleportCooldown") then
			vehicle:SetAttribute("TeleportCooldown", true)

			local randomExit = exits[math.random(1, #exits)]
			local exitCFrame = if randomExit:IsA("BasePart")
				then randomExit.CFrame
				elseif randomExit:IsA("Model") then randomExit:GetPivot()
				else portal.CFrame
			-- Teletransportar elevando 5 studs para no atorarse
			vehicle:PivotTo(exitCFrame + Vector3.new(0, 5, 0))

			task.delay(4, function()
				if vehicle then
					vehicle:SetAttribute("TeleportCooldown", false)
				end
			end)
		end
	end)
end

for _, portal in ipairs(CollectionService:GetTagged("AlienTeleporter")) do
	setupAlienTeleporter(portal)
end
CollectionService:GetInstanceAddedSignal("AlienTeleporter"):Connect(setupAlienTeleporter)

-- =========================================================================
-- 4. GHOST TOWN: Tornado que succiona y lanza vehículos por los aires
-- Etiqueta: "TornadoZone" (Cilindro o Part invisible móvil)
-- =========================================================================
local function setupTornadoZone(tornado: Instance)
	if not tornado:IsA("BasePart") then
		return
	end
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not tornado.Parent then
			conn:Disconnect()
			return
		end
		-- Rotar visualmente el tornado
		tornado.CFrame *= CFrame.Angles(0, math.rad(180 * dt), 0)

		local parts = workspace:GetPartsInPart(tornado)
		local liftedVehicles: { [Model]: boolean } = {}

		for _, part in ipairs(parts) do
			local v = getVehicleFromPart(part)
			if v and v.PrimaryPart and not liftedVehicles[v] then
				liftedVehicles[v] = true
				-- Aplicar fuerza ascendente y centrípeta
				local pullDir = tornado.Position - v.PrimaryPart.Position
				local flatPull = Vector3.new(-pullDir.Z, 0, pullDir.X)
				local swirl = if flatPull.Magnitude > 0.001 then flatPull.Unit * 40 else Vector3.zero
				v.PrimaryPart.AssemblyLinearVelocity = Vector3.new(swirl.X, 65, swirl.Z)
			end
		end
	end)
end

for _, tornado in ipairs(CollectionService:GetTagged("TornadoZone")) do
	setupTornadoZone(tornado)
end
CollectionService:GetInstanceAddedSignal("TornadoZone"):Connect(setupTornadoZone)

-- =========================================================================
-- 5. HOOVER DAM: Interruptor que electrifica el agua
-- Etiquetas: "DamSwitch" (interruptor destructible) y "DamWater" (zona de agua)
-- =========================================================================
local function triggerDamElectrification()
	local waterZones = CollectionService:GetTagged("DamWater")
	for _, water in ipairs(waterZones) do
		if water:IsA("BasePart") then
			water.Color = Color3.fromRGB(0, 255, 255)
			water.Material = Enum.Material.Neon
		end
	end

	local startTime = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() - startTime > 8 then
			connection:Disconnect()
			for _, water in ipairs(waterZones) do
				if water:IsA("BasePart") then
					water.Color = Color3.fromRGB(30, 100, 180)
					water.Material = Enum.Material.SmoothPlastic
				end
			end
			return
		end

		for _, water in ipairs(waterZones) do
			if water:IsA("BasePart") and water.Parent then
				for _, part in ipairs(workspace:GetPartsInPart(water)) do
					local v = getVehicleFromPart(part)
					if v and not v:GetAttribute("ShockCooldown") then
						v:SetAttribute("ShockCooldown", true)
						VehicleHealthService.ApplyDamage(v, 15, water.Position)
						task.delay(0.8, function()
							if v then
								v:SetAttribute("ShockCooldown", false)
							end
						end)
					end
				end
			end
		end
	end)
end

local function setupDamSwitch(switch: Instance)
	local triggered = false
	local function onSwitchDestroyed()
		if triggered then
			return
		end
		triggered = true
		triggerDamElectrification()
	end

	switch:GetAttributeChangedSignal("IsDestroyed"):Connect(function()
		if switch:GetAttribute("IsDestroyed") then
			onSwitchDestroyed()
		end
	end)
	switch.AncestryChanged:Connect(function(_, parent)
		if not parent then
			onSwitchDestroyed()
		end
	end)
end

for _, switch in ipairs(CollectionService:GetTagged("DamSwitch")) do
	setupDamSwitch(switch)
end
CollectionService:GetInstanceAddedSignal("DamSwitch"):Connect(setupDamSwitch)
