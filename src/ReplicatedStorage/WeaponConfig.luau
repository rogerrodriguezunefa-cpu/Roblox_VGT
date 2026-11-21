local WeaponConfig = {
	-- Armas Estándar
	["InterceptorMissiles"] = {
		DisplayName = "Interceptor Missiles",
		MountPoint = "LeftSideMount",
		MaxAmmo = 15,
		IsSpecial = false,
	},
	["BullsEyeRockets"] = {
		DisplayName = "Bull's Eye Rockets",
		MountPoint = "FrontMount",
		MaxAmmo = 12,
		IsSpecial = false,
	},
	["SkyHammerMortar"] = {
		DisplayName = "Sky Hammer Mortar",
		MountPoint = "RightSideMount",
		MaxAmmo = 10,
		IsSpecial = false,
	},
	["BruiserCannon"] = {
		DisplayName = "Bruiser Cannon",
		MountPoint = "RoofMount",
		MaxAmmo = 8,
		IsSpecial = false,
	},
	["RoadkillMines"] = {
		DisplayName = "Roadkill Mines",
		MountPoint = "RearMount",
		MaxAmmo = 8,
		IsSpecial = false,
	},

	-- Armas Especiales (Cajas Verdes)
	["Gridlock"] = {
		DisplayName = "Gridlock (Rattler)",
		MountPoint = "RoofMount",
		MaxAmmo = 8,
		IsSpecial = true,
	},
	["Invasion"] = {
		DisplayName = "Invasion (Van)",
		MountPoint = "RoofMount",
		MaxAmmo = 5,
		IsSpecial = true,
	},
	["GammaSwarm"] = {
		DisplayName = "Gamma Swarm (Stag Pickup)",
		MountPoint = "RightSideMount",
		MaxAmmo = 10,
		IsSpecial = true,
	},
}

return WeaponConfig
