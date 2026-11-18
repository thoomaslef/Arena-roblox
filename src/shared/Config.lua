-- Toutes les constantes du jeu, reprises du jeu Godot (scripts/player/fighter.gd,
-- scripts/weapons/weapons.gd, scripts/modes/joust.gd).
-- Unités : MÈTRES et SECONDES. La conversion en studs se fait au dernier moment
-- avec STUDS_PER_METER (1 m = 3 studs : un joueur de 1,8 m mesure ~5,4 studs,
-- la taille d'un avatar Roblox).

local Config = {}

Config.STUDS_PER_METER = 3

-- Déplacements --------------------------------------------------------------
Config.Move = {
	RUN_SPEED = 8.5,
	SPRINT_SPEED = 13.5,
	WALK_SPEED = 4.2,
	GROUND_ACCEL = 70.0,
	GROUND_FRICTION = 55.0,
	OVERSPEED_DECEL = 11.0,
	AIR_ACCEL = 15.0,
	GRAVITY = 22.0,
	JUMP_MIN_VY = 2.6, -- micro-saut
	JUMP_FULL_VY = 7.6, -- saut complet (bouton tenu)
	JUMP_BOOST_TIME = 0.18,
	RISE_HOLD_GRAVITY = 0.72,
	GLIDE_GRAVITY = 0.5,
	GLIDE_MAX_FALL = 4.5,
	WALLJUMP_PUSH = 7.5,
	WALLJUMP_VY = 7.0,
	WALLJUMP_DELAY = 0.22,
	WALLJUMP_KEEP = 0.75, -- part de la vitesse gardée le long du mur
	PAD_VY = 17.0,
	ACCEL_SPEED = 24.0,
	ACCEL_VY = 3.5,
	PRESS_BUFFER = 0.18,
	COYOTE = 0.1,
	KILL_Y = -20.0,
}

Config.Stamina = {
	MAX = 1.0,
	COST_JUMP = 0.12,
	COST_WALLJUMP = 0.16,
	DRAIN_SPRINT = 0.42,
	DRAIN_GLIDE = 0.38,
	REGEN = 0.33,
	REGEN_DELAY = 0.45,
}

Config.Body = {
	HEIGHT = 1.8,
	RADIUS = 0.4,
	EYE_HEIGHT = 1.6,
	STEP_HEIGHT = 0.35, -- accroche au sol / hauteur de marche franchie sans sauter
	MAX_SLOPE_DEG = 50,
}

-- Caméra ----------------------------------------------------------------------
Config.Camera = {
	HFOV = 95, -- champ de vision HORIZONTAL (comme dans Godot, KEEP_WIDTH)
	MOUSE_SENS = 0.0035, -- radians par pixel de mouvement brut (× sensibilité du menu Réglages)
	GAMEPAD_SENS = 4.0, -- radians par seconde, stick à fond
	TOUCH_SENS = 0.006, -- radians par pixel glissé
	MAX_PITCH_DEG = 89,
}

-- Armes (étapes suivantes) ------------------------------------------------------
Config.Rocket = {
	CHARGES = 5,
	RELOAD = 2.0, -- par roquette, en continu
	MIN_INTERVAL = 0.26,
	SPEED = 36.0,
	HIT_RADIUS = 1.4,
	PUSH_RADIUS = 3.4,
	PUSH_FORCE = 11.0, -- × (0,35 + 0,65 × proximité)
	PUSH_UP = 0.35,
	LIFETIME = 5.0,
	MUZZLE_FORWARD = 0.5,
	START_EMPTY = true, -- début de manche : aucune roquette chargée, la recharge démarre au GO
	KNOCK_TIME = 0.2, -- juste après une poussée, le sol ne freine pas
	KNOCK_MIN_VY = 3.5, -- une poussée au sol décolle au moins à cette vitesse
	-- Tolérances du serveur (anti-triche) : le réseau décale un peu les horloges.
	SERVER_MIN_CHARGE = 0.9,
	SERVER_MIN_INTERVAL = 0.2,
	SERVER_EYE_TOLERANCE = 6.0, -- m entre l'œil annoncé par le client et celui vu par le serveur
	SHAKE_STRENGTH = 0.45,
	SHAKE_REACH = 14.0,
}

Config.Rail = {
	CHARGES = 1,
	RELOAD = 2.5,
	RANGE = 220.0,
	COOLDOWN = 0.35,
	DAMAGE = 1, -- en 1v1 : 1 vie
	ROCKET_DESTROY_DIST = 0.55,
	ZOOM_FACTOR = 0.45,
	BEAM_COLOR = Color3.new(0.22, 0.91, 1.0),
	BEAM_TIME = 0.35,
	-- Tolérances du serveur.
	SERVER_MIN_INTERVAL = 0.3,
	SERVER_RAIL_MEMORY = 5.0, -- s : on garde le Rail tant qu'on n'a pas reposé le pied ailleurs (le serveur tolère 5 s)
	SERVER_HIT_TOLERANCE = 2.2, -- m : écart permis entre la touche vue par le tireur et la cible côté serveur
	SERVER_ROCKET_LAG = 0.25, -- s : on teste aussi où la roquette était il y a si peu
}

-- Règles du 1v1 « Règlement de comptes » ------------------------------------------
Config.Joust = {
	LIVES = 3,
	WIN_SCORE = 11,
	WIN_GAP = 2,
	COUNTDOWN = 3.0,
	ROUND_END_PAUSE = 3.0,
	GAS_STEPS = { { 5, 1.0 }, { 15, 0.66 }, { 8, 0.66 }, { 15, 0.38 }, { 8, 0.38 }, { 15, 0.12 } },
	GAS_MIN_RADIUS = 4.0,
	GAS_WARN_DIST = 4.0,
	GAS_COLOR = Color3.fromHex("#B8FF2E"),
	GAS_WALL_EXTRA = 14.0, -- hauteur du mur de gaz au-dessus du plus haut bloc (m)
	TIE_GRACE = 0.15, -- deux morts à moins de 0,15 s d'écart = égalité
	MATCH_END_PAUSE = 12.0, -- écran de fin de match (et vote de map) avant le match suivant
}

-- Matchmaking ------------------------------------------------------------------------
-- Serveurs de 2 places (réglage Max Players = 2 dans Studio, voir README). Seul trop
-- longtemps : un bot prend la place de l'adversaire, et la rend dès qu'un joueur arrive.
Config.Match = {
	BOT_ENABLED = true,
	BOT_WAIT = 15, -- s d'attente seul avant l'arrivée du bot
	BOT_SKILL = 2, -- 1 facile, 2 moyen, 3 difficile (niveaux du bot Godot)
	-- Maps 1v1 (fichiers de src/shared/Maps) : une au hasard à chaque nouveau match,
	-- jamais deux fois la même d'affilée. RANDOM_MAP = false : toujours la première.
	MAPS = { "cratere", "piliers", "terrasses", "fosse", "passerelles" },
	RANDOM_MAP = true,
	MAP_VOTE = true, -- vote pour la prochaine map pendant l'écran de fin de match
}

-- Progression (XP, niveaux) et classement -------------------------------------------------
Config.Progress = {
	XP_MATCH_PLAYED = 40,
	XP_MATCH_WON = 60,
	XP_ROUND_WON = 15,
	XP_HIT = 5, -- par touche sur l'adversaire
	XP_KILL = 10, -- en plus, pour la touche qui gagne la manche
	XP_DETONATE = 10, -- roquette détruite au Rail
	VS_BOT_MULT = 0.5, -- contre le bot, l'XP est réduite de moitié
	-- XP pour passer du niveau n au niveau n+1 : BASE + STEP × (n - 1).
	LEVEL_BASE = 100,
	LEVEL_STEP = 50,
}

Config.Ranked = {
	SEASON = 1, -- changer ce numéro lance une nouvelle saison (classement remis à zéro, en douceur)
	START_RATING = 1000,
	K = 32, -- vitesse de variation des points (Elo)
	PLACEMENT_GAMES = 3, -- matchs contre des joueurs avant d'avoir un rang
	SEASON_CARRY = 0.5, -- nouvelle saison : on garde la moitié de l'écart à 1000
	LEADERBOARD_SIZE = 10,
	-- Rangs selon les points (seuil minimal).
	TIERS = {
		{ 0, "bronze", Color3.fromRGB(205, 127, 50) },
		{ 900, "silver", Color3.fromRGB(200, 205, 215) },
		{ 1100, "gold", Color3.fromRGB(255, 205, 60) },
		{ 1300, "platinum", Color3.fromRGB(90, 220, 200) },
		{ 1500, "diamond", Color3.fromRGB(110, 170, 255) },
		{ 1700, "champion", Color3.fromRGB(255, 90, 140) },
	},
}

-- Rang (clé Lang « rank.… » et couleur) pour un nombre de points.
function Config.rankFor(rating: number): (string, Color3)
	local key, color = "bronze", Config.Ranked.TIERS[1][3]
	for _, t in Config.Ranked.TIERS do
		if rating >= t[1] then
			key, color = t[2], t[3]
		end
	end
	return key, color
end

-- XP nécessaire pour passer du niveau `level` au suivant.
function Config.xpForLevel(level: number): number
	return Config.Progress.LEVEL_BASE + Config.Progress.LEVEL_STEP * (level - 1)
end

Config.Teams = {
	[0] = { name = "Flics", color = Color3.fromHex("#3B7AFF") },
	[1] = { name = "Bandits", color = Color3.fromHex("#FF8A29") },
}

-- Sons ---------------------------------------------------------------------------------
-- Les sons du jeu Godot sont regroupés dans UNE planche : assets/sfx/cavale_sfx.ogg
-- (générée par tools/make_sfx.py). Mets-la en ligne sur Roblox (voir README) et colle son
-- ID ici, par ex. "rbxassetid://123456789". Vide : quelques sons intégrés à Roblox à la place.
Config.Audio = {
	SFX_ID = "",
	VOLUME = 0.7, -- volume général des bruitages
}

-- Groupes de collision ---------------------------------------------------------------
Config.Groups = {
	BODY = "CavaleBody", -- parties visibles de l'avatar : ne touchent rien
	COLLIDER = "CavaleCollider", -- cylindre invisible du joueur : touche la map, pas les autres joueurs
}

return Config
