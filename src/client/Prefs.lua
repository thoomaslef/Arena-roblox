-- Préférences de jeu du joueur (onglet JEU du menu Réglages), sauvegardées avec les touches.
--   volume        0..1,5  (× volume général des bruitages)
--   fov           champ de vision HORIZONTAL en degrés (80..110)
--   crosshair     "cross", "dot", "circle", "crossdot"
--   crosshairColor "white", "green", "yellow", "cyan", "pink"
--   language      "auto", "fr", "en"
--   sensTouch / sensPad : multiplicateurs de sensibilité (tactile, manette)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Lang = require(ReplicatedStorage.Shared:WaitForChild("Lang"))

local Prefs = {
	volume = 1.0,
	fov = Config.Camera.HFOV,
	crosshair = "cross",
	crosshairColor = "white",
	language = "auto",
	sensTouch = 1.0,
	sensPad = 1.0,
}

Prefs.CROSSHAIRS = { "cross", "dot", "circle", "crossdot" }
Prefs.COLORS = { "white", "green", "yellow", "cyan", "pink" }
Prefs.COLOR_VALUES = {
	white = Color3.new(1, 1, 1),
	green = Color3.fromRGB(90, 255, 120),
	yellow = Color3.fromRGB(255, 230, 80),
	cyan = Color3.fromRGB(60, 230, 255),
	pink = Color3.fromRGB(255, 110, 200),
}
Prefs.LIMITS = {
	volume = { 0, 1.5 },
	fov = { 80, 110 },
	sensTouch = { 0.2, 3 },
	sensPad = { 0.2, 3 },
}

local changed = Instance.new("BindableEvent")
Prefs.changed = changed.Event

local function has(list, v): boolean
	for _, x in list do
		if x == v then
			return true
		end
	end
	return false
end

function Prefs.notify()
	Lang.set(Prefs.language)
	changed:Fire()
end

function Prefs.set(key: string, value: any)
	local lim = Prefs.LIMITS[key]
	if lim and type(value) == "number" then
		value = math.clamp(math.floor(value * 100 + 0.5) / 100, lim[1], lim[2])
	end
	Prefs[key] = value
	Prefs.notify()
end

-- Applique des préférences sauvegardées (tolère les données incomplètes ou anciennes).
function Prefs.load(data: any)
	if type(data) ~= "table" then
		return
	end
	for key, lim in Prefs.LIMITS do
		if type(data[key]) == "number" and data[key] == data[key] then
			Prefs[key] = math.clamp(data[key], lim[1], lim[2])
		end
	end
	if has(Prefs.CROSSHAIRS, data.crosshair) then
		Prefs.crosshair = data.crosshair
	end
	if has(Prefs.COLORS, data.crosshairColor) then
		Prefs.crosshairColor = data.crosshairColor
	end
	if has(Lang.LANGUAGES, data.language) then
		Prefs.language = data.language
	end
	Prefs.notify()
end

function Prefs.save(): any
	return {
		volume = Prefs.volume,
		fov = Prefs.fov,
		crosshair = Prefs.crosshair,
		crosshairColor = Prefs.crosshairColor,
		language = Prefs.language,
		sensTouch = Prefs.sensTouch,
		sensPad = Prefs.sensPad,
	}
end

return Prefs
