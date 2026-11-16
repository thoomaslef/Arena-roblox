-- Effets côté client : explosions, sons, roquettes visibles. Rien ici n'a d'effet sur le jeu.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local S = Config.STUDS_PER_METER
local R = Config.Rocket

local Fx = {}

local folder = Workspace:FindFirstChild("CavaleFx")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "CavaleFx"
	folder.Parent = Workspace
end
Fx.folder = folder

local EXPLOSION_COLOR = Color3.new(1.0, 0.5, 0.18)
local ROCKET_COLOR = Color3.new(1.0, 0.93, 0.82)

local function fxPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Son « 2D » (interface, touches).
function Fx.play(id: string, volume: number?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

-- Son placé dans le monde (position en mètres).
function Fx.playAt(id: string, pos: Vector3, volume: number?, pitch: number?)
	local holder = fxPart()
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.Position = pos * S
	holder.Parent = folder
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 300
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 4)
end

-- Explosion de roquette (position en mètres).
function Fx.explosion(pos: Vector3)
	local e = Instance.new("Explosion")
	e.BlastPressure = 0
	e.BlastRadius = R.HIT_RADIUS * S
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Position = pos * S
	e.Parent = folder

	local ball = fxPart()
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = EXPLOSION_COLOR
	ball.Size = Vector3.one * 0.4 * S
	ball.Position = pos * S
	ball.Transparency = 0.1
	ball.Parent = folder
	TweenService:Create(ball, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * R.HIT_RADIUS * 2 * S,
		Transparency = 1,
	}):Play()
	local light = Instance.new("PointLight")
	light.Color = EXPLOSION_COLOR
	light.Range = 8 * S
	light.Brightness = 4
	light.Parent = ball
	TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	Debris:AddItem(ball, 0.4)
end

-- Roquette visible : renvoie la Part à déplacer avec Fx.placeRocket.
function Fx.newRocket(team: number?): Part
	local p = fxPart()
	p.Name = "Rocket"
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = ROCKET_COLOR
	-- Axe du cylindre = X : longueur 0,55 m, diamètre 0,22 m.
	p.Size = Vector3.new(0.55 * S, 0.22 * S, 0.22 * S)
	local light = Instance.new("PointLight")
	light.Color = if team ~= nil and Config.Teams[team] then Config.Teams[team].color else EXPLOSION_COLOR
	light.Range = 4 * S
	light.Brightness = 1.6
	light.Parent = p

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.08 * S, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.08 * S, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(ROCKET_COLOR, EXPLOSION_COLOR)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = p

	p.Parent = folder
	return p
end

-- Place la roquette (position en m, vitesse en m/s) : l'axe X du cylindre suit la vitesse.
function Fx.placeRocket(part: Part, pos: Vector3, vel: Vector3)
	local p = pos * S
	if vel.Magnitude > 0.1 then
		part.CFrame = CFrame.lookAt(p, p + vel) * CFrame.Angles(0, math.pi / 2, 0)
	else
		part.Position = p
	end
end

return Fx
