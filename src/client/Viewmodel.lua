-- Vue à la première personne : l'arme en main et les bras, devant la caméra.
-- Portage de arena.gd (_build_viewmodel, _update_viewmodel), weapon_models.gd
-- (rocket_launcher, railgun, GRIPS) et view_arms.gd.
--
-- Tout est décrit en MÈTRES dans le repère de la caméra (comme dans Godot : -Z devant,
-- +Y en haut, +X à droite), puis converti en studs. Les pièces sont locales (dans la
-- caméra), sans collision ni requête : elles ne gênent ni les tirs ni les déplacements.
--   * balancement : l'arme traîne un peu derrière les mouvements de la souris ;
--   * balancier en courant, recul au tir, petite descente au changement d'arme ;
--   * mains posées sur les poignées de l'arme ; tenue des bras selon le camp ;
--   * masquée pendant le zoom du Rail.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local S = Config.STUDS_PER_METER
local player = Players.LocalPlayer

local Viewmodel = {}

-- Matériaux (couleurs de weapon_models.gd / view_arms.gd) ---------------------------------
local GUNMETAL = Color3.new(0.11, 0.12, 0.15)
local GUNMETAL_LIGHT = Color3.new(0.2, 0.21, 0.25)
local BLACK = Color3.new(0.03, 0.03, 0.04)
local GLOW = {
	rocket = Color3.new(1.0, 0.93, 0.82),
	rail = Color3.new(0.22, 0.91, 1.0),
}
local SKIN = Color3.new(0.66, 0.44, 0.31)
local GLOVE = Color3.new(0.26, 0.24, 0.21)

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

-- Place de chaque arme dans le viewmodel (position, rotation en degrés, échelle) et points de
-- prise des mains [droite (poignée arrière), gauche (avant)] dans le repère de l'arme.
local MOUNTS = {
	rocket = { pos = Vector3.new(0.06, -0.05, -0.1), rot = rotDeg(2, 6, 0), scale = 0.34, grips = { Vector3.new(0, -0.17, 0.12), Vector3.new(0, -0.15, -0.17) } },
	rail = { pos = Vector3.new(0.05, -0.03, -0.08), rot = rotDeg(2, 6, 0), scale = 0.34, grips = { Vector3.new(0, -0.1, 0.19), Vector3.new(0, -0.035, -0.2) } },
}

-- Bras (view_arms.gd), repère caméra : épaules hors champ, coudes décalés des mains.
local SHOULDER = { Vector3.new(0.34, -0.34, 0.06), Vector3.new(-0.3, -0.4, 0.04) }
local ELBOW = { Vector3.new(0.08, -0.08, 0.13), Vector3.new(-0.11, -0.07, 0.09) }
local VM_BASE = Vector3.new(0.16, -0.155, -0.56)

-- Construction ------------------------------------------------------------------------------
local model = Instance.new("Model")
model.Name = "CavaleViewmodel"

local function newPart(shape: Enum.PartType, color: Color3, neon: boolean): Part
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
	p.Parent = model
	return p
end

-- Le cylindre Roblox s'allonge sur X : ce quart de tour le met le long de -Z.
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

type Piece = { part: Part, local_: CFrame } -- local_ : dans le repère de l'arme, déjà à l'échelle (studs)
local weapons: { [string]: { pieces: { Piece }, glow: { Part } } } = {}

for name, list in MODELS do
	local mount = MOUNTS[name]
	local k = mount.scale * S
	local pieces, glows = {}, {}
	for _, d in list do
		local isGlow = d.mat == "glow"
		local color = if isGlow
			then GLOW[name]
			elseif d.mat == "light" then GUNMETAL_LIGHT
			elseif d.mat == "black" then BLACK
			else GUNMETAL
		local part
		local cf = CFrame.new(d.pos * k) * (d.rot or CFrame.identity)
		if d.kind == "tube" then
			part = newPart(Enum.PartType.Cylinder, color, isGlow)
			part.Size = Vector3.new(d.length * k, d.radius * 2 * k, d.radius * 2 * k)
			cf *= ALONG_Z
		else
			part = newPart(Enum.PartType.Block, color, isGlow)
			part.Size = d.size * k
		end
		table.insert(pieces, { part = part, local_ = cf })
		if isGlow then
			table.insert(glows, part)
		end
	end
	weapons[name] = { pieces = pieces, glow = glows }
end

-- Bras : pour chaque côté, avant-bras, manchette, bras, main.
type Arm = { fore: Part, cuff: Part, upper: Part, hand: Part }
local arms: { Arm } = {}
for i = 1, 2 do
	arms[i] = {
		fore = newPart(Enum.PartType.Cylinder, SKIN, false),
		cuff = newPart(Enum.PartType.Cylinder, SKIN, false),
		upper = newPart(Enum.PartType.Cylinder, SKIN, false),
		hand = newPart(Enum.PartType.Block, SKIN, false),
	}
	arms[i].hand.Size = Vector3.new(0.042, 0.034, 0.052) * S
end
local armTeam = -2

