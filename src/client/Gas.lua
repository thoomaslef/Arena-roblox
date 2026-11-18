-- Gaz lacrymo côté client : mur blanc-vert qui se resserre, bip près du bord,
-- message à chaque resserrement. Le rayon est recalculé ici à partir de l'heure du GO
-- (même formule que le serveur, qui seul décide des morts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local JoustRules = require(Shared.JoustRules)
local Rocket = require(Shared.Rocket)

local Fx = require(script.Parent.Fx)
local MatchHud = require(script.Parent.MatchHud)
local Sfx = require(script.Parent.Sfx)

local S = Config.STUDS_PER_METER
local J = Config.Joust
local SEGMENTS = 64

local match = ReplicatedStorage:WaitForChild("Match")

local Gas = {}

local wallColor = Color3.new(1, 1, 1):Lerp(J.GAS_COLOR, 0.55)
local panels: { Part } = {}
local wallFolder = Instance.new("Folder")
wallFolder.Name = "GasWall"
wallFolder.Parent = Fx.folder

for i = 1, SEGMENTS do
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = wallColor
	p.Transparency = 0.55
	p.Size = Vector3.new(1, 1, 0.1)
	p.Parent = wallFolder
	panels[i] = p
end

local lastRadius = -1
local bottomY, wallH = 0, 20 -- m
local prevStage = 0
local beepT = 0

local measuredMap: Instance? = nil
local function measureMap()
	local map = Workspace:FindFirstChild("Map")
	measuredMap = map
	if map and map:IsA("Model") then
		local cf, size = map:GetBoundingBox()
		bottomY = (cf.Position.Y - size.Y / 2) / S
		wallH = size.Y / S + J.GAS_WALL_EXTRA
	end
end

local function placeWall(center: Vector3, radius: number, visible: boolean)
	if not visible then
		if lastRadius ~= -2 then
			for _, p in panels do
				p.Transparency = 1
			end
			lastRadius = -2
		end
		return
	end
	-- Nouvelle map : on remesure sa hauteur et on replace le mur.
	if Workspace:FindFirstChild("Map") ~= measuredMap then
		measureMap()
		lastRadius = -1
	end
	if math.abs(radius - lastRadius) < 0.01 then
		return
	end
	lastRadius = radius
	local width = 2 * math.pi * radius / SEGMENTS * 1.06
	local cy = bottomY + wallH / 2
	for i, p in panels do
		local a = (i - 1) / SEGMENTS * 2 * math.pi
		local pos = Vector3.new(center.X + math.cos(a) * radius, cy, center.Z + math.sin(a) * radius)
		local look = Vector3.new(center.X, cy, center.Z)
		p.Size = Vector3.new(width * S, wallH * S, 0.1 * S)
		p.CFrame = CFrame.lookAt(pos * S, look * S)
		p.Transparency = 0.55
	end
end

-- À chaque image. Renvoie (palier du gaz, alerte « près du bord »).
function Gas.update(dt: number, character: Model?): (number, boolean)
	local state = match:GetAttribute("State")
	local r0 = match:GetAttribute("GasR0")
	local center = match:GetAttribute("GasCenter")
	if type(r0) ~= "number" or typeof(center) ~= "Vector3" or state == "waiting" or state == nil then
		placeWall(Vector3.zero, 0, false)
		prevStage = 0
		return 0, false
	end
	local t = MatchHud.roundTime()
	local radius = if state == "live" or state == "post" then JoustRules.gasRadius(t, r0) else r0
	placeWall(center, radius, true)

	local stage = if state == "live" then JoustRules.gasStage(t) else 0
	if state == "live" and stage ~= prevStage and JoustRules.isShrinking(t) then
		MatchHud.gasShrink(stage)
	end
	prevStage = stage

	local warn = false
	if state == "live" and MatchHud.myIndex() ~= nil then -- seuls les combattants sont concernés
		local feet = Rocket.feetOf(character)
		if feet and JoustRules.distToCenter(feet, center) > radius - J.GAS_WARN_DIST then
			warn = true
			beepT -= dt
			if beepT <= 0 then
				beepT = 0.5
				Sfx.play("zone", -6)
			end
		end
	end
	return stage, warn
end

return Gas
