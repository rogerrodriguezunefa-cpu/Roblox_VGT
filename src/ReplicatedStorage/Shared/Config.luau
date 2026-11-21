local Config = {}

-- Configuración general de la arena de pruebas
Config.ARENA_SIZE = 1200 -- Tamaño del cuadrado de la arena (studs) para 2-5 jugadores
Config.WALL_HEIGHT = 28

-- Configuración del vehículo arcade (estilo Vigilante 8)
Config.VEHICLE = {
	SCALE = 1.35,            -- Escala 3D del vehículo (permite ver al piloto dentro de la cabina)
	MAX_SPEED = 65,          -- Velocidad angular máxima de las ruedas (rad/s)
	TORQUE = 500000,         -- Fuerza del motor para acelerar rápido y subir rampas
	STEER_ANGLE = 28,        -- Ángulo máximo de giro a baja velocidad (grados)
	STEER_SPEED = 22,        -- Qué tan rápido responde el volante
	TURBO_MULTIPLIER = 1.65, -- Multiplicador de velocidad al usar Turbo
	TURBO_FORCE = 18000,     -- Empuje extra del turbo
	TURBO_MAX = 100,         -- Energía máxima de turbo
	TURBO_DRAIN = 35,        -- Consumo por segundo
	TURBO_REGEN = 18,        -- Recarga por segundo cuando no se usa
	MAX_HEALTH = 100,        -- Vida base del vehículo
}

-- Configuración de Combate (Fase 2)
Config.COMBAT = {
	MG_DAMAGE = 10,          -- Daño por bala de la ametralladora
	MG_FIRE_RATE = 0.12,     -- Segundos entre disparos (~8 disparos/seg)
	MG_RANGE = 220,          -- Alcance máximo en studs
	MG_SPREAD = 0.02,        -- Dispersión ligera estilo arcade
	RESPAWN_DELAY = 3.5,     -- Segundos para reaparecer tras explotar
}

-- Configuración de Armas Especiales y Pickups (Fase 3 / Estilo Vigilante 8 PS1)
Config.WEAPONS = {
	PICKUP_RESPAWN = 12,     -- Segundos para reaparecer un pickup recogido
	REPAIR_AMOUNT = 45,      -- Vida recuperada por llave inglesa
	MAX_SLOTS = 3,           -- Hasta 3 armas recolectables equipadas a la vez
	CATALOG = {
		Interceptor = {
			Id = "Interceptor",
			Name = "Interceptor Missiles",
			ShortName = "MISILES",
			Ammo = 6,
			ComboCost = 3,
			Damage = 38,
			Speed = 120,
			TurnRate = 5.5,
			Lifetime = 5.0,
			Color = Color3.fromRGB(255, 95, 55),
		},
		Rockets = {
			Id = "Rockets",
			Name = "Bull's Eye Rockets",
			ShortName = "COHETES",
			Ammo = 8,
			ComboCost = 3,
			Damage = 42,
			Speed = 195,
			Lifetime = 3.0,
			Color = Color3.fromRGB(255, 145, 40),
		},
		Mortar = {
			Id = "Mortar",
			Name = "Sky Hammer Mortar",
			ShortName = "MORTERO",
			Ammo = 6,
			ComboCost = 2,
			Damage = 52,
			Speed = 95,
			ArcUp = 58,
			Gravity = 110,
			Lifetime = 4.5,
			Color = Color3.fromRGB(165, 110, 255),
		},
		Cannon = {
			Id = "Cannon",
			Name = "Bruiser Cannon",
			ShortName = "CAÑÓN",
			Ammo = 6,
			ComboCost = 2,
			Damage = 58,
			Speed = 155,
			Knockback = 16000,
			Lifetime = 3.0,
			Color = Color3.fromRGB(70, 200, 255),
		},
		Mines = {
			Id = "Mines",
			Name = "Roadkill Mines",
			ShortName = "MINAS",
			Ammo = 5,
			ComboCost = 3,
			Damage = 55,
			Radius = 11,
			ArmDelay = 0.8,
			Lifetime = 25,
			Color = Color3.fromRGB(255, 205, 45),
		},
	},
}

