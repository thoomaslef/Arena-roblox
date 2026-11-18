-- Animations des personnages, jouées par CHAQUE client pour les autres personnages
-- (adversaire et bot ; notre propre corps est invisible en vue FPS).
--
-- Le Humanoid ne gère plus rien (contrôleur maison) : le script Animate de Roblox ne
-- saurait pas quoi jouer. On lit donc les mouvements réels (vitesse, au sol ou non) et on
-- choisit l'animation : repos, marche, course, sprint, saut, chute, plané.
-- En plus :
--   * le bassin se tourne vers la direction du déplacement (pas latéraux, marche arrière),
--     le haut du corps reste face à la visée ;
--   * le buste et la tête suivent l'inclinaison de la visée (attribut AimPitch) ;
--   * petit recul du buste à chaque tir ;
--   * l'arme en main (roquette, ou Rail sur une plateforme Rail), bras en position de tir.
-- Les ID d'animation sont ceux de l'avatar (copiés par CharacterRig), sinon ceux de Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rocket = require(Shared.Rocket)

local Fx = require(script.Parent.Fx)
local WeaponModels = require(script.Parent.WeaponModels)

local S = Config.STUDS_PER_METER
local player = Players.LocalPlayer

-- Animations par défaut de Roblox.
local DEFAULTS = {
	R15 = {
		idle = "rbxassetid://507766666",
		walk = "rbxassetid://507777826",
		run = "rbxassetid://507767714",
		jump = "rbxassetid://507765000",
		fall = "rbxassetid://507767968",
	},
	R6 = {
		idle = "rbxassetid://180435571",
		walk = "rbxassetid://180426354",
		run = "rbxassetid://180426354",
		jump = "rbxassetid://125750702",
		fall = "rbxassetid://180436148",
	},
}

local FADE = 0.15
local MAX_TWIST = math.rad(60) -- rotation max du bassin vers le déplacement
local WALK_MAX = 5.0 -- m/s : au-delà, on passe de la marche à la course
local SPRINT_MIN = 11.0 -- m/s : au-delà, course accélérée (sprint)
local GLIDE_FALL = Config.Move.GLIDE_MAX_FALL

local CharacterAnimator = {}

type Entry = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	animator: Animator,
	tracks: { [string]: AnimationTrack },
	current: string?,
	lastPos: Vector3?,
	vel: Vector3,
	airT: number,
	twist: number,
	pitch: number,
	kick: number,
	joints: { [string]: { motor: Motor6D, base: CFrame } },
	r15: boolean,
	weapon: string,
	guns: { [string]: { WeaponModels.Piece } },
	shownWeapon: string?,
}

-- Bras en position de tir (rotation dans le repère de la pièce parente, au point d'attache) :
-- bras droit vers l'avant sur la poignée, bras gauche ramené sous le canon.
local ARM_POSE_R15 = {
	rshoulder = CFrame.Angles(0, math.rad(15), 0) * CFrame.Angles(math.rad(80), 0, 0),
	relbow = CFrame.Angles(math.rad(20), 0, 0),
	lshoulder = CFrame.Angles(0, math.rad(-40), 0) * CFrame.Angles(math.rad(75), 0, 0),
	lelbow = CFrame.Angles(math.rad(30), 0, 0),
}
local ARM_POSE_R6 = {
	rshoulder = CFrame.Angles(0, math.rad(15), 0) * CFrame.Angles(math.rad(85), 0, 0),
	lshoulder = CFrame.Angles(0, math.rad(-35), 0) * CFrame.Angles(math.rad(80), 0, 0),
}
local ARM_JOINTS = { "rshoulder", "relbow", "lshoulder", "lelbow" }
local WEAPON_SCALE = 1.0 -- taille réelle (m)

local entries: { [Model]: Entry } = {}

local function loadTracks(model: Model, animator: Animator, r15: boolean): { [string]: AnimationTrack }
	local defaults = if r15 then DEFAULTS.R15 else DEFAULTS.R6
	local tracks = {}
	for key, default in defaults do
		local id = model:GetAttribute("Anim_" .. key)
		local anim = Instance.new("Animation")
		anim.AnimationId = if type(id) == "string" and id ~= "" then id else default
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = key ~= "jump"
			track.Priority = if key == "idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			tracks[key] = track
		end
	end
	return tracks
end

local function joint(parent: Instance?, name: string): Motor6D?
	local m = parent and parent:FindFirstChild(name)
	return if m and m:IsA("Motor6D") then m else nil
end

local function track(model: Model)
	if entries[model] or model == player.Character then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or model:GetAttribute("FeetOffset") == nil then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local joints = {}
	local function keep(key: string, m: Motor6D?)
		if m then
			joints[key] = { motor = m, base = m.C0 }
		end
	end
	if r15 then
		keep("root", joint(model:FindFirstChild("LowerTorso"), "Root"))
		keep("waist", joint(model:FindFirstChild("UpperTorso"), "Waist"))
		keep("neck", joint(model:FindFirstChild("Head"), "Neck"))
		keep("rshoulder", joint(model:FindFirstChild("RightUpperArm"), "RightShoulder"))
		keep("relbow", joint(model:FindFirstChild("RightLowerArm"), "RightElbow"))
		keep("lshoulder", joint(model:FindFirstChild("LeftUpperArm"), "LeftShoulder"))
		keep("lelbow", joint(model:FindFirstChild("LeftLowerArm"), "LeftElbow"))
	else
		local torso = model:FindFirstChild("Torso")
		keep("neck", joint(torso, "Neck"))
		keep("rshoulder", joint(torso, "Right Shoulder"))
		keep("lshoulder", joint(torso, "Left Shoulder"))
	end
	-- Les deux armes, construites une fois ; on affiche celle en main.
	local guns = {}
	for name in WeaponModels.GRIPS do
		guns[name] = WeaponModels.build(name, WEAPON_SCALE * S, Fx.folder)
		WeaponModels.setVisible(guns[name], false)
	end
	entries[model] = {
		model = model,
		humanoid = humanoid,
		root = root,
		animator = animator :: Animator,
		tracks = loadTracks(model, animator :: Animator, r15),
		current = nil,
		lastPos = nil,
		vel = Vector3.zero,
		airT = 0,
		twist = 0,
		pitch = 0,
		kick = 0,
		joints = joints,
		r15 = r15,
		weapon = "rocket",
		guns = guns,
		shownWeapon = nil,
	}
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			CharacterAnimator.forget(model)
		end
	end)
