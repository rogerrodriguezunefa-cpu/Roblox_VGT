local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpecialWeapons = {}

export type CombatContext = {
	ShooterCar: Model,
	Character: Model,
	Player: Player,
	MuzzlePos: Vector3,
	AimDir: Vector3,
	ApplyDamage: (targetCar: Model, amount: number, attacker: Player?) -> (),
	ExplodeAt: (pos: Vector3, radius: number, damage: number, ignoreCar: Model?, attacker: Player?, knockback: number?) -> (),
	FindNearestEnemy: (shooterCar: Model, origin: Vector3, forward: Vector3) -> Model?,
	SpawnProjectile: (opts: { [string]: any }) -> (),
	BulletEffect: RemoteEvent,
}

local function spawnBeam(startPos: Vector3, endPos: Vector3, color: Color3, thickness: number, duration: number)
	local dist = (endPos - startPos).Magnitude
	if dist < 0.1 then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "SpecialBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(thickness, thickness, dist)
	beam.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = Workspace
	Debris:AddItem(beam, duration)
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

local function raycastBeam(ctx: CombatContext, origin: Vector3, dir: Vector3, range: number, damage: number, color: Color3, thickness: number, duration: number, explodeRadius: number?)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { ctx.ShooterCar, ctx.Character }

	local res = Workspace:Raycast(origin, dir * range, rayParams)
	local endPos = if res then res.Position else origin + dir * range
	spawnBeam(origin, endPos, color, thickness, duration)

	if res and res.Instance then
		if res.Instance:GetAttribute("IsExplosiveBarrel") then
			res.Instance:SetAttribute("Detonated", true)
		end
		local target = findVehicleModel(res.Instance)
		if target and target ~= ctx.ShooterCar then
			ctx.ApplyDamage(target, damage, ctx.Player)
		end
		if explodeRadius and explodeRadius > 0 then
			ctx.ExplodeAt(endPos, explodeRadius, damage * 0.4, ctx.ShooterCar, ctx.Player, 0)
		end
	end
end

local handlers: { [string]: (ctx: CombatContext) -> () } = {}

-- 1. Rattler (Chassey Blue) - Gridlock: Inmoviliza al rival
handlers.Rattler = function(ctx)
	local startPos = ctx.MuzzlePos
	local dir = ctx.AimDir
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { ctx.ShooterCar, ctx.Character }

	local res = Workspace:Raycast(startPos, dir * 180, rayParams)
	local endPos = if res then res.Position else startPos + dir * 180
	spawnBeam(startPos, endPos, Color3.fromRGB(45, 210, 255), 0.7, 0.25)

	if res and res.Instance then
		local target = findVehicleModel(res.Instance)
		if target and target ~= ctx.ShooterCar and target.PrimaryPart then
			ctx.ApplyDamage(target, 30, ctx.Player)
			local tChassis = target.PrimaryPart
			local origColor = tChassis.Color
			tChassis.Anchored = true
			tChassis.Color = Color3.fromRGB(90, 225, 255)
			task.delay(2.5, function()
				if tChassis.Parent then
					tChassis.Anchored = false
					if not target:GetAttribute("Destroyed") then
						tChassis.Color = origColor
					end
				end
			end)
		end
	end
end

-- 2. Clydesdale (Slick Clyde) - Lightning Bolt: Rayo eléctrico de largo alcance
handlers.Clydesdale = function(ctx)
	raycastBeam(ctx, ctx.MuzzlePos, ctx.AimDir, 240, 48, Color3.fromRGB(160, 225, 255), 0.65, 0.22, 8)
end

