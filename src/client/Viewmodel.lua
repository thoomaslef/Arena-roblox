-- Vue à la première personne : l'arme en main et les bras, devant la caméra.
-- Portage de arena.gd (_build_viewmodel, _update_viewmodel) et view_arms.gd ; les armes
-- viennent de WeaponModels (weapon_models.gd).
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

local WeaponModels = require(script.Parent.WeaponModels)

local SKIN = Color3.new(0.66, 0.44, 0.31)
local GLOVE = Color3.new(0.26, 0.24, 0.21)

local function rotDeg(x: number, y: number, z: number): CFrame
	return CFrame.fromEulerAnglesYXZ(math.rad(x), math.rad(y), math.rad(z))
end

-- Place de chaque arme dans le viewmodel (position, rotation en degrés, échelle) ; les mains
-- se posent sur WeaponModels.GRIPS.
local MOUNTS = {
	rocket = { pos = Vector3.new(0.06, -0.05, -0.1), rot = rotDeg(2, 6, 0), scale = 0.34, grips = WeaponModels.GRIPS.rocket },
	rail = { pos = Vector3.new(0.05, -0.03, -0.08), rot = rotDeg(2, 6, 0), scale = 0.34, grips = WeaponModels.GRIPS.rail },
}

-- Bras (view_arms.gd), repère caméra : épaules hors champ, coudes décalés des mains.
local SHOULDER = { Vector3.new(0.34, -0.34, 0.06), Vector3.new(-0.3, -0.4, 0.04) }
local ELBOW = { Vector3.new(0.08, -0.08, 0.13), Vector3.new(-0.11, -0.07, 0.09) }
local VM_BASE = Vector3.new(0.16, -0.155, -0.56)

-- Construction ------------------------------------------------------------------------------
local model = Instance.new("Model")
model.Name = "CavaleViewmodel"

local function newPart(shape: Enum.PartType, color: Color3, neon: boolean): Part
	return WeaponModels.newPart(shape, color, neon, model)
end

local ALONG_Z = WeaponModels.ALONG_Z

local weapons: { [string]: { pieces: { WeaponModels.Piece } } } = {}
for name, mount in MOUNTS do
	weapons[name] = { pieces = WeaponModels.build(name, mount.scale * S, model) }
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
			WeaponModels.setVisible(w.pieces, name == weapon)
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
