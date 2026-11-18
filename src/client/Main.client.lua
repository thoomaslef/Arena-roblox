-- Client : déplacement, caméra FPS, endurance, roquettes, HUD du match et gaz.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Lang = require(ReplicatedStorage.Shared:WaitForChild("Lang"))

local Input = require(script.Parent.Input)
local Movement = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Movement"))
local FpsCamera = require(script.Parent.FpsCamera)
local Hud = require(script.Parent.Hud)
local Weapons = require(script.Parent.Weapons)
local MatchHud = require(script.Parent.MatchHud)
local Gas = require(script.Parent.Gas)
local CharacterAnimator = require(script.Parent.CharacterAnimator)
local Viewmodel = require(script.Parent.Viewmodel)
local Sfx = require(script.Parent.Sfx)
local SettingsMenu = require(script.Parent.SettingsMenu) -- menu Réglages (touche P)
local MainMenu = require(script.Parent.MainMenu) -- écran d'accueil
local Tutorial = require(script.Parent.Tutorial)
local TouchControls = require(script.Parent.TouchControls)
MainMenu.onSettings = SettingsMenu.toggle

local aimRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Aim") :: UnreliableRemoteEvent
local aimSendT = 0
local lastSentPitch = 999

Weapons.onHit = function(_victimName, killed, victimModel, livesLeft)
	Hud.onHit(killed, victimModel, livesLeft)
	if killed then
		FpsCamera.punch = 1 -- petit à-coup de zoom à l'élimination
	end
end
Weapons.onDetonated = function()
	Hud.showHit(false)
	MatchHud.killfeed(Lang.t("m.detonated"), Config.Rail.BEAM_COLOR)
end
Weapons.onFire = function()
	Viewmodel.kick()
	Tutorial.noteFire()
end
Weapons.onOtherShot = function(muzzle)
	CharacterAnimator.kickNear(muzzle)
end
Weapons.onDamaged = function()
	Hud.showDamaged()
	Sfx.play("hurt", -2)
	FpsCamera.shake = math.max(FpsCamera.shake, 0.6)
end

local player = Players.LocalPlayer
local ctrl = nil
local stride = 0
local lastWeapon = "rocket"

-- Le joueur ne voit pas son propre corps (vue FPS) : la caméra est dans la tête, les cheveux
-- et accessoires rempliraient l'écran. LocalTransparencyModifier ne suffit pas pour certains
-- accessoires (vêtements « layered ») : on met aussi Transparency à 1. Ce changement fait
-- sur notre client n'est pas envoyé au serveur : les autres joueurs nous voient normalement.
local function hideLocalBody(character: Model)
	local function hide(d: Instance)
		if d:IsA("BasePart") or d:IsA("Decal") then
			local visual: any = d
			visual.LocalTransparencyModifier = 1
			visual.Transparency = 1
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
	CharacterAnimator.stopOwn(character)
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
	if Weapons.weapon ~= lastWeapon then
		lastWeapon = Weapons.weapon
		Sfx.play("switch", -8)
	end
	if ctrl and ctrl.root.Parent then
		FpsCamera.update(dt, ctrl:eyePosition())
	end
	-- Bras et arme en main, juste après la caméra.
	Viewmodel.update(dt, ctrl, Weapons.weapon, FpsCamera.yaw, FpsCamera.pitch)
	Hud.update(ctrl)
	Hud.setVisible(not MainMenu.isOpen())
	MainMenu.update(dt, SettingsMenu.isOpen())
	Tutorial.update(dt, ctrl)
	TouchControls.update(if ctrl and ctrl.root.Parent then ctrl else nil, not MainMenu.isOpen() and not SettingsMenu.isOpen())
	-- Un écran cliquable est ouvert (accueil, réglages, vote de map) : souris libre, le
	-- personnage ne reçoit plus les commandes.
	local uiOpen = MainMenu.isOpen() or SettingsMenu.isOpen() or MatchHud.isVoting()
	Input.menuOpen = uiOpen
	FpsCamera.cursorFree = uiOpen
	CharacterAnimator.update(dt)
	-- Inclinaison de notre visée, pour que l'adversaire voie où on vise (~15 fois par seconde).
	aimSendT -= dt
	if ctrl and ctrl.root.Parent and aimSendT <= 0 then
		aimSendT = 1 / 15
		if math.abs(FpsCamera.pitch - lastSentPitch) > 0.01 then
			lastSentPitch = FpsCamera.pitch
			aimRemote:FireServer(FpsCamera.pitch)
		end
	end
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

	-- Sons de nos propres actions (en 2D : on est dans la tête du personnage).
	if ctrl.onJump then
		Sfx.play("jump", -8)
	end
	if ctrl.onWalljump then
		Sfx.play("jump", -4, 1.25)
	end
	if ctrl.onLand then
		Sfx.play("land", -6)
	end
	if ctrl.onPad then
		Sfx.play("pad")
	end
	if ctrl.onAccel then
		Sfx.play("accel")
	end
	-- Pas : un son tous les 1,6 m en marchant, 2,9 m en courant.
	local hs = Vector2.new(ctrl.vel.X, ctrl.vel.Z).Magnitude
	local level = if ctrl.onFloor then Sfx.stepLevel(hs, ctrl.sprinting) else 0
	if level > 0 then
		stride += hs * dt
		if stride > Sfx.stride(level) then
			stride = 0
			Sfx.step(level, ctrl.surfacePart)
		end
	else
		stride = 1.2 -- le premier pas tombe vite après l'atterrissage
	end
end)