-- Catálogo de los 13 vehículos y armas especiales exclusivas de Vigilante 8 (PS1)
Config.VEHICLE_ORDER = {
	"Rattler",
	"Clydesdale",
	"Strider",
	"Jefferson",
	"Van",
	"MothTruck",
	"Glenn4x4",
	"Palomino",
	"Leprechaun",
	"StagPickup",
	"SchoolBus",
	"Manta",
	"LuxoSaucer",
}

Config.VEHICLE_TYPES = {
	Rattler = {
		Id = "Rattler",
		Enabled = true,
		Character = "Chassey Blue",
		DisplayName = "Rattler",
		SpecialName = "Gridlock",
		Description = "Inmoviliza al rival con energía.",
		Color = Color3.fromRGB(28, 45, 82),
		BodyStyle = "Muscle",
		MaxHealth = 100,
		MaxSpeed = 72,
		SteerAngle = 28,
		SpecialPower = 60,
	},
	Clydesdale = {
		Id = "Clydesdale",
		Enabled = true,
		Character = "Slick Clyde",
		DisplayName = "Clydesdale",
		SpecialName = "Lightning Bolt",
		Description = "Rayo eléctrico de largo alcance.",
		Color = Color3.fromRGB(105, 62, 42),
		BodyStyle = "Pickup",
		MaxHealth = 115,
		MaxSpeed = 66,
		SteerAngle = 27,
		SpecialPower = 75,
		Scale = 1.42,
	},
	Strider = {
		Id = "Strider",
		Enabled = true,
		Character = "Sheila",
		DisplayName = "Strider",
		SpecialName = "Tantrum Gun",
		Description = "Ametralladora pesada ultra rápida.",
		Color = Color3.fromRGB(205, 42, 38),
		BodyStyle = "Buggy",
		MaxHealth = 85,
		MaxSpeed = 82,
		SteerAngle = 31,
		SpecialPower = 85,
		Scale = 1.22,
	},
	Jefferson = {
		Id = "Jefferson",
		Enabled = true,
		Character = "John Torque",
		DisplayName = "Jefferson",
		SpecialName = "Bass Quake",
		Description = "Onda sónica expansiva alrededor.",
		Color = Color3.fromRGB(35, 55, 95),
		BodyStyle = "Muscle",
		MaxHealth = 105,
		MaxSpeed = 70,
		SteerAngle = 28,
		SpecialPower = 72,
	},
	Van = {
		Id = "Van",
		Enabled = true,
		Character = "Dave",
		DisplayName = "Van",
		SpecialName = "Invasion",
		Description = "Invoca platillos voladores con láser.",
		Color = Color3.fromRGB(105, 62, 42),
		BodyStyle = "Van",
		MaxHealth = 120,
		MaxSpeed = 62,
		SteerAngle = 26,
		SpecialPower = 78,
		Scale = 1.48,
	},
	MothTruck = {
		Id = "MothTruck",
		Enabled = true,
		Character = "Convoy",
		DisplayName = "Moth Truck",
		SpecialName = "Steel Belted",
		Description = "Neumáticos explosivos que rebotan.",
		Color = Color3.fromRGB(215, 115, 42),
		BodyStyle = "Truck",
		MaxHealth = 155,
		MaxSpeed = 54,
		SteerAngle = 24,
		SpecialPower = 82,
		Scale = 1.60,
	},
	Glenn4x4 = {
		Id = "Glenn4x4",
		Enabled = true,
		Character = "Loki",
		DisplayName = "Glenn 4x4",
		SpecialName = "Scatter Missiles",
		Description = "Tres misiles crucero de racimo.",
		Color = Color3.fromRGB(92, 110, 68),
		BodyStyle = "Pickup",
		MaxHealth = 125,
		MaxSpeed = 64,
		SteerAngle = 27,
		SpecialPower = 84,
		Scale = 1.42,
	},
	Palomino = {
		Id = "Palomino",
		Enabled = true,
		Character = "Houston 3",
		DisplayName = "Palomino",
		SpecialName = "Super Death Ray",
		Description = "Rayo láser concentrado letal.",
		Color = Color3.fromRGB(155, 32, 38),
		BodyStyle = "Muscle",
		MaxHealth = 100,
		MaxSpeed = 74,
		SteerAngle = 29,
		SpecialPower = 95,
	},
	Leprechaun = {
		Id = "Leprechaun",
		Enabled = true,
		Character = "Boogie",
		DisplayName = "Leprechaun",
		SpecialName = "Disco Inferno",
		Description = "Bola disco que dispara rayos láser.",
		Color = Color3.fromRGB(130, 195, 55),
		BodyStyle = "Buggy",
		MaxHealth = 95,
		MaxSpeed = 76,
		SteerAngle = 30,
		SpecialPower = 80,
		Scale = 1.24,
	},
	StagPickup = {
		Id = "StagPickup",
		Enabled = true,
		Character = "Beezwax",
		DisplayName = "Stag Pickup",
		SpecialName = "Gamma Swarm",
		Description = "Enjambre de abejas radiactivas.",
		Color = Color3.fromRGB(38, 128, 68),
		BodyStyle = "Pickup",
		MaxHealth = 120,
		MaxSpeed = 65,
		SteerAngle = 26,
		SpecialPower = 76,
		Scale = 1.42,
	},
	SchoolBus = {
		Id = "SchoolBus",
		Enabled = true,
		Character = "Molo",
		DisplayName = "School Bus",
		SpecialName = "Smog Check",
		Description = "Nube tóxica que daña y desorienta.",
		Color = Color3.fromRGB(245, 190, 30),
		BodyStyle = "Bus",
		MaxHealth = 165,
		MaxSpeed = 52,
		SteerAngle = 23,
		SpecialPower = 74,
		Scale = 1.68,
	},
	Manta = {
		Id = "Manta",
		Enabled = true,
		Character = "Sid Burn",
		DisplayName = "Manta",
		SpecialName = "Scorcher",
		Description = "Lanzallamas frontal de corto alcance.",
		Color = Color3.fromRGB(240, 105, 30),
		BodyStyle = "Muscle",
		MaxHealth = 95,
		MaxSpeed = 78,
		SteerAngle = 30,
		SpecialPower = 78,
	},
	LuxoSaucer = {
		Id = "LuxoSaucer",
		Enabled = true,
		Character = "Y The Alien",
		DisplayName = "Luxo Saucer",
		SpecialName = "Cosmic Rays",
		Description = "Descarga alienígena de rayos cósmicos.",
		Color = Color3.fromRGB(172, 176, 182),
		BodyStyle = "Saucer",
		MaxHealth = 90,
		MaxSpeed = 84,
		SteerAngle = 32,
		SpecialPower = 92,
	},
}