-- 3. Strider (Sheila) - Tantrum Gun: Ametralladora pesada de altísima cadencia
handlers.Strider = function(ctx)
	task.spawn(function()
		for i = 1, 12 do
			if not ctx.ShooterCar.Parent or not ctx.ShooterCar.PrimaryPart or ctx.ShooterCar:GetAttribute("Destroyed") then
				break
			end
			local c = ctx.ShooterCar.PrimaryPart
			local scale = (ctx.ShooterCar:GetAttribute("VehicleScale") :: number?) or 1.35
			local mounted = ctx.ShooterCar:FindFirstChild("MountedWeapons")
			local core = mounted and mounted:FindFirstChild("ExclusiveCore") :: BasePart?
			local startPos = if core then core.Position else c.Position + Vector3.new(0, 2.0 * scale, 0) + c.CFrame.LookVector * (5.5 * scale)
			local spread = Vector3.new((math.random() - 0.5) * 0.05, (math.random() - 0.5) * 0.02, (math.random() - 0.5) * 0.05)
			local dir = (c.CFrame.LookVector + spread).Unit
			raycastBeam(ctx, startPos, dir, 210, 7, Color3.fromRGB(255, 115, 175), 0.25, 0.08)
			task.wait(0.07)
		end
	end)
end

-- 4. Jefferson (John Torque) - Bass Quake: Onda expansiva sónica alrededor del auto
handlers.Jefferson = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	local pos = chassis.Position

	local ring = Instance.new("Part")
	ring.Name = "BassQuakeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1.2, 12, 12)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(175, 75, 255)
	ring.Transparency = 0.25
	ring.Parent = Workspace

	task.spawn(function()
		for step = 1, 10 do
			if not ring.Parent then
				break
			end
			local s = 12 + step * 5.5
			ring.Size = Vector3.new(1.2, s, s)
			ring.Transparency = 0.25 + step * 0.07
			task.wait(0.03)
		end
		ring:Destroy()
	end)

	ctx.ExplodeAt(pos, 34, 45, ctx.ShooterCar, ctx.Player, 15000)
end

