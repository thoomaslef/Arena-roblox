-- Modèles d'armes low-poly (portage de scripts/fx/weapon_models.gd) : lance-roquettes et
-- Rail, construits pièce par pièce avec des Parts. Utilisés par la vue à la première
-- personne (Viewmodel, en petit devant la caméra) et dans la main des autres personnages
-- (CharacterAnimator, en taille réelle). Dimensions en MÈTRES, repère de l'arme :
-- -Z = vers l'avant (le canon), +Y en haut.

local WeaponModels = {}

-- Matériaux (couleurs de weapon_models.gd / view_arms.gd) ---------------------------------
local GUNMETAL = Color3.new(0.11, 0.12, 0.15)
local GUNMETAL_LIGHT = Color3.new(0.2, 0.21, 0.25)
local BLACK = Color3.new(0.03, 0.03, 0.04)
local GLOW = {
	rocket = Color3.new(1.0, 0.93, 0.82),
	rail = Color3.new(0.22, 0.91, 1.0),
}
local function rotDeg(x: number, y: number, z: number): CFrame
	return CFrame.fromEulerAnglesYXZ(math.rad(x), math.rad(y), math.rad(z))
end

-- Pièces d'une arme : { kind = "box"|"tube", size | (radius, length), pos, rot?, mat }.
-- mat : "dark", "light", "glow", "black". Les tubes sont orientés le long de Z.
local MODELS = {
	rocket = {
		-- Tube principal et renforts.
		{ kind = "tube", radius = 0.075, length = 0.78, pos = Vector3.new(0, 0, -0.04), mat = "dark" },
		{ kind = "tube", radius = 0.085, length = 0.16, pos = Vector3.new(0, 0, 0.12), mat = "light" },
		{ kind = "tube", radius = 0.082, length = 0.1, pos = Vector3.new(0, 0, -0.28), mat = "light" },
		-- Bouche évasée + anneau lumineux.
		{ kind = "tube", radius = 0.1025, length = 0.14, pos = Vector3.new(0, 0, -0.48), mat = "dark" },
		{ kind = "tube", radius = 0.092, length = 0.01, pos = Vector3.new(0, 0, -0.552), mat = "glow" },
		{ kind = "tube", radius = 0.068, length = 0.012, pos = Vector3.new(0, 0, -0.556), mat = "black" },
		-- Arrière : sortie des gaz.
		{ kind = "tube", radius = 0.095, length = 0.08, pos = Vector3.new(0, 0, 0.39), mat = "dark" },
		{ kind = "tube", radius = 0.07, length = 0.012, pos = Vector3.new(0, 0, 0.43), mat = "black" },
		-- Bandes lumineuses.
		{ kind = "tube", radius = 0.0865, length = 0.018, pos = Vector3.new(0, 0, 0.06), mat = "glow" },
		{ kind = "tube", radius = 0.0865, length = 0.018, pos = Vector3.new(0, 0, 0.18), mat = "glow" },
		{ kind = "tube", radius = 0.0835, length = 0.014, pos = Vector3.new(0, 0, -0.25), mat = "glow" },
		{ kind = "box", size = Vector3.new(0.012, 0.016, 0.36), pos = Vector3.new(0.076, 0.012, -0.08), mat = "glow" },
		{ kind = "box", size = Vector3.new(0.012, 0.016, 0.36), pos = Vector3.new(-0.076, 0.012, -0.08), mat = "glow" },
		-- Carter sous le tube.
		{ kind = "box", size = Vector3.new(0.1, 0.07, 0.34), pos = Vector3.new(0, -0.085, 0.04), mat = "light" },
		-- Poignée pistolet, pontet, poignée avant.
		{ kind = "box", size = Vector3.new(0.048, 0.17, 0.065), pos = Vector3.new(0, -0.19, 0.13), rot = rotDeg(-14, 0, 0), mat = "dark" },
		{ kind = "box", size = Vector3.new(0.04, 0.012, 0.09), pos = Vector3.new(0, -0.13, 0.06), mat = "dark" },
		{ kind = "box", size = Vector3.new(0.044, 0.13, 0.05), pos = Vector3.new(0, -0.17, -0.17), rot = rotDeg(8, 0, 0), mat = "dark" },
		-- Poignée de transport + viseur lumineux.
		{ kind = "box", size = Vector3.new(0.032, 0.075, 0.035), pos = Vector3.new(0, 0.105, 0.1), mat = "light" },
		{ kind = "box", size = Vector3.new(0.032, 0.075, 0.035), pos = Vector3.new(0, 0.105, -0.16), mat = "light" },
		{ kind = "box", size = Vector3.new(0.036, 0.03, 0.32), pos = Vector3.new(0, 0.15, -0.03), mat = "dark" },
		{ kind = "box", size = Vector3.new(0.05, 0.045, 0.06), pos = Vector3.new(0, 0.19, 0.06), mat = "light" },
		{ kind = "box", size = Vector3.new(0.03, 0.02, 0.006), pos = Vector3.new(0, 0.195, 0.028), mat = "glow" },
	},
	rail = {
		-- Corps central et crosse.
		{ kind = "box", size = Vector3.new(0.075, 0.095, 0.38), pos = Vector3.new(0, 0, 0.12), mat = "light" },
		{ kind = "box", size = Vector3.new(0.06, 0.11, 0.2), pos = Vector3.new(0, -0.03, 0.4), rot = rotDeg(-6, 0, 0), mat = "dark" },
		{ kind = "box", size = Vector3.new(0.064, 0.02, 0.16), pos = Vector3.new(0, 0.02, 0.4), rot = rotDeg(-6, 0, 0), mat = "glow" },
		-- Deux rails parallèles.
		{ kind = "box", size = Vector3.new(0.018, 0.05, 0.62), pos = Vector3.new(0.028, 0.005, -0.35), mat = "dark" },
		{ kind = "box", size = Vector3.new(0.006, 0.03, 0.6), pos = Vector3.new(0.019, 0.005, -0.35), mat = "glow" },
		{ kind = "box", size = Vector3.new(0.018, 0.05, 0.62), pos = Vector3.new(-0.028, 0.005, -0.35), mat = "dark" },
		{ kind = "box", size = Vector3.new(0.006, 0.03, 0.6), pos = Vector3.new(-0.019, 0.005, -0.35), mat = "glow" },
		-- Bobines autour des rails.
		{ kind = "tube", radius = 0.058, length = 0.013, pos = Vector3.new(0, 0.005, -0.12), mat = "glow" },
		{ kind = "tube", radius = 0.058, length = 0.013, pos = Vector3.new(0, 0.005, -0.27), mat = "glow" },
		{ kind = "tube", radius = 0.058, length = 0.013, pos = Vector3.new(0, 0.005, -0.42), mat = "glow" },
		{ kind = "tube", radius = 0.058, length = 0.013, pos = Vector3.new(0, 0.005, -0.57), mat = "glow" },
		{ kind = "box", size = Vector3.new(0.075, 0.07, 0.03), pos = Vector3.new(0, 0.005, -0.66), mat = "dark" },
		-- Poignée pistolet.
		{ kind = "box", size = Vector3.new(0.042, 0.15, 0.055), pos = Vector3.new(0, -0.12, 0.2), rot = rotDeg(-14, 0, 0), mat = "dark" },
		-- Lunette.
		{ kind = "box", size = Vector3.new(0.02, 0.04, 0.02), pos = Vector3.new(0, 0.07, 0.08), mat = "light" },
		{ kind = "box", size = Vector3.new(0.02, 0.04, 0.02), pos = Vector3.new(0, 0.07, -0.04), mat = "light" },
		{ kind = "tube", radius = 0.025, length = 0.22, pos = Vector3.new(0, 0.1, 0.02), mat = "dark" },
		{ kind = "tube", radius = 0.02, length = 0.005, pos = Vector3.new(0, 0.1, -0.092), mat = "glow" },
	},
}