-- Catálogo de las 10 Arenas de Vigilante 8 (PS1): 8 iniciales + 2 desbloqueables
Config.ARENA_ORDER = {
	"SkiResort",
	"ValleyFarms",
	"AircraftGraveyard",
	"Canyonlands",
	"OilFields",
	"CasinoCity",
	"GhostTown",
	"HooverDam",
	"SandFactory",
	"SecretBase",
}

Config.ARENAS = {
	SkiResort = {
		Id = "SkiResort",
		DisplayName = "Ski Resort",
		Location = "Colorado",
		Description = "Nieve y rampas. Dispara a 3 pinos para provocar una avalancha.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(235, 242, 250),
		FloorMaterial = Enum.Material.Snow,
		WallColor = Color3.fromRGB(165, 185, 205),
		ClockTime = 13,
	},
	ValleyFarms = {
		Id = "ValleyFarms",
		DisplayName = "Valley Farms",
		Location = "California",
		Description = "Granja con graneros, silos y estructuras destructibles.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(125, 155, 78),
		FloorMaterial = Enum.Material.Grass,
		WallColor = Color3.fromRGB(120, 90, 60),
		ClockTime = 14,
	},
	AircraftGraveyard = {
		Id = "AircraftGraveyard",
		DisplayName = "Aircraft Graveyard",
		Location = "Arizona",
		Description = "Cementerio de aviones; usa alas y fuselajes como rampas.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(194, 158, 108),
		FloorMaterial = Enum.Material.Sand,
		WallColor = Color3.fromRGB(130, 100, 75),
		ClockTime = 15,
	},
	Canyonlands = {
		Id = "Canyonlands",
		DisplayName = "Canyonlands",
		Location = "Utah",
		Description = "Cañones, puente central y círculo de piedra teletransportador.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(185, 105, 68),
		FloorMaterial = Enum.Material.Rock,
		WallColor = Color3.fromRGB(140, 72, 48),
		ClockTime = 16,
	},
	OilFields = {
		Id = "OilFields",
		DisplayName = "Oil Fields",
		Location = "Nuevo México",
		Description = "Refinería con torres y tanques inflamables en cadena.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(145, 125, 100),
		FloorMaterial = Enum.Material.Ground,
		WallColor = Color3.fromRGB(80, 75, 72),
		ClockTime = 14,
	},
	CasinoCity = {
		Id = "CasinoCity",
		DisplayName = "Casino City",
		Location = "Nevada",
		Description = "Ciudad nocturna estilo Las Vegas con letreros de neón.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(48, 50, 58),
		FloorMaterial = Enum.Material.Asphalt,
		WallColor = Color3.fromRGB(35, 32, 48),
		ClockTime = 0,
	},
	GhostTown = {
		Id = "GhostTown",
		DisplayName = "Ghost Town",
		Location = "Nuevo México",
		Description = "Pueblo fantasma con locomotora activa y tornado.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(182, 146, 98),
		FloorMaterial = Enum.Material.Sand,
		WallColor = Color3.fromRGB(115, 86, 62),
		ClockTime = 17,
	},
	HooverDam = {
		Id = "HooverDam",
		DisplayName = "Hoover Dam",
		Location = "Arizona - Nevada",
		Description = "Presa hidroeléctrica; dispara al interruptor para electrificar el agua.",
		Unlockable = false,
		FloorColor = Color3.fromRGB(150, 152, 156),
		FloorMaterial = Enum.Material.Concrete,
		WallColor = Color3.fromRGB(110, 112, 118),
		ClockTime = 13,
	},
	SandFactory = {
		Id = "SandFactory",
		DisplayName = "Sand Factory",
		Location = "Utah (Extra)",
		Description = "Planta industrial; dispara al poste para bajar el ascensor.",
		Unlockable = true,
		FloorColor = Color3.fromRGB(198, 174, 125),
		FloorMaterial = Enum.Material.Sand,
		WallColor = Color3.fromRGB(105, 98, 88),
		ClockTime = 14,
	},
	SecretBase = {
		Id = "SecretBase",
		DisplayName = "Secret Base",
		Location = "Nevada (Extra)",
		Description = "Base subterránea Área 51 con naves alienígenas y propulsores.",
		Unlockable = true,
		FloorColor = Color3.fromRGB(58, 62, 72),
		FloorMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(40, 44, 52),
		ClockTime = 2,
	},
}

-- Configuración de Partida y Rondas (Fase 5)
Config.MATCH = {
	ROUND_DURATION = 180, -- 3 minutos por ronda
	INTERMISSION = 8,     -- Segundos entre rondas
}

-- Configuración de Bots simples (para probar solo mientras desarrollamos)
Config.BOTS_ENABLED = true
Config.BOT_COUNT = 3
Config.BOT_SPEED = 45
Config.BOT_RESPAWN_DELAY = 4

return Config