end

local function play(e: Entry, key: string, speed: number)
	local t = e.tracks[key]
	if e.current ~= key then
		if e.current and e.tracks[e.current] then
			e.tracks[e.current]:Stop(FADE)
		end
		e.current = key
		if t then
			t:Play(FADE)
		end
	end
	if t then
		t:AdjustSpeed(speed)
	end
end

-- Tourne un joint autour de son point d'attache (dans le repère de la pièce parente).
local function pose(e: Entry, key: string, rot: CFrame)
	local j = e.joints[key]
	if j then
		local base = j.base
		j.motor.C0 = CFrame.new(base.Position) * rot * (base - base.Position)
	end
end

function CharacterAnimator.forget(model: Model)
	local e = entries[model]
	if not e then
		return
	end
	entries[model] = nil
	for _, pieces in e.guns do
		for _, piece in pieces do
			piece.part:Destroy()
		end
	end
end

-- Sol sous les pieds : la Part touchée (ou nil en l'air).
local function groundPart(feet: Vector3): BasePart?
	local from = feet + Vector3.new(0, 0.3, 0)
	local hit = Workspace:Raycast(from * S, Vector3.new(0, -0.6 * S, 0), Rocket.worldParams())
	return if hit then hit.Instance :: BasePart else nil
end

local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

function CharacterAnimator.update(dt: number)
	if dt <= 0 then
		return
	end
	for model, e in entries do
		if not e.root.Parent then
			CharacterAnimator.forget(model)
			continue
		end
		local feet = Rocket.feetOf(model)
		if not feet then
			continue
		end
		-- Vitesse d'après le déplacement réel (lissée), fiable pour tout personnage répliqué.
		if e.lastPos then
			local raw = (feet - e.lastPos) / dt
			if raw.Magnitude < 80 then -- ignore les téléportations
				e.vel = e.vel:Lerp(raw, math.min(1, dt * 12))
			end
		end
		e.lastPos = feet
		local v = e.vel
		local flat = Vector3.new(v.X, 0, v.Z)
		local hs = flat.Magnitude
		local ground = groundPart(feet)
		local grounded = ground ~= nil and math.abs(v.Y) < 3
		e.airT = if grounded then 0 else e.airT + dt
		-- L'arme dépend du bloc sous les pieds (comme pour nous), gardée en l'air.
		if grounded and ground then
			e.weapon = if ground:GetAttribute("Surface") == "rail" then "rail" else "rocket"
		end

		-- Direction du déplacement par rapport au regard (repère du HumanoidRootPart).
		local twistTarget, backwards = 0, false
		if hs > 1.0 then
			local localMove = e.root.CFrame:VectorToObjectSpace(flat)
			local ang = math.atan2(-localMove.X, -localMove.Z) -- 0 = devant, + = vers la gauche
			if math.abs(ang) > math.pi / 2 + 0.2 then
				backwards = true
				ang = wrap(ang - math.pi)
			end
			twistTarget = math.clamp(ang, -MAX_TWIST, MAX_TWIST)
		end
		if not grounded then
			twistTarget *= 0.4
		end
		e.twist += (twistTarget - e.twist) * math.min(1, dt * 10)

		-- Choix de l'animation.
		local studsPerSec = hs * S
		if grounded or e.airT < 0.12 then
			if hs < 0.6 then
				play(e, "idle", 1)
			elseif hs < WALK_MAX then
				play(e, "walk", (if backwards then -1 else 1) * math.clamp(studsPerSec / 14, 0.4, 1.6))
			else
				local k = if hs >= SPRINT_MIN then 1.15 else 1
				play(e, "run", (if backwards then -1 else 1) * math.clamp(studsPerSec / 20 * k, 0.8, 2.3))
			end
		elseif v.Y > 0.5 and e.current ~= "fall" then
			-- Montée : animation de saut (jouée une fois), puis pose de chute si on monte
			-- encore longtemps (rocket jump, pad).
			local jt = e.tracks.jump
			if jt and (e.current ~= "jump" or jt.IsPlaying) then
				play(e, "jump", 1)
			else
				play(e, "fall", 1)
			end
		elseif v.Y > -(GLIDE_FALL + 0.4) and e.airT > 0.35 then
			play(e, "fall", 0.35) -- plané : chute lente, pose ralentie
		else
			play(e, "fall", 1)
		end

		-- Buste et tête : visée haut / bas, recul du tir, bassin tourné vers le déplacement.
		local target = model:GetAttribute("AimPitch")
		target = if type(target) == "number" then target else 0
		e.pitch += (target - e.pitch) * math.min(1, dt * 15)
		e.kick = math.max(0, e.kick - dt * 6)
		local aim = e.pitch + e.kick * 0.25
		if e.r15 then
			pose(e, "root", CFrame.Angles(0, e.twist, 0))
			pose(e, "waist", CFrame.Angles(0, -e.twist, 0) * CFrame.Angles(aim * 0.55, 0, 0))
			pose(e, "neck", CFrame.Angles(aim * 0.4, 0, 0))
		else
			pose(e, "neck", CFrame.Angles(aim * 0.6, 0, 0))
		end
	end
end

-- Après l'animation (PreSimulation) : bras tenus en position de tir (on remplace la pose
-- animée des bras), puis l'arme placée dans la main droite, alignée sur la visée.
RunService.PreSimulation:Connect(function()
	local parts, cframes = {}, {}
	for model, e in entries do
		if not e.root.Parent then
			continue
		end
		local armPose = if e.r15 then ARM_POSE_R15 else ARM_POSE_R6
		for _, key in ARM_JOINTS do
			local j = e.joints[key]
			if j and armPose[key] then
				j.motor.Transform = CFrame.identity
				pose(e, key, armPose[key])
			end
		end

		if e.shownWeapon ~= e.weapon then
			for name, pieces in e.guns do
				WeaponModels.setVisible(pieces, name == e.weapon)
			end
			e.shownWeapon = e.weapon
		end
		local hand, rot
		if e.r15 then
			local rh = model:FindFirstChild("RightHand") :: BasePart?
			local ut = model:FindFirstChild("UpperTorso") :: BasePart?
			if rh and ut then
				hand, rot = rh.Position, ut.CFrame.Rotation
			end
		else
			local ra = model:FindFirstChild("Right Arm") :: BasePart?
			local torso = model:FindFirstChild("Torso") :: BasePart?
			if ra and torso then
				hand = (ra.CFrame * CFrame.new(0, -ra.Size.Y / 2, 0)).Position
				rot = torso.CFrame.Rotation * CFrame.Angles(e.pitch * 0.6, 0, 0)
			end
		end
		if hand and rot then
			local k = WEAPON_SCALE * S
			local grip = WeaponModels.GRIPS[e.weapon][1] * k
			local weaponCF = CFrame.new(hand) * rot * CFrame.new(-grip) * CFrame.new(0, 0, e.kick * 0.08 * S)
			for _, piece in e.guns[e.weapon] do
				table.insert(parts, piece.part)
				table.insert(cframes, weaponCF * piece.local_)
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- Recul : le personnage le plus proche de `pos` (m) vient de tirer.
function CharacterAnimator.kickNear(pos: Vector3)
	local best, bestD = nil, 2.5
	for model, e in entries do
		local feet = Rocket.feetOf(model)
		if feet then
			local d = (feet + Vector3.new(0, Config.Body.EYE_HEIGHT, 0) - pos).Magnitude
			if d < bestD then
				best, bestD = e, d
			end
		end
	end
	if best then
		best.kick = 1
	end
end

-- Notre propre personnage : on arrête les animations que le script Animate de Roblox a pu
-- lancer avant d'être retiré par le serveur (elles seraient visibles chez les autres).
function CharacterAnimator.stopOwn(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0)
		end
	end
end

-- Repère les personnages (joueurs et bots) ; FeetOffset arrive un peu après leur apparition.
task.spawn(function()
	while true do
		for _, child in Workspace:GetChildren() do
			if child:IsA("Model") and not entries[child] then
				track(child)
			end
		end
		task.wait(0.5)
	end
end)

return CharacterAnimator
