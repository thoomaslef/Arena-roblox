-- Sons du jeu (client). Mêmes sons que le jeu Godot (autoload/sfx.gd), générés par
-- tools/make_sfx.py dans UNE planche de sons : assets/sfx/cavale_sfx.ogg.
-- Chaque son est un morceau de cette planche, joué avec Sound.PlaybackRegion
-- (positions dans Shared/SfxAtlas).
--
-- Tant que Config.Audio.SFX_ID est vide (planche pas encore mise en ligne sur Roblox),
-- on joue quelques sons intégrés à Roblox à la place, et les autres restent muets.
--
--   Sfx.play("hit", volumeDb, pitch)            son « 2D » (interface, nos propres actions)
--   Sfx.playAt("explosion", posM, volumeDb, pitch, maxDistM)   son placé dans le monde

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Atlas = require(Shared.SfxAtlas)

local Fx = require(script.Parent.Fx)

local S = Config.STUDS_PER_METER
local A = Config.Audio

local Sfx = {}

-- Remplaçants intégrés à Roblox (avant la mise en ligne de la planche) : { id, vitesse }.
local FALLBACK = {
	rocket = { "rbxasset://sounds/Rocket shot.wav", 1 },
	rail = { "rbxasset://sounds/electronicpingshort.wav", 0.6 },
	hit = { "rbxasset://sounds/electronicpingshort.wav", 1.2 },
	kill = { "rbxasset://sounds/electronicpingshort.wav", 0.8 },
	jump = { "rbxasset://sounds/action_jump.mp3", 1 },
	land = { "rbxasset://sounds/action_jump_land.mp3", 1 },
	empty = { "rbxasset://sounds/switch.wav", 1 },
	beep = { "rbxasset://sounds/button.wav", 1 },
}

local function atlasReady(): boolean
	return type(A.SFX_ID) == "string" and A.SFX_ID ~= ""
end

-- Prépare un Sound pour `name`. Renvoie (sound, durée) ou nil si ce son n'existe pas.
local function makeSound(name: string, volumeDb: number?, pitch: number?): (Sound?, number)
	local s = Instance.new("Sound")
	local speed = pitch or 1
	local duration = 3
	if atlasReady() then
		local r = Atlas[name]
		if not r then
			s:Destroy()
			return nil, 0
		end
		s.SoundId = A.SFX_ID
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(r[1], r[2])
		duration = (r[2] - r[1]) / speed
	else
		local fb = FALLBACK[name]
		if not fb then
			s:Destroy()
			return nil, 0
		end
		s.SoundId = fb[1]
		speed *= fb[2]
	end
	-- Volume en dB (comme dans Godot) → volume linéaire Roblox.
	s.Volume = A.VOLUME * 10 ^ ((volumeDb or 0) / 20)
	s.PlaybackSpeed = speed
	return s, duration
end

function Sfx.play(name: string, volumeDb: number?, pitch: number?)
	local s, duration = makeSound(name, volumeDb, pitch)
	if not s then
		return
	end
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, duration + 0.2)
end

-- pos en mètres ; maxDist (m) : au-delà, on n'entend plus rien (140 m par défaut).
function Sfx.playAt(name: string, pos: Vector3, volumeDb: number?, pitch: number?, maxDist: number?)
	-- Légère variation de hauteur, comme dans Godot, pour éviter l'effet « disque rayé ».
	local s, duration = makeSound(name, volumeDb, (pitch or 1) * (0.96 + math.random() * 0.08))
	if not s then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.Position = pos * S
	holder.Parent = Fx.folder
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = math.min(9, (maxDist or 140) * 0.5) * S
	s.RollOffMaxDistance = (maxDist or 140) * S
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, duration + 0.2)
end

-- Pas (fighter.gd) : matière du bloc sous les pieds → son ; niveau 1 marche, 2 course, 3 sprint.
local STEP_MATERIALS = { height = "metal", jump_pad = "metal", accelerator = "metal", sprint = "metal", glass = "glass" }
local STEP_VOL_OWN = { -34, -19, -13 }
local STEP_VOL_3D = { -16, -2, 3 }
local STEP_RANGE = { 6, 28, 50 } -- m : portée d'écoute

function Sfx.stepLevel(hs: number, sprinting: boolean?): number
	if hs < 1.2 then
		return 0
	end
	if sprinting or hs > 10.5 then
		return 3
	end
	return if hs < 5.4 then 1 else 2
end

-- Distance (m) entre deux pas selon le niveau.
function Sfx.stride(level: number): number
	return if level == 1 then 1.6 else 2.9
end

-- Joue un pas. `ground` : la Part sous les pieds ; `pos` (m) nil = nos propres pas (2D, discrets).
function Sfx.step(level: number, ground: Instance?, pos: Vector3?)
	if level <= 0 then
		return
	end
	local mat = ground and STEP_MATERIALS[ground.Name]
	local name
	if mat then
		name = ("step_%s%d"):format(mat, math.random(0, 1))
	elseif level >= 3 then
		name = "step_sprint"
	else
		name = ("step%d"):format(math.random(0, 2))
	end
	local pitch = 0.9 + math.random() * 0.2
	if pos then
		Sfx.playAt(name, pos, STEP_VOL_3D[level], pitch, STEP_RANGE[level])
	else
		Sfx.play(name, STEP_VOL_OWN[level], pitch)
	end
end

-- Charge la planche dès le début (sinon le premier son de la partie arriverait en retard).
if atlasReady() then
	task.spawn(function()
		local s = Instance.new("Sound")
		s.SoundId = A.SFX_ID
		pcall(function()
			ContentProvider:PreloadAsync({ s })
		end)
		s:Destroy()
	end)
end

return Sfx
