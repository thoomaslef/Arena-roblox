--!strict
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
	MOUSE_SENS = 0.0035, -- radians par pixel (multiplié par la sensibilité Roblox du joueur)
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
}

Config.Rail = {
	CHARGES = 1,
	RELOAD = 2.5,
	RANGE = 220.0,
	ROCKET_DESTROY_DIST = 0.55,
	ZOOM_FACTOR = 0.45,
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
}

Config.Teams = {
	[0] = { name = "Flics", color = Color3.fromHex("#3B7AFF") },
	[1] = { name = "Bandits", color = Color3.fromHex("#FF8A29") },
}

-- Groupes de collision ---------------------------------------------------------------
Config.Groups = {
	BODY = "CavaleBody", -- parties visibles de l'avatar : ne touchent rien
	COLLIDER = "CavaleCollider", -- cylindre invisible du joueur : touche la map, pas les autres joueurs
}

return Config