-- 5. Van (Dave) - Invasion: Invoca platillos voladores que atacan con láser
handlers.Van = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	for _, side in ipairs({ -7, 7 }) do
		local ufo = Instance.new("Part")
		ufo.Name = "InvasionUFO"
		ufo.Shape = Enum.PartType.Cylinder
		ufo.Size = Vector3.new(1.5, 6, 6)
		ufo.Anchored = true
		ufo.CanCollide = false
		ufo.CanQuery = false
		ufo.Material = Enum.Material.Neon
		ufo.Color = Color3.fromRGB(85, 255, 130)
		ufo.CFrame = CFrame.new(chassis.Position + Vector3.new(side, 12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ufo.Parent = Workspace

		task.spawn(function()
			for _ = 1, 6 do
				if not ufo.Parent or not ctx.ShooterCar.Parent then
					break
				end
				local c = ctx.ShooterCar.PrimaryPart
				if c then
					ufo.CFrame = CFrame.new(c.Position + Vector3.new(side, 12, 0)) * CFrame.Angles(0, 0, math.rad(90))
					local target = ctx.FindNearestEnemy(ctx.ShooterCar, ufo.Position, c.CFrame.LookVector)
					if target and target.PrimaryPart then
						local dir = (target.PrimaryPart.Position - ufo.Position).Unit
						raycastBeam(ctx, ufo.Position, dir, 180, 10, Color3.fromRGB(85, 255, 130), 0.35, 0.14)
					end
				end
				task.wait(0.85)
			end
			if ufo.Parent then
				ufo:Destroy()
			end
		end)
	end
end

-- 6. MothTruck (Convoy) - Steel Belted: Neumáticos explosivos que rebotan
handlers.MothTruck = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	for _, xOff in ipairs({ -2.5, 2.5 }) do
		local tire = Instance.new("Part")
		tire.Name = "SteelBeltedTire"
		tire.Shape = Enum.PartType.Cylinder
		tire.Size = Vector3.new(1.6, 4.2, 4.2)
		tire.Color = Color3.fromRGB(30, 30, 35)
		tire.Material = Enum.Material.Rubber
		tire.CustomPhysicalProperties = PhysicalProperties.new(1.0, 0.2, 0.9)
		tire.CFrame = chassis.CFrame * CFrame.new(xOff, 1.5, -8)
		tire.Parent = Workspace
		tire.AssemblyLinearVelocity = chassis.CFrame.LookVector * 120 + Vector3.new(0, 18, 0)

		local exploded = false
		tire.Touched:Connect(function(hit: BasePart)
			if exploded then
				return
			end
			local car = findVehicleModel(hit)
			if car and car ~= ctx.ShooterCar then
				exploded = true
				ctx.ExplodeAt(tire.Position, 16, 50, ctx.ShooterCar, ctx.Player, 10000)
				tire:Destroy()
			end
		end)

		task.delay(3.2, function()
			if not exploded and tire.Parent then
				exploded = true
				ctx.ExplodeAt(tire.Position, 15, 45, ctx.ShooterCar, ctx.Player, 8000)
				tire:Destroy()
			end
		end)
	end
end

-- 7. Glenn4x4 (Loki) - Scatter Missiles: Tres misiles crucero con ojivas de racimo
handlers.Glenn4x4 = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	local startPos = ctx.MuzzlePos
	for _, ang in ipairs({ -0.25, 0, 0.25 }) do
		local dir = (ctx.AimDir + chassis.CFrame.RightVector * ang).Unit
		ctx.SpawnProjectile({
			Name = "ScatterMissile",
			Size = Vector3.new(1.0, 1.0, 3.4),
			Color = Color3.fromRGB(115, 225, 95),
			StartPos = startPos,
			Velocity = dir * 115,
			Lifetime = 4.5,
			BlastRadius = 18,
			Damage = 26,
			HomingTurnRate = 4.2,
			ShooterCar = ctx.ShooterCar,
			Character = ctx.Character,
			Attacker = ctx.Player,
		})
	end
end

-- 8. Palomino (Houston 3) - Super Fantastic Death Ray: Rayo láser concentrado
handlers.Palomino = function(ctx)
	raycastBeam(ctx, ctx.MuzzlePos, ctx.AimDir, 220, 65, Color3.fromRGB(255, 50, 50), 1.3, 0.35, 14)
end

-- 9. Leprechaun (Boogie) - Disco Inferno: Bola disco flotante que dispara rayos láser
handlers.Leprechaun = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	local ball = Instance.new("Part")
	ball.Name = "DiscoBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(4.2, 4.2, 4.2)
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 215, 90)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Position = chassis.Position + Vector3.new(0, 9.5, 0)
	ball.Parent = Workspace

	local discoColors = {
		Color3.fromRGB(255, 70, 190),
		Color3.fromRGB(70, 235, 255),
		Color3.fromRGB(120, 255, 90),
		Color3.fromRGB(255, 225, 65),
	}

	task.spawn(function()
		for i = 1, 8 do
			if not ball.Parent or not ctx.ShooterCar.Parent then
				break
			end
			local c = ctx.ShooterCar.PrimaryPart
			if c then
				ball.Position = c.Position + Vector3.new(0, 9.5, 0)
				ball.Color = discoColors[((i - 1) % #discoColors) + 1]
				local target = ctx.FindNearestEnemy(ctx.ShooterCar, ball.Position, c.CFrame.LookVector)
				if target and target.PrimaryPart then
					local dir = (target.PrimaryPart.Position - ball.Position).Unit
					raycastBeam(ctx, ball.Position, dir, 170, 9, ball.Color, 0.4, 0.14)
				end
			end
			task.wait(0.55)
		end
		if ball.Parent then
			ball:Destroy()
		end
	end)
end

-- 10. StagPickup (Beezwax) - Gamma Swarm: Enjambre de abejas radiactivas teledirigidas
handlers.StagPickup = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	local startPos = ctx.MuzzlePos
	for i = 1, 5 do
		local spread = (i - 3) * 0.2
		local dir = (ctx.AimDir + chassis.CFrame.RightVector * spread + Vector3.new(0, 0.15, 0)).Unit
		ctx.SpawnProjectile({
			Name = "GammaBee",
			Size = Vector3.new(0.9, 0.9, 1.4),
			Color = Color3.fromRGB(195, 255, 45),
			StartPos = startPos,
			Velocity = dir * 105,
			Lifetime = 5.0,
			BlastRadius = 9,
			Damage = 14,
			HomingTurnRate = 6.5,
			ShooterCar = ctx.ShooterCar,
			Character = ctx.Character,
			Attacker = ctx.Player,
		})
	end
end

-- 11. SchoolBus (Molo) - Smog Check: Nube tóxica que daña y desorienta
handlers.SchoolBus = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	local cloudPos = chassis.Position - chassis.CFrame.LookVector * 14

	local cloud = Instance.new("Part")
	cloud.Name = "SmogCloud"
	cloud.Shape = Enum.PartType.Ball
	cloud.Size = Vector3.new(26, 14, 26)
	cloud.Position = cloudPos
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.Material = Enum.Material.SmoothPlastic
	cloud.Color = Color3.fromRGB(105, 165, 65)
	cloud.Transparency = 0.55
	cloud.Parent = Workspace

	task.spawn(function()
		for _ = 1, 10 do
			if not cloud.Parent then
				break
			end
			local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
			if vehiclesFolder then
				for _, car in ipairs(vehiclesFolder:GetChildren()) do
					if car:IsA("Model") and car ~= ctx.ShooterCar and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
						if car.PrimaryPart and (car.PrimaryPart.Position - cloudPos).Magnitude <= 16 then
							ctx.ApplyDamage(car, 7, ctx.Player)
							car.PrimaryPart:ApplyAngularImpulse(Vector3.new(0, (math.random() - 0.5) * 4000, 0))
						end
					end
				end
			end
			task.wait(0.5)
		end
		if cloud.Parent then
			cloud:Destroy()
		end
	end)
end

-- 12. Manta (Sid Burn) - Scorcher: Lanzallamas frontal de corto alcance
handlers.Manta = function(ctx)
	task.spawn(function()
		for _ = 1, 8 do
			if not ctx.ShooterCar.Parent or not ctx.ShooterCar.PrimaryPart or ctx.ShooterCar:GetAttribute("Destroyed") then
				break
			end
			local c = ctx.ShooterCar.PrimaryPart
			local startPos = c.Position + Vector3.new(0, 2.2, 0) + c.CFrame.LookVector * 6
			local flame = Instance.new("Part")
			flame.Name = "ScorcherFlame"
			flame.Shape = Enum.PartType.Ball
			flame.Size = Vector3.new(6, 5, 10)
			flame.CFrame = CFrame.lookAt(startPos + c.CFrame.LookVector * 14, startPos + c.CFrame.LookVector * 30)
			flame.Anchored = true
			flame.CanCollide = false
			flame.CanQuery = false
			flame.Material = Enum.Material.Neon
			flame.Color = Color3.fromRGB(255, 115, 30)
			flame.Transparency = 0.35
			flame.Parent = Workspace
			Debris:AddItem(flame, 0.14)

			local vehiclesFolder = Workspace:FindFirstChild("ActiveVehicles")
			if vehiclesFolder then
				for _, car in ipairs(vehiclesFolder:GetChildren()) do
					if car:IsA("Model") and car ~= ctx.ShooterCar and car:GetAttribute("IsVehicle") and not car:GetAttribute("Destroyed") then
						if car.PrimaryPart then
							local offset = car.PrimaryPart.Position - c.Position
							if offset.Magnitude <= 45 and c.CFrame.LookVector:Dot(offset.Unit) > 0.6 then
								ctx.ApplyDamage(car, 8, ctx.Player)
							end
						end
					end
				end
			end
			task.wait(0.15)
		end
	end)
end

-- 13. LuxoSaucer (Y The Alien) - Cosmic Rays: Descarga alienígena de rayos cósmicos
handlers.LuxoSaucer = function(ctx)
	local chassis = ctx.ShooterCar.PrimaryPart :: BasePart
	local startPos = ctx.MuzzlePos
	local colors = {
		Color3.fromRGB(110, 255, 240),
		Color3.fromRGB(220, 100, 255),
		Color3.fromRGB(120, 255, 140),
		Color3.fromRGB(220, 100, 255),
		Color3.fromRGB(110, 255, 240),
	}
	for i, ang in ipairs({ -0.32, -0.16, 0, 0.16, 0.32 }) do
		local dir = (ctx.AimDir + chassis.CFrame.RightVector * ang).Unit
		raycastBeam(ctx, startPos, dir, 195, 18, colors[i], 0.55, 0.25)
	end
end

function SpecialWeapons.Fire(vehicleId: string, ctx: CombatContext): boolean
	local handler = handlers[vehicleId]
	if not handler then
		return false
	end
	handler(ctx)
	return true
end

return SpecialWeapons
