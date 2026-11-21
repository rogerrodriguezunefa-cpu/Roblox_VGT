local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DestructionSystem = require(ServerScriptService:WaitForChild("DestructionSystem"))
local SpecialWeapons = require(ServerScriptService:WaitForChild("SpecialWeapons"))
local VehicleDamageFX = require(ServerScriptService:WaitForChild("VehicleDamageFX"))
local ProjectileService = require(ServerScriptService:WaitForChild("ProjectileService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local damageBindable = Instance.new("BindableEvent")
damageBindable.Name = "DamageVehicleEvent"
damageBindable.Parent = ServerScriptService

local firePrimary = Instance.new("RemoteEvent")
firePrimary.Name = "FirePrimary"
firePrimary.Parent = Remotes

local fireSpecial = Instance.new("RemoteEvent")
fireSpecial.Name = "FireSpecial"
fireSpecial.Parent = Remotes

local fireExclusiveSpecial = Instance.new("RemoteEvent")
fireExclusiveSpecial.Name = "FireExclusiveSpecial"
fireExclusiveSpecial.Parent = Remotes

local fireWeapon = Instance.new("RemoteEvent")
fireWeapon.Name = "FireWeapon"
fireWeapon.Parent = Remotes

local weaponVFX = Instance.new("RemoteEvent")
weaponVFX.Name = "WeaponVFX"
weaponVFX.Parent = Remotes

local selectWeaponSlot = Instance.new("RemoteEvent")
selectWeaponSlot.Name = "SelectWeaponSlot"
selectWeaponSlot.Parent = Remotes

local bulletEffect = Instance.new("RemoteEvent")
bulletEffect.Name = "BulletEffect"
bulletEffect.Parent = Remotes

local killFeed = Instance.new("RemoteEvent")
killFeed.Name = "KillFeed"
killFeed.Parent = Remotes

local lastFireTime: { [Player]: number } = {}
local lastSpecialTime: { [Player]: number } = {}
local barrelToggle: { [Player]: boolean } = {}

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

local function updateBotHealthGui(car: Model, health: number, maxHealth: number)
	local gui = car:FindFirstChild("BotHealthGui")
	if not gui then
		return
	end
	local bg = gui:FindFirstChild("Bg")
	if not bg then
		return
	end
	local ratio = math.clamp(health / math.max(1, maxHealth), 0, 1)
	local fill = bg:FindFirstChild("Fill") :: Frame?
	if fill then
		fill.Size = UDim2.fromScale(ratio, 1)
		if ratio > 0.5 then
			fill.BackgroundColor3 = Color3.fromRGB(75, 210, 95)
		elseif ratio > 0.25 then
			fill.BackgroundColor3 = Color3.fromRGB(235, 190, 45)
		else
			fill.BackgroundColor3 = Color3.fromRGB(225, 55, 55)
		end
	end
	local label = bg:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = string.format("BOT %d", math.max(0, math.ceil(health)))
	end
end

local function destroyVehicle(car: Model)
	if car:GetAttribute("Destroyed") then
		return
	end
	car:SetAttribute("Destroyed", true)

	-- Actualizar marcador (leaderstats) y Kill Feed
	local victimName = (car:GetAttribute("OwnerName") :: string?) or car.Name
	local attackerName = car:GetAttribute("LastAttacker") :: string?

	if not car:GetAttribute("IsBot") then
		local victimPlayer = Players:FindFirstChild(victimName)
		if victimPlayer then
			local ls = victimPlayer:FindFirstChild("leaderstats")
			local deaths = ls and ls:FindFirstChild("Muertes") :: IntValue?
			if deaths then
				deaths.Value += 1
			end
		end
	end

	if attackerName and attackerName ~= victimName then
		local attackerPlayer = Players:FindFirstChild(attackerName)
		if attackerPlayer then
			local ls = attackerPlayer:FindFirstChild("leaderstats")
			local kills = ls and ls:FindFirstChild("Eliminaciones") :: IntValue?
			if kills then
				kills.Value += 1
			end
		end
	end

	killFeed:FireAllClients(attackerName or "Arena", victimName)

	local chassis = car.PrimaryPart
	local explosionPos = if chassis then chassis.Position else car:GetPivot().Position

	-- Explosión visual estilo arcade (sin destruir el mapa)
	local explosion = Instance.new("Explosion")
	explosion.Position = explosionPos
	explosion.BlastRadius = 18
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace

	VehicleDamageFX.OnDestroyed(car)

	-- Expulsar al conductor si había alguien adentro
	local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat?
	if seat then
		if seat.Occupant then
			seat.Occupant.Sit = false
		end
		seat.Disabled = true
	end

	-- Apagar motores y ennegrecer la chatarra
	local motors = car:FindFirstChild("DriveMotors")
	if motors then
		for _, hinge in ipairs(motors:GetChildren()) do
			if hinge:IsA("HingeConstraint") then
				hinge.AngularVelocity = 0
			end
		end
	end

	for _, desc in ipairs(car:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Color = Color3.fromRGB(32, 32, 35)
			desc.Material = Enum.Material.CorrodedMetal
		elseif desc:IsA("ProximityPrompt") then
			desc.Enabled = false
		end
	end

	if chassis then
		chassis:ApplyImpulse(Vector3.new(0, 6500, 0))
	end

	Debris:AddItem(car, 3.0)
end

local function applyDamage(targetCar: Model, amount: number, attackerPlayer: Player?)
	if targetCar:GetAttribute("Destroyed") then
		return
	end
	local currentHealth = (targetCar:GetAttribute("Health") :: number?) or Config.VEHICLE.MAX_HEALTH
	local maxHealth = (targetCar:GetAttribute("MaxHealth") :: number?) or Config.VEHICLE.MAX_HEALTH
	local newHealth = math.max(0, currentHealth - amount)
	local actualDamage = math.round(currentHealth - newHealth)

	if attackerPlayer then
		targetCar:SetAttribute("LastAttacker", attackerPlayer.Name)
		local ownerName = targetCar:GetAttribute("OwnerName") :: string?
		if actualDamage > 0 and ownerName ~= attackerPlayer.Name then
			local ls = attackerPlayer:FindFirstChild("leaderstats")
			local dmgStat = ls and ls:FindFirstChild("Daño") :: IntValue?
			if dmgStat then
				dmgStat.Value += actualDamage
			end
		end
	end

	targetCar:SetAttribute("Health", newHealth)
	updateBotHealthGui(targetCar, newHealth, maxHealth)
	VehicleDamageFX.OnDamaged(targetCar, newHealth / math.max(1, maxHealth))

	if newHealth <= 0 then
		destroyVehicle(targetCar)
	end
end

damageBindable.Event:Connect(function(targetCar: Model, amount: number)
	if typeof(targetCar) == "Instance" and targetCar:IsA("Model") and typeof(amount) == "number" then
		applyDamage(targetCar, amount)
	end
end)

local function validateLockedTarget(shooterCar: Model, candidate: any): Model?
	if typeof(candidate) ~= "Instance" or not candidate:IsA("Model") then
		return nil
	end
	if candidate == shooterCar or not candidate:GetAttribute("IsVehicle") or candidate:GetAttribute("Destroyed") then
		return nil
	end
	local sChassis = shooterCar.PrimaryPart
	local tChassis = candidate.PrimaryPart
	if not sChassis or not tChassis then
		return nil
	end
	local offset = tChassis.Position - sChassis.Position
	local dist = offset.Magnitude
	if dist > 240 or dist < 1 then
		return nil
	end
	if sChassis.CFrame.LookVector:Dot(offset.Unit) < 0.35 then
		return nil
	end
	return candidate
end

firePrimary.OnServerEvent:Connect(function(player: Player, lockedTarget: Model?)
	local now = os.clock()
	if lastFireTime[player] and now - lastFireTime[player] < Config.COMBAT.MG_FIRE_RATE * 0.85 then
		return
	end
	lastFireTime[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local seat = humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return
	end

	local shooterCar = seat.Parent
	if not shooterCar or not shooterCar:IsA("Model") or not shooterCar:GetAttribute("IsVehicle") then
		return
	end
	if shooterCar:GetAttribute("Destroyed") then
		return
	end

	local chassis = shooterCar.PrimaryPart
	if not chassis then
		return
	end

	-- Alternar entre cañón izquierdo y derecho
	barrelToggle[player] = not barrelToggle[player]
	local barrelName = if barrelToggle[player] then "GunBarrelL" else "GunBarrelR"
	local barrel = shooterCar:FindFirstChild(barrelName) :: BasePart?

	local scale = (shooterCar:GetAttribute("VehicleScale") :: number?) or Config.VEHICLE.SCALE or 1.35
	local startPos = if barrel
		then barrel.Position + barrel.CFrame.LookVector * (1.4 * scale)
		else chassis.Position + chassis.CFrame.LookVector * (7.2 * scale) + Vector3.new(0, 1.2 * scale, 0)

	local validTarget = validateLockedTarget(shooterCar, lockedTarget)
	local forward = if validTarget and validTarget.PrimaryPart
		then (validTarget.PrimaryPart.Position - startPos).Unit
		else chassis.CFrame.LookVector
	local spread = Config.COMBAT.MG_SPREAD
	local dir = (forward + Vector3.new(
		(math.random() - 0.5) * spread,
		(math.random() - 0.5) * spread * 0.4,
		(math.random() - 0.5) * spread
	)).Unit

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { shooterCar, character }

	local result = Workspace:Raycast(startPos, dir * Config.COMBAT.MG_RANGE, rayParams)
	local endPos = if result then result.Position else startPos + dir * Config.COMBAT.MG_RANGE
	local hitVehicle = false

	if result and result.Instance then
		if result.Instance:GetAttribute("IsExplosiveBarrel") then
			result.Instance:SetAttribute("Detonated", true)
		elseif result.Instance:GetAttribute("IsShootableTrigger") then
			result.Instance:SetAttribute("Triggered", true)
		elseif DestructionSystem.Damage(result.Instance, Config.COMBAT.MG_DAMAGE, player, result.Position) then
			hitVehicle = true
		else
			local targetCar = findVehicleModel(result.Instance)
			if targetCar and targetCar ~= shooterCar then
				hitVehicle = true
				applyDamage(targetCar, Config.COMBAT.MG_DAMAGE, player)
			end
		end
	end

	bulletEffect:FireAllClients(startPos, endPos, hitVehicle)
end)

-- ==========================================
-- ARMAS ESTÁNDAR RECOLECTABLES (Estilo Vigilante 8 PS1)
-- ==========================================
local function explodeAt(pos: Vector3, radius: number, damage: number, ignoreCar: Model?, attackerPlayer: Player?, knockback: number?)
	local explosion = Instance.new("Explosion")
	explosion.Position = pos
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace

	local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
	if vehiclesFolder then
		for _, car in ipairs(vehiclesFolder:GetChildren()) do
			if car:IsA("Model") and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
				if car ~= ignoreCar and car.PrimaryPart then
					local offset = car.PrimaryPart.Position - pos
					local dist = offset.Magnitude
					if dist <= radius + 4 then
						applyDamage(car, damage, attackerPlayer)
						if knockback and knockback > 0 then
							local pushDir = if dist > 0.1 then (offset.Unit + Vector3.new(0, 0.45, 0)).Unit else Vector3.new(0, 1, 0)
							car.PrimaryPart:ApplyImpulse(pushDir * knockback)
						end
					end
				end
			end
		end
	end

	local arena = Workspace:FindFirstChild("TestArena")
	if arena then
		for _, obj in ipairs(arena:GetDescendants()) do
			if obj:IsA("BasePart") and obj:GetAttribute("IsExplosiveBarrel") and not obj:GetAttribute("Detonated") then
				if (obj.Position - pos).Magnitude <= radius + 4 then
					obj:SetAttribute("Detonated", true)
				end
			end
		end
	end
end

local function findNearestEnemy(shooterCar: Model, origin: Vector3, forward: Vector3): Model?
	local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
	if not vehiclesFolder then
		return nil
	end
	local bestTarget: Model? = nil
	local bestScore = math.huge

	for _, car in ipairs(vehiclesFolder:GetChildren()) do
		if car:IsA("Model") and car ~= shooterCar and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
			local chassis = car.PrimaryPart
			if chassis then
				local toTarget = chassis.Position - origin
				local dist = toTarget.Magnitude
				if dist < 210 and dist > 1 then
					local dot = forward:Dot(toTarget.Unit)
					local score = dist * (1.5 - dot * 0.5)
					if score < bestScore then
						bestScore = score
						bestTarget = car
					end
				end
			end
		end
	end
	return bestTarget
end

local function spawnProjectile(opts: {
	Name: string,
	Size: Vector3,
	Color: Color3,
	StartPos: Vector3,
	Velocity: Vector3,
	Gravity: number?,
	Lifetime: number,
	BlastRadius: number,
	Damage: number,
	Knockback: number?,
	HomingTurnRate: number?,
	ShooterCar: Model,
	Character: Model,
	Attacker: Player,
})
	local proj = Instance.new("Part")
	proj.Name = opts.Name
	proj.Size = opts.Size
	proj.Color = opts.Color
	proj.Material = Enum.Material.Neon
	proj.Anchored = true
	proj.CanCollide = false
	proj.CanQuery = false
	proj.CFrame = CFrame.lookAt(opts.StartPos, opts.StartPos + opts.Velocity)
	proj.Parent = Workspace

	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Parent = proj

	local vel = opts.Velocity
	local speed = vel.Magnitude
	local gravity = opts.Gravity or 0
	local spawnedAt = os.clock()
	local conn: RBXScriptConnection

	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not proj.Parent or os.clock() - spawnedAt > opts.Lifetime then
			if conn then
				conn:Disconnect()
			end
			if proj.Parent then
				explodeAt(proj.Position, opts.BlastRadius, opts.Damage, opts.ShooterCar, opts.Attacker, opts.Knockback)
				proj:Destroy()
			end
			return
		end

		if opts.HomingTurnRate and opts.HomingTurnRate > 0 then
			local target = findNearestEnemy(opts.ShooterCar, proj.Position, vel.Unit)
			if target and target.PrimaryPart then
				local desiredDir = (target.PrimaryPart.Position + Vector3.new(0, 1, 0) - proj.Position).Unit
				local newDir = vel.Unit:Lerp(desiredDir, math.clamp(dt * opts.HomingTurnRate, 0, 1)).Unit
				vel = newDir * speed
			end
		end

		if gravity > 0 then
			vel = vel - Vector3.new(0, gravity * dt, 0)
		end

		local step = vel * dt
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { opts.ShooterCar, opts.Character, proj }

		local hit = Workspace:Raycast(proj.Position, step + vel.Unit * 1.5, rayParams)
		if hit then
			conn:Disconnect()
			explodeAt(hit.Position, opts.BlastRadius, opts.Damage, opts.ShooterCar, opts.Attacker, opts.Knockback)
			proj:Destroy()
			return
		end

		local nextPos = proj.Position + step
		proj.CFrame = CFrame.lookAt(nextPos, nextPos + vel)
	end)
end

local function dropMineAt(shooterCar: Model, attackerPlayer: Player, sideOffset: number)
	local chassis = shooterCar.PrimaryPart
	if not chassis then
		return
	end

	local cfg = Config.WEAPONS.CATALOG.Mines
	local scale = (shooterCar:GetAttribute("VehicleScale") :: number?) or Config.VEHICLE.SCALE or 1.35
	local mounted = shooterCar:FindFirstChild("MountedWeapons")
	local tray = mounted and mounted:FindFirstChild("MineTray") :: BasePart?
	local baseOrigin = if tray
		then tray.Position - chassis.CFrame.LookVector * (1.8 * scale) + chassis.CFrame.RightVector * sideOffset + Vector3.new(0, 1.5, 0)
		else chassis.Position - chassis.CFrame.LookVector * (9.5 * scale) + chassis.CFrame.RightVector * sideOffset + Vector3.new(0, 2, 0)
	local dropOrigin = baseOrigin
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { shooterCar }

	local groundHit = Workspace:Raycast(dropOrigin, Vector3.new(0, -15, 0), rayParams)
	local minePos = if groundHit then groundHit.Position + Vector3.new(0, 0.45, 0) else dropOrigin - Vector3.new(0, 2, 0)

	local mine = Instance.new("Part")
	mine.Name = "LandMine"
	mine.Shape = Enum.PartType.Cylinder
	mine.Size = Vector3.new(0.9, 3.4, 3.4)
	mine.CFrame = CFrame.new(minePos) * CFrame.Angles(0, 0, math.rad(90))
	mine.Anchored = true
	mine.CanCollide = false
	mine.CanQuery = false
	mine.Material = Enum.Material.Metal
	mine.Color = Color3.fromRGB(90, 90, 95)
	mine.Parent = Workspace

	local beacon = Instance.new("Part")
	beacon.Name = "MineBeacon"
	beacon.Shape = Enum.PartType.Ball
	beacon.Size = Vector3.new(1.2, 1.2, 1.2)
	beacon.Position = minePos + Vector3.new(0, 0.4, 0)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = cfg.Color
	beacon.Parent = mine

	task.spawn(function()
		task.wait(cfg.ArmDelay)
		if not mine.Parent then
			return
		end
		beacon.Color = Color3.fromRGB(255, 45, 45)

		local armedAt = os.clock()
		while mine.Parent and os.clock() - armedAt < cfg.Lifetime do
			local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
			if vehiclesFolder then
				for _, car in ipairs(vehiclesFolder:GetChildren()) do
					if car:IsA("Model") and car ~= shooterCar and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
						if car.PrimaryPart and (car.PrimaryPart.Position - minePos).Magnitude <= cfg.Radius then
							explodeAt(minePos, 15, cfg.Damage, nil, attackerPlayer)
							mine:Destroy()
							return
						end
					end
				end
			end
			task.wait(0.1)
		end

		if mine.Parent then
			mine:Destroy()
		end
	end)
end

local function getSeatedShooterCar(player: Player): (Model?, Model?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	local seat = humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return nil, nil
	end
	local shooterCar = seat.Parent
	if not shooterCar or not shooterCar:IsA("Model") or not shooterCar:GetAttribute("IsVehicle") or shooterCar:GetAttribute("Destroyed") then
		return nil, nil
	end
	return shooterCar, character
end

selectWeaponSlot.OnServerEvent:Connect(function(player: Player, slotIndex: number)
	if typeof(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > Config.WEAPONS.MAX_SLOTS then
		return
	end
	local shooterCar = getSeatedShooterCar(player)
	if shooterCar then
		shooterCar:SetAttribute("ActiveSlot", math.floor(slotIndex))
	end
end)

local function getMountedMuzzle(car: Model, partName: string, fallbackLocal: Vector3): Vector3
	local chassis = car.PrimaryPart :: BasePart
	local scale = (car:GetAttribute("VehicleScale") :: number?) or Config.VEHICLE.SCALE or 1.35
	local mounted = car:FindFirstChild("MountedWeapons")
	local part = mounted and mounted:FindFirstChild(partName) :: BasePart?
	if part then
		return part.Position + chassis.CFrame.LookVector * (1.2 * scale)
	end
	return (chassis.CFrame * CFrame.new(fallbackLocal * scale)).Position
end

local function getForwardAimPoint(car: Model, character: Model, lockedTarget: Model?): Vector3
	local validTarget = validateLockedTarget(car, lockedTarget)
	if validTarget and validTarget.PrimaryPart then
		return validTarget.PrimaryPart.Position
	end
	local chassis = car.PrimaryPart :: BasePart
	local scale = (car:GetAttribute("VehicleScale") :: number?) or Config.VEHICLE.SCALE or 1.35
	local origin = chassis.Position + Vector3.new(0, 1.4 * scale, 0) + chassis.CFrame.LookVector * (7.5 * scale)
	local dir = chassis.CFrame.LookVector
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { car, character }
	local hit = Workspace:Raycast(origin, dir * 200, rayParams)
	return if hit then hit.Position else origin + dir * 200
end

fireSpecial.OnServerEvent:Connect(function(player: Player, wantsCombo: boolean?, lockedTarget: Model?)
	local now = os.clock()
	if lastSpecialTime[player] and now - lastSpecialTime[player] < 0.35 then
		return
	end
	lastSpecialTime[player] = now

	local shooterCar, character = getSeatedShooterCar(player)
	if not shooterCar or not character or not shooterCar.PrimaryPart then
		return
	end

	local activeSlot = (shooterCar:GetAttribute("ActiveSlot") :: number?) or 1
	local weaponId = shooterCar:GetAttribute("Slot" .. activeSlot .. "Weapon") :: string?
	local ammo = (shooterCar:GetAttribute("Slot" .. activeSlot .. "Ammo") :: number?) or 0
	if not weaponId or ammo <= 0 then
		return
	end

	local cfg = Config.WEAPONS.CATALOG[weaponId]
	if not cfg then
		return
	end

	-- Capturar la posición exacta de salida del arma montada antes de descontar la última munición
	local chassis = shooterCar.PrimaryPart
	local look = chassis.CFrame.LookVector
	local right = chassis.CFrame.RightVector
	local aimPoint = getForwardAimPoint(shooterCar, character, lockedTarget)

	local muzzlePos = if weaponId == "Rockets"
		then getMountedMuzzle(shooterCar, "RocketsPodBase", Vector3.new(0, 1.8, -7.2))
		elseif weaponId == "Interceptor" then getMountedMuzzle(shooterCar, "MissileRack", Vector3.new(5.2, 1.2, 1.0))
		elseif weaponId == "Mortar" then getMountedMuzzle(shooterCar, "MortarRing", Vector3.new(-5.2, 2.2, -1.5))
		elseif weaponId == "Cannon" then getMountedMuzzle(shooterCar, "CannonMuzzle", Vector3.new(0, 4.4, -6.0))
		else (chassis.Position + Vector3.new(0, 2.0, 0) + look * 8)

	local isCombo = wantsCombo == true and ammo >= cfg.ComboCost
	local cost = if isCombo then cfg.ComboCost else 1

	ammo -= cost
	shooterCar:SetAttribute("Slot" .. activeSlot .. "Ammo", ammo)
	if ammo <= 0 then
		shooterCar:SetAttribute("Slot" .. activeSlot .. "Weapon", nil)
		for s = 1, Config.WEAPONS.MAX_SLOTS do
			local nextW = shooterCar:GetAttribute("Slot" .. s .. "Weapon")
			local nextA = (shooterCar:GetAttribute("Slot" .. s .. "Ammo") :: number?) or 0
			if nextW and nextA > 0 then
				shooterCar:SetAttribute("ActiveSlot", s)
				break
			end
		end
	end

	local aimDir = (aimPoint - muzzlePos).Unit

	if weaponId == "Interceptor" then
		local angles = if isCombo then { -0.22, 0, 0.22 } else { 0 }
		for _, ang in ipairs(angles) do
			local dir = (aimDir + right * ang).Unit
			spawnProjectile({
				Name = "InterceptorMissile",
				Size = Vector3.new(0.9, 0.9, 3.2),
				Color = cfg.Color,
				StartPos = muzzlePos,
				Velocity = dir * cfg.Speed,
				Lifetime = cfg.Lifetime,
				BlastRadius = 15,
				Damage = cfg.Damage,
				HomingTurnRate = cfg.TurnRate,
				ShooterCar = shooterCar,
				Character = character,
				Attacker = player,
			})
		end
	elseif weaponId == "Rockets" then
		local count = if isCombo then 3 else 1
		for i = 1, count do
			task.delay((i - 1) * 0.12, function()
				if not shooterCar.Parent or not shooterCar.PrimaryPart then
					return
				end
				local curMuzzle = getMountedMuzzle(shooterCar, "RocketsPodBase", Vector3.new(0, 1.8, -7.2))
				local curAim = (getForwardAimPoint(shooterCar, character, lockedTarget) - curMuzzle).Unit
				spawnProjectile({
					Name = "BullsEyeRocket",
					Size = Vector3.new(0.8, 0.8, 3.0),
					Color = cfg.Color,
					StartPos = curMuzzle,
					Velocity = curAim * cfg.Speed,
					Lifetime = cfg.Lifetime,
					BlastRadius = 12,
					Damage = cfg.Damage,
					ShooterCar = shooterCar,
					Character = character,
					Attacker = player,
				})
			end)
		end
	elseif weaponId == "Mortar" then
		local spreads = if isCombo then { -0.18, 0, 0.18 } else { 0 }
		for _, sp in ipairs(spreads) do
			local dir = (look + right * sp).Unit
			spawnProjectile({
				Name = "SkyHammerMortar",
				Size = Vector3.new(1.5, 1.5, 1.5),
				Color = cfg.Color,
				StartPos = muzzlePos,
				Velocity = dir * cfg.Speed + Vector3.new(0, cfg.ArcUp, 0),
				Gravity = cfg.Gravity,
				Lifetime = cfg.Lifetime,
				BlastRadius = 21,
				Damage = cfg.Damage,
				ShooterCar = shooterCar,
				Character = character,
				Attacker = player,
			})
		end
	elseif weaponId == "Cannon" then
		spawnProjectile({
			Name = "BruiserCannonShell",
			Size = if isCombo then Vector3.new(2.0, 2.0, 2.0) else Vector3.new(1.4, 1.4, 1.4),
			Color = cfg.Color,
			StartPos = muzzlePos,
			Velocity = aimDir * cfg.Speed,
			Lifetime = cfg.Lifetime,
			BlastRadius = if isCombo then 18 else 13,
			Damage = if isCombo then cfg.Damage * 1.5 else cfg.Damage,
			Knockback = if isCombo then cfg.Knockback * 1.8 else cfg.Knockback,
			ShooterCar = shooterCar,
			Character = character,
			Attacker = player,
		})
	elseif weaponId == "Mines" then
		local offsets = if isCombo then { -4.5, 0, 4.5 } else { 0 }
		for _, off in ipairs(offsets) do
			dropMineAt(shooterCar, player, off)
		end
	end
end)

fireExclusiveSpecial.OnServerEvent:Connect(function(player: Player, lockedTarget: Model?)
	local now = os.clock()
	if lastSpecialTime[player] and now - lastSpecialTime[player] < 0.6 then
		return
	end
	lastSpecialTime[player] = now

	local shooterCar, character = getSeatedShooterCar(player)
	if not shooterCar or not character or not shooterCar.PrimaryPart then
		return
	end

	local ammo = (shooterCar:GetAttribute("ExclusiveSpecialAmmo") :: number?) or 0
	if ammo <= 0 then
		return
	end

	local muzzlePos = getMountedMuzzle(shooterCar, "ExclusiveCore", Vector3.new(-1.5, 2.1, -5.6))
	local aimPoint = getForwardAimPoint(shooterCar, character, lockedTarget)

	local vehicleId = (shooterCar:GetAttribute("VehicleType") :: string?) or "Rattler"
	shooterCar:SetAttribute("ExclusiveSpecialAmmo", ammo - 1)

	SpecialWeapons.Fire(vehicleId, {
		ShooterCar = shooterCar,
		Character = character,
		Player = player,
		MuzzlePos = muzzlePos,
		AimDir = (aimPoint - muzzlePos).Unit,
		ApplyDamage = applyDamage,
		ExplodeAt = explodeAt,
		FindNearestEnemy = findNearestEnemy,
		SpawnProjectile = spawnProjectile,
		BulletEffect = bulletEffect,
	})
end)

fireWeapon.OnServerEvent:Connect(function(player: Player, mountPointName: string, targetVehicle: Model?)
	local now = os.clock()
	if lastSpecialTime[player] and now - lastSpecialTime[player] < 0.35 then
		return
	end
	lastSpecialTime[player] = now

	local shooterCar, character = getSeatedShooterCar(player)
	if not shooterCar or not character or not shooterCar.PrimaryPart then
		return
	end

	local chassis = shooterCar.PrimaryPart
	local equipped = shooterCar:FindFirstChild("EquippedWeapons")
	local mounted = equipped and equipped:FindFirstChild(if typeof(mountPointName) == "string" then mountPointName else "RoofMount") :: Model?
	local originPos = if mounted and mounted.PrimaryPart
		then mounted.PrimaryPart.Position
		else getMountedMuzzle(shooterCar, "CannonMuzzle", Vector3.new(0, 3.2, -2.0))

	local ammo = if mounted then (mounted:GetAttribute("Ammo") :: number?) or 0 else 1
	if mounted and ammo <= 0 then
		mounted:Destroy()
		return
	end
	if mounted then
		mounted:SetAttribute("Ammo", ammo - 1)
	end

	local validTarget = validateLockedTarget(shooterCar, targetVehicle)
	local weaponId = if mounted then (mounted:GetAttribute("WeaponId") :: string?) or "MountedWeapon" else "MountedWeapon"
	local muzzleCFrame = if mounted and mounted.PrimaryPart
		then mounted.PrimaryPart.CFrame
		else chassis.CFrame * CFrame.new(0, 3.2, -2.0)

	if weaponId == "InterceptorMissiles" or weaponId == "ScatterMissiles" then
		ProjectileService.SpawnHomingMissile(muzzleCFrame, validTarget, shooterCar, player, 120, 35)
	elseif weaponId == "SteelBelted" then
		ProjectileService.SpawnBouncingTire(muzzleCFrame, shooterCar, player, 140, 40)
	elseif weaponId == "RoadkillMines" then
		local dropPos = chassis.Position - chassis.CFrame.LookVector * 8
		ProjectileService.DropMine(dropPos, shooterCar, player, 45)
	else
		local dir = if validTarget and validTarget.PrimaryPart
			then (validTarget.PrimaryPart.Position - originPos).Unit
			else chassis.CFrame.LookVector

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { shooterCar, character }

		local res = Workspace:Raycast(originPos, dir * 300, rayParams)
		local hitPos = if res then res.Position else originPos + dir * 300

		if res and res.Instance then
			local hitCar = findVehicleModel(res.Instance)
			if hitCar and hitCar ~= shooterCar then
				applyDamage(hitCar, 25, player)
			end
		end

		weaponVFX:FireAllClients(originPos, hitPos, weaponId)
	end

	if mounted and ((mounted:GetAttribute("Ammo") :: number?) or 0) <= 0 then
		task.delay(0.2, function()
			if mounted and mounted.Parent then
				mounted:Destroy()
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastFireTime[player] = nil
	lastSpecialTime[player] = nil
	barrelToggle[player] = nil
end)
