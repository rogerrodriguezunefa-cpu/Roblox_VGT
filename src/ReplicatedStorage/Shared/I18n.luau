local LocalizationService = game:GetService("LocalizationService")

local I18n = {}

local locale = LocalizationService.RobloxLocaleId or "en-us"
I18n.Lang = if string.sub(string.lower(locale), 1, 2) == "es" then "es" else "en"

local STRINGS: { [string]: { en: string, es: string } } = {
	GARAGE_BTN = { en = "Garage [M]", es = "Garaje [M]" },
	MAPS_BTN = { en = "Maps [N]", es = "Mapas [N]" },
	CHOOSE_VEHICLE = { en = "SELECT YOUR VEHICLE (13)", es = "ELIGE TU VEHÍCULO (13)" },
	CHOOSE_ARENA = { en = "SELECT COMBAT ARENA (10)", es = "ELIGE LA ARENA DE COMBATE (10)" },
	STAT_SPEED = { en = "Speed", es = "Velocidad" },
	STAT_ARMOR = { en = "Armor", es = "Resistencia" },
	STAT_SPECIAL = { en = "Spec. Dmg", es = "Daño Esp." },
	KILLS = { en = "KILLS", es = "BAJAS" },
	DEATHS = { en = "DEATHS", es = "MUERTES" },
	DAMAGE = { en = "DMG", es = "DAÑO" },
	NEW_ROUND = { en = "NEXT ROUND IN %ds", es = "NUEVA RONDA EN %ds" },
	EMPTY_SLOT = { en = "EMPTY", es = "---" },
	GREEN_CRATE = { en = "Green Crate", es = "Caja Verde" },
	CONTROLS_HINT = {
		en = "1-3: Weapon | Q: Fire | X: Special | R: Flip",
		es = "1-3: Arma | Q: Disparar | X: Especial | R: Enderezar",
	},
	KILLED_MSG = { en = "%s wrecked %s!", es = "¡%s destruyó a %s!" },
	DESC_Rattler = { en = "Freezes enemy with energy.", es = "Inmoviliza al rival con energía." },
	DESC_Clydesdale = { en = "Long-range electric bolt.", es = "Rayo eléctrico de largo alcance." },
	DESC_Strider = { en = "Ultra-fast heavy machine gun.", es = "Ametralladora pesada ultra rápida." },
	DESC_Jefferson = { en = "Sonic shockwave around car.", es = "Onda sónica expansiva alrededor." },
	DESC_Van = { en = "Summons laser-firing UFOs.", es = "Invoca platillos voladores con láser." },
	DESC_MothTruck = { en = "Bouncing explosive tires.", es = "Neumáticos explosivos que rebotan." },
	DESC_Glenn4x4 = { en = "Triple cluster cruise missiles.", es = "Tres misiles crucero de racimo." },
	DESC_Palomino = { en = "Concentrated lethal laser.", es = "Rayo láser concentrado letal." },
	DESC_Leprechaun = { en = "Floating laser disco ball.", es = "Bola disco que dispara rayos láser." },
	DESC_StagPickup = { en = "Homing radioactive bee swarm.", es = "Enjambre de abejas radiactivas." },
	DESC_SchoolBus = { en = "Toxic cloud damages & spins.", es = "Nube tóxica que daña y desorienta." },
	DESC_Manta = { en = "Front short-range flamethrower.", es = "Lanzallamas frontal de corto alcance." },
	DESC_LuxoSaucer = { en = "Alien cosmic ray spread.", es = "Descarga alienígena de rayos cósmicos." },
	ARENA_SkiResort = { en = "Snow & ramps. Shoot 3 pines for avalanche.", es = "Nieve y rampas. Dispara a 3 pinos para avalancha." },
	ARENA_ValleyFarms = { en = "Farms, red barn, silos & breakables.", es = "Granja con graneros, silos y destructibles." },
	ARENA_AircraftGraveyard = { en = "Plane boneyard; use wings as ramps.", es = "Cementerio de aviones; usa alas como rampas." },
	ARENA_Canyonlands = { en = "Canyons, bridge & stone teleporter.", es = "Cañones, puente y círculo teletransportador." },
	ARENA_OilFields = { en = "Refinery with chain-exploding oil tanks.", es = "Refinería con tanques inflamables en cadena." },
	ARENA_CasinoCity = { en = "Nighttime Vegas strip & neon signs.", es = "Ciudad nocturna estilo Las Vegas y neón." },
	ARENA_GhostTown = { en = "Western town with active train & tornado.", es = "Pueblo oeste con locomotora activa y tornado." },
	ARENA_HooverDam = { en = "Dam & water; shoot switch to electrify.", es = "Presa; dispara al interruptor para electrificar." },
	ARENA_SandFactory = { en = "Sand plant; shoot post to lower elevator.", es = "Planta industrial; dispara al poste del ascensor." },
	ARENA_SecretBase = { en = "Area 51 hangar, UFO & boost pads.", es = "Base Área 51 con platillo y propulsores." },
}

function I18n.T(key: string): string
	local entry = STRINGS[key]
	if not entry then
		return key
	end
	return entry[I18n.Lang] or entry.en
end

function I18n.Toggle()
	I18n.Lang = if I18n.Lang == "en" then "es" else "en"
end

return I18n