WeaponModels.MODELS = MODELS

-- Points de prise des mains [droite (poignée arrière), gauche (avant)] dans le repère de l'arme.
WeaponModels.GRIPS = {
	rocket = { Vector3.new(0, -0.17, 0.12), Vector3.new(0, -0.15, -0.17) },
	rail = { Vector3.new(0, -0.1, 0.19), Vector3.new(0, -0.035, -0.2) },
}

-- Le cylindre Roblox s'allonge sur X : ce quart de tour le met le long de -Z.
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local function newPart(shape: Enum.PartType, color: Color3, neon: boolean, parent: Instance): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
WeaponModels.newPart = newPart
WeaponModels.ALONG_Z = ALONG_Z

export type Piece = { part: Part, local_: CFrame }

-- Construit l'arme `name` à l'échelle `k` (studs par mètre du modèle) dans `parent`.
-- Renvoie les pièces avec leur placement dans le repère de l'arme (studs).
function WeaponModels.build(name: string, k: number, parent: Instance): { Piece }
	local pieces = {}
	for _, d in MODELS[name] do
		local isGlow = d.mat == "glow"
		local color = if isGlow
			then GLOW[name]
			elseif d.mat == "light" then GUNMETAL_LIGHT
			elseif d.mat == "black" then BLACK
			else GUNMETAL
		local part
		local cf = CFrame.new(d.pos * k) * (d.rot or CFrame.identity)
		if d.kind == "tube" then
			part = newPart(Enum.PartType.Cylinder, color, isGlow, parent)
			part.Size = Vector3.new(d.length * k, d.radius * 2 * k, d.radius * 2 * k)
			cf *= ALONG_Z
		else
			part = newPart(Enum.PartType.Block, color, isGlow, parent)
			part.Size = d.size * k
		end
		table.insert(pieces, { part = part, local_ = cf })
	end
	return pieces
end

-- Affiche ou cache une arme construite.
function WeaponModels.setVisible(pieces: { Piece }, visible: boolean)
	for _, piece in pieces do
		piece.part.Transparency = if visible then 0 else 1
	end
end

return WeaponModels
