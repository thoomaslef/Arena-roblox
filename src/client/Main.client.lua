-- Client : déplacement, caméra FPS, endurance, roquettes, HUD du match et gaz.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Input = require(script.Parent.Input)
local Movement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Movement"))
local FpsCamera = require(script.Parent.FpsCamera)
local Hud = require(script.Parent.Hud)
local Weapons = require(script.Parent.Weapons)
local MatchHud = require(script.Parent.MatchHud)
local Gas = require(script.Parent.Gas)

Weapons.onHit = function(_victimName, killed)
	Hud.showHit(killed)
end
Weapons.onDetonated = function()
	Hud.showHit(false)
	MatchHud.killfeed("Roquette détruite en vol !", Config.Rail.BEAM_COLOR)
end
Weapons.onDamaged = function()
	Hud.showDamaged()
	FpsCamera.shake = math.max(FpsCamera.shake, 0.6)
end

local player = Players.LocalPlayer
local ctrl = nil

-- Le joueur ne voit pas son propre corps (vue FPS).
local function hideLocalBody(character: Model)
	local function hide(d: Instance)
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = 1
		end
	end
	for _, d in character:GetDescendants() do
		hide(d)
	end
	character.DescendantAdded:Connect(hide)
end

local function onCharacter(character: Model)
	if ctrl then
		ctrl:destroy()
		ctrl = nil
		Weapons.setController(nil)
	end
	local c = Movement.new(character)
	if player.Character ~= character then
		c:destroy()
		return
	end
	ctrl = c
	Weapons.setController(c)
	Weapons.reset()
	FpsCamera.setYaw(c.yaw)
	hideLocalBody(character)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- Caméra : juste avant le rendu.
RunService:BindToRenderStep("CavaleCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	Input.update(dt)
	FpsCamera.applyLook(Input.consumeLook())
	Weapons.update(dt, Input.fireHeld) -- (le tir vérifie lui-même qu'on a un personnage)
	FpsCamera.zoomTarget = if ctrl and ctrl.zooming then Config.Rail.ZOOM_FACTOR else 1
	Hud.updateWeapons(Weapons.charges, Weapons.weapon, Weapons.railCharges)
	if ctrl and ctrl.root.Parent then
		FpsCamera.update(dt, ctrl:eyePosition())
	end
	Hud.update(ctrl)
	local stage, warn = Gas.update(dt, if ctrl and ctrl.root.Parent then ctrl.character else nil)
	MatchHud.update(stage, warn)
end)

-- Déplacement : avant chaque pas de physique.
RunService.PreSimulation:Connect(function(dt)
	if not ctrl then
		return
	end
	ctrl.yaw = FpsCamera.yaw
	ctrl:step(dt, {
		move = Input.move,
		held = Input.mobHeld,
		pressed = Input.consumeMobPressed(),
		walk = Input.walk,
	})
end)
