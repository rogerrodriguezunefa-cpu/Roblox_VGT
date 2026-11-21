--!strict
-- ServerScriptService/BotAIService.luau
-- Controla la IA de conducción, evasión de obstáculos por raycast, recolección de cajas y disparo de bots enemigos.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProjectileService = require(ServerScriptService:WaitForChild("ProjectileService"))
local VehicleHealthService = require(ServerScriptService:WaitForChild("VehicleHealthService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeaponVFXEvent = Remotes:WaitForChild("WeaponVFX") :: RemoteEvent

local BotAIService = {}

local AI_CONFIG = {
	DetectionRange = 350,   -- Distancia máxima para detectar enemigos
	AttackRange = 160,      -- Distancia ideal para empezar a disparar
	MinCombatDistance = 35, -- Distancia mínima para no chocar de frente al disparar
	SensorLength = 28,      -- Longitud de rayos frontales para esquivar muros
	FireCooldown = 1.6,     -- Tiempo entre disparos del bot
}

-- Verifica si el bot tiene alguna arma con munición equipada
local function getActiveWeapon(botVehicle: Model): Model?
	local equipped = botVehicle:FindFirstChild("EquippedWeapons")
	if not equipped then
		return nil
	end

	for _, weapon in ipairs(equipped:GetChildren()) do
		if weapon:IsA("Model") and ((weapon:GetAttribute("Ammo") :: number?) or 0) > 0 then
			return weapon
		end
	end
	return nil
end

-- Busca la caja de armas disponible más cercana
local function findNearestCrate(originPos: Vector3): BasePart?
	local nearest: BasePart? = nil
	local shortestDist = math.huge

	for _, crate in ipairs(CollectionService:GetTagged("WeaponCrate")) do
		if crate:IsA("BasePart") and crate.CanTouch and crate.Transparency < 1 then
			local dist = (crate.Position - originPos).Magnitude
			if dist < shortestDist then
				shortestDist = dist
				nearest = crate
			end
		end
	end
	return nearest
end

-- Busca el vehículo enemigo vivo más cercano
local function findNearestEnemy(botVehicle: Model): Model?
	local myChassis = botVehicle.PrimaryPart
	if not myChassis then
		return nil
	end

	local nearest: Model? = nil
	local shortestDist = AI_CONFIG.DetectionRange

	for _, vehicle in ipairs(CollectionService:GetTagged("CombatVehicle")) do
		if vehicle:IsA("Model")
			and vehicle ~= botVehicle
			and vehicle.PrimaryPart
			and not vehicle:GetAttribute("IsDestroyed")
			and ((vehicle:GetAttribute("Health") :: number?) or 0) > 0
		then
			local dist = (vehicle.PrimaryPart.Position - myChassis.Position).Magnitude
			if dist < shortestDist then
				shortestDist = dist
				nearest = vehicle
			end
		end
	end
	return nearest
end

-- Ejecuta el disparo del bot usando ProjectileService o rayos de energía
local function botFireWeapon(botVehicle: Model, weaponModel: Model, targetVehicle: Model)
	local ammo = (weaponModel:GetAttribute("Ammo") :: number?) or 0
	if ammo <= 0 then
		weaponModel:Destroy()
		return
	end

	weaponModel:SetAttribute("Ammo", ammo - 1)
	local weaponId = (weaponModel:GetAttribute("WeaponId") :: string?) or "InterceptorMissiles"
	local muzzlePart = weaponModel.PrimaryPart or botVehicle.PrimaryPart
	if not muzzlePart then
		return
	end

	local spawnCFrame = muzzlePart.CFrame * CFrame.new(0, 0, -4)

	if weaponId == "InterceptorMissiles" or weaponId == "ScatterMissiles" then
		ProjectileService.SpawnHomingMissile(spawnCFrame, targetVehicle, botVehicle, nil, 120, 35)
	elseif weaponId == "SteelBelted" then
		ProjectileService.SpawnBouncingTire(spawnCFrame, botVehicle, nil, 140, 40)
	else
		local origin = muzzlePart.Position
		local targetRoot = targetVehicle.PrimaryPart
		if targetRoot then
			local targetPos = targetRoot.Position
			WeaponVFXEvent:FireAllClients(origin, targetPos, weaponId)
			VehicleHealthService.ApplyDamage(targetVehicle, 18, targetPos)
		end
	end

	if ((weaponModel:GetAttribute("Ammo") :: number?) or 0) <= 0 then
		task.delay(0.2, function()
			if weaponModel.Parent then
				weaponModel:Destroy()
			end
		end)
	end
end

-- Inicia el bucle de inteligencia artificial para un vehículo bot
function BotAIService.StartBotAI(botVehicle: Model)
	if botVehicle:GetAttribute("BotAIActive") then
		return
	end

	local chassisInst = botVehicle.PrimaryPart or botVehicle:FindFirstChild("Chassis")
	if not chassisInst or not chassisInst:IsA("BasePart") then
		return
	end
	local chassis = chassisInst :: BasePart

	local seatInst = chassis:FindFirstChildOfClass("VehicleSeat")
		or botVehicle:FindFirstChild("DriverSeat")
		or botVehicle:FindFirstChildWhichIsA("VehicleSeat", true)
	if not seatInst or not seatInst:IsA("VehicleSeat") then
		return
	end
	local seat = seatInst :: VehicleSeat

	botVehicle:SetAttribute("BotAIActive", true)

	-- Asegurar que el servidor controle la física del bot
	if chassis:CanSetNetworkOwnership() then
		chassis:SetNetworkOwner(nil)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { botVehicle }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local lastFireTime = 0
	local stuckTimer = 0
	local isReversing = false

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		-- Detener IA si el bot fue destruido
		if not botVehicle.Parent or botVehicle:GetAttribute("IsDestroyed") or botVehicle:GetAttribute("Destroyed") then
			connection:Disconnect()
			return
		end

		local myPos = chassis.Position
		local forward = chassis.CFrame.LookVector
		local right = chassis.CFrame.RightVector
		local speed = chassis.AssemblyLinearVelocity.Magnitude

		-- 1. Detección de atasco (si no se mueve durante 1.5s)
		if speed < 3 and not isReversing then
			stuckTimer += dt
			if stuckTimer > 1.5 then
				isReversing = true
				stuckTimer = 0
				task.delay(1.2, function()
					isReversing = false
				end)
			end
		else
			stuckTimer = 0
		end

		if isReversing then
			seat.ThrottleFloat = -0.8
			seat.SteerFloat = 1
			return
		end

		-- 2. Decidir objetivo (buscar caja si no tiene armas, o cazar enemigo)
		local activeWeapon = getActiveWeapon(botVehicle)
		local enemy = findNearestEnemy(botVehicle)
		local goalPosition: Vector3? = nil

		if not activeWeapon then
			local crate = findNearestCrate(myPos)
			if crate then
				goalPosition = crate.Position
			elseif enemy and enemy.PrimaryPart then
				goalPosition = enemy.PrimaryPart.Position
			end
		elseif enemy and enemy.PrimaryPart then
			goalPosition = enemy.PrimaryPart.Position
		end

		-- 3. Navegación y evasión de obstáculos por raycast
		local throttle = 0.85
		local steer = 0

		local leftSensorDir = (forward - right * 0.45).Unit * AI_CONFIG.SensorLength
		local rightSensorDir = (forward + right * 0.45).Unit * AI_CONFIG.SensorLength

		local hitLeft = workspace:Raycast(myPos, leftSensorDir, rayParams)
		local hitRight = workspace:Raycast(myPos, rightSensorDir, rayParams)

		if hitLeft and not hitRight then
			steer = 1
		elseif hitRight and not hitLeft then
			steer = -1
		elseif hitLeft and hitRight then
			steer = 1
			throttle = -0.5
		elseif goalPosition then
			local toGoal = goalPosition - myPos
			local distToGoal = toGoal.Magnitude
			local flatGoal = Vector3.new(toGoal.X, 0, toGoal.Z)
			local flatRightVec = Vector3.new(right.X, 0, right.Z)

			if flatGoal.Magnitude > 0.001 and flatRightVec.Magnitude > 0.001 then
				local sideDot = flatRightVec.Unit:Dot(flatGoal.Unit)
				steer = math.clamp(sideDot * 2.5, -1, 1)
			end

			if activeWeapon and enemy and distToGoal < AI_CONFIG.MinCombatDistance then
				throttle = 0.2
			end
		end

		-- Activar derrape automático en curvas muy cerradas a alta velocidad
		seat:SetAttribute("IsDrifting", math.abs(steer) > 0.85 and speed > 55)

		seat.ThrottleFloat = throttle
		seat.SteerFloat = steer

		-- 4. Lógica de disparo
		if activeWeapon and enemy and enemy.PrimaryPart then
			local toEnemy = enemy.PrimaryPart.Position - myPos
			local dist = toEnemy.Magnitude
			if dist > 0.001 then
				local aimDot = forward:Dot(toEnemy.Unit)
				if dist <= AI_CONFIG.AttackRange and aimDot >= 0.82 then
					if os.clock() - lastFireTime >= AI_CONFIG.FireCooldown then
						lastFireTime = os.clock()
						botFireWeapon(botVehicle, activeWeapon, enemy)
					end
				end
			end
		end
	end)
end

return BotAIService