-- Tenue selon le camp : Flics manches SWAT bleues et gants ; Bandits avant-bras nus,
-- bracelets orange.
local function dressArms(team: number?)
	local t = if team == 1 then 1 else 0
	if t == armTeam then
		return
	end
	armTeam = t
	local tcol = Config.Teams[t].color
	local sleeve = if t == 0 then Color3.new(0.05, 0.07, 0.14):Lerp(tcol, 0.08) else SKIN
	local upper = if t == 0 then Color3.new(0.04, 0.05, 0.09) else Color3.new(0.11, 0.1, 0.12)
	local hand = if t == 0 then GLOVE else SKIN
	local cuff = if t == 0 then Color3.new(0.1, 0.1, 0.12) else tcol
	for _, a in arms do
		a.fore.Color = sleeve
		a.upper.Color = upper
		a.hand.Color = hand
		a.cuff.Color = cuff
	end
end

-- Cylindre étiré entre a et b (repère caméra, studs), rayon r (studs).
local function span(part: Part, a: Vector3, b: Vector3, r: number): CFrame
	local d = b - a
	local l = math.max(d.Magnitude, 0.001)
	part.Size = Vector3.new(l, r * 2, r * 2)
	return CFrame.lookAt((a + b) / 2, b) * ALONG_Z
end

-- État d'animation ------------------------------------------------------------------------------
local current = nil :: string?
local kick, dip, bob = 0, 0, 0
local sway = Vector2.zero
local lastYaw, lastPitch = nil :: number?, 0

-- Recul : appelé à chaque tir.
function Viewmodel.kick()
	kick = 1
end

local function hideAll()
	model.Parent = nil
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- À appeler après la mise à jour de la caméra.
--   ctrl : contrôleur de déplacement (ou nil), weapon : "rocket" | "rail", yaw / pitch de la vue.
function Viewmodel.update(dt: number, ctrl, weapon: string, yaw: number, pitch: number)
	local cam = Workspace.CurrentCamera
	if not cam or not ctrl or not ctrl.root.Parent or ctrl.zooming then
		hideAll()
		lastYaw = nil
		return
	end
	if model.Parent ~= cam then
		model.Parent = cam
	end
	weapon = if weapons[weapon] then weapon else "rocket"

	-- Changement d'arme : l'arme descend puis remonte.
	if weapon ~= current then
		current = weapon
		dip = 1
		for name, w in weapons do
			local visible = name == weapon
			for _, piece in w.pieces do
				piece.part.Transparency = if visible then 0 else 1
			end
		end
	end
	dressArms(player:GetAttribute("Team"))

	kick = math.max(0, kick - dt * 6)
	dip = math.max(0, dip - dt * 5)

	-- Balancier de course (au sol).
	local v = ctrl.vel
	local hs = Vector2.new(v.X, v.Z).Magnitude
	if ctrl.onFloor then
		bob += dt * hs * 1.3
	end
	local bobV = Vector3.new(math.sin(bob) * 0.012, math.abs(math.cos(bob)) * 0.012, 0) * math.min(1, hs / 8)

	-- Balancement : l'arme traîne derrière la souris.
	local dyaw = if lastYaw then wrap(yaw - lastYaw) else 0
	local dpitch = pitch - lastPitch
	lastYaw, lastPitch = yaw, pitch
	local swayTarget = Vector2.new(math.clamp(dyaw * 2.5, -0.08, 0.08), math.clamp(dpitch * 2.5, -0.06, 0.06))
	sway = sway:Lerp(swayTarget, math.min(1, dt * 10))

	local vmPos = VM_BASE + Vector3.new(-sway.X * 0.4, -dip * 0.1 + sway.Y * 0.3, kick * 0.06) + bobV
	local vmCF = CFrame.new(vmPos * S) * CFrame.fromEulerAnglesYXZ(kick * 0.18, sway.X, sway.X * 0.6)

	local mount = MOUNTS[weapon]
	local weaponCF = vmCF * CFrame.new(mount.pos * S) * mount.rot -- repère caméra (studs)
	local camCF = cam.CFrame

	local parts, cframes = {}, {}
	for _, piece in weapons[weapon].pieces do
		table.insert(parts, piece.part)
		table.insert(cframes, camCF * weaponCF * piece.local_)
	end

	-- Bras : les mains sur les poignées.
	local k = mount.scale * S
	local fwd = weaponCF.LookVector
	for i, a in arms do
		local h = (weaponCF * CFrame.new(mount.grips[i] * k)).Position
		local elbow = h + ELBOW[i] * S
		local shoulder = SHOULDER[i] * S
		local back = (elbow - h).Unit
		local wrist = h + back * 0.034 * S
		local cfFore = span(a.fore, elbow, wrist, 0.031 * S)
		local cfCuff = span(a.cuff, wrist + back * 0.018 * S, wrist, 0.029 * S)
		local cfUpper = span(a.upper, shoulder, elbow, 0.043 * S)
		local up = if math.abs(back:Dot(fwd)) < 0.98 then back:Cross(fwd):Cross(back).Unit else Vector3.yAxis
		local handPos = h + back * 0.012 * S
		local cfHand = CFrame.lookAt(handPos, handPos - back, up)
		for _, pair in { { a.fore, cfFore }, { a.cuff, cfCuff }, { a.upper, cfUpper }, { a.hand, cfHand } } do
			table.insert(parts, pair[1])
			table.insert(cframes, camCF * pair[2])
		end
	end

	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

return Viewmodel
