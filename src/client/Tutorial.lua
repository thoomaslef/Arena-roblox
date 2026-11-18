-- Tutoriel (client) : 9 étapes guidées sur le terrain d'entraînement, chacune validée
-- automatiquement quand le joueur réussit le geste. Actif en mode « tutorial ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Lang = require(ReplicatedStorage.Shared:WaitForChild("Lang"))
local UserInputService = game:GetService("UserInputService")
local Input = require(script.Parent.Input)
local Sfx = require(script.Parent.Sfx)
local UiScale = require(script.Parent.UiScale)

local M = Config.Move
local ACCENT = Color3.fromRGB(255, 200, 80)
local RAIL = Config.Rail.BEAM_COLOR

local player = Players.LocalPlayer
local lobby = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby") :: RemoteEvent

local Tutorial = {}

local TOUCH_NAMES = {
	forward = "tuto.joystick",
	back = "tuto.joystick",
	left = "tuto.joystick",
	right = "tuto.joystick",
	mobility = "tuto.btn_jump",
	fire = "tuto.btn_fire",
}

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function key(id: string): string
	-- Sur téléphone / tablette (sans clavier) : on parle des boutons à l'écran.
	if touchOnly() then
		return Lang.t(TOUCH_NAMES[id] or id)
	end
	local b = Input.bindings[id]
	local a = Input.pretty(b[1])
	if b[2] ~= "" then
		return a .. " / " .. Input.pretty(b[2])
	end
	return a
end

-- Étapes : clé de texte (Lang), touche affichée, et condition de réussite.
-- `st` garde l'état de suivi (sauts, temps de plané…).
local STEPS = {
	{
		id = "move",
		text = function()
			if touchOnly() then
				return Lang.t("tuto.move.touch")
			end
			return Lang.t("tuto.move.text", key("forward"), key("left"), key("back"), key("right"))
		end,
		done = function(st)
			return st.moved > 8
		end,
	},
	{
		id = "micro",
		done = function(st)
			return st.lastJumpVy ~= nil and st.lastJumpVy < 4.5
		end,
	},
	{
		id = "full",
		done = function(st)
			return st.lastJumpVy ~= nil and st.lastJumpVy >= M.JUMP_FULL_VY - 0.3
		end,
	},
	{
		id = "glide",
		done = function(st)
			return st.glide > 0.8
		end,
	},
	{
		id = "sprint",
		done = function(st)
			return st.sprint > 1.0
		end,
	},
	{
		id = "wall",
		done = function(st)
			return st.walljumps >= 1
		end,
	},
	{
		id = "fire",
		key = "fire",
		done = function(st)
			return st.shots >= 2
		end,
	},
	{
		id = "rj",
		done = function(st)
			return st.knock > 5
		end,
	},
	{
		id = "rail",
		done = function(st)
			return st.zoom > 0.5
		end,
	},
}

local function stepTitle(step): string
	return Lang.t("tuto." .. step.id .. ".title")
end

local function stepText(step): string
	if step.text then
		return step.text()
	end
	return Lang.t("tuto." .. step.id .. ".text", key(step.key or "mobility"))
end

-- Interface -----------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CavaleTutorial"
gui.AutoLocalize = false -- nos textes sont déjà traduits (Lang) : pas de traduction auto de Roblox
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Enabled = false
UiScale.attach(gui)

local panel = Instance.new("Frame")
panel.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
panel.BackgroundTransparency = 0.15
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(640, 118)
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 2
stroke.Transparency = 0.4
stroke.Parent = panel

local function label(props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = panel
	return l
end
local stepLabel = label({ Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = ACCENT, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 18) })
local titleLabel = label({ Font = Enum.Font.GothamBlack, TextSize = 24, Position = UDim2.fromOffset(18, 28), Size = UDim2.new(1, -36, 0, 30) })
local textLabel = label({ Font = Enum.Font.GothamMedium, TextSize = 16, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(18, 60), Size = UDim2.new(1, -36, 0, 50) })

local function button(text: string, x: number, primary: boolean): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 18
	b.TextColor3 = if primary then Color3.fromRGB(20, 20, 28) else Color3.new(1, 1, 1)
	b.BackgroundColor3 = if primary then ACCENT else Color3.fromRGB(40, 44, 58)
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(x, 0, 1, -14)
	b.Size = UDim2.new(0.44, 0, 0, 44)
	b.Visible = false
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end
local playButton = button("", 0.04, true)
local menuButton = button("", 0.52, false)
Lang.bind(playButton, "tuto.play")
Lang.bind(menuButton, "tuto.menu")

local skip = Instance.new("TextButton")
Lang.bind(skip, "tuto.skip")
skip.Font = Enum.Font.GothamBold
skip.TextSize = 14
skip.TextColor3 = Color3.fromRGB(190, 195, 210)
skip.BackgroundTransparency = 1
skip.AnchorPoint = Vector2.new(1, 0)
skip.Position = UDim2.new(1, -14, 0, 8)
skip.Size = UDim2.fromOffset(90, 20)
skip.Parent = panel

gui.Parent = player:WaitForChild("PlayerGui")

-- État -----------------------------------------------------------------------------------------
local index = 1
local st = nil
local finished = false
local lastPos: Vector3? = nil
local jumpMaxVy: number? = nil

local function newState()
	return { moved = 0, lastJumpVy = nil, glide = 0, sprint = 0, walljumps = 0, shots = 0, knock = 0, zoom = 0 }
end

local function show()
	if finished then
		stepLabel.Text = Lang.t("tuto.done_step")
		titleLabel.Text = Lang.t("tuto.done_title")
		textLabel.Text = ""
		panel.Size = UDim2.fromOffset(640, 130)
		playButton.Visible, menuButton.Visible, skip.Visible = true, true, false
		return
	end
	local step = STEPS[index]
	stepLabel.Text = Lang.t("tuto.step", index, #STEPS)
	titleLabel.Text = stepTitle(step)
	titleLabel.TextColor3 = if step.id == "rail" then RAIL else Color3.new(1, 1, 1)
	textLabel.Text = stepText(step)
	panel.Size = UDim2.fromOffset(640, 118)
	playButton.Visible, menuButton.Visible, skip.Visible = false, false, true
end

local function reset()
	index, finished = 1, false
	st = newState()
	lastPos, jumpMaxVy = nil, nil
	show()
end

local function advance()
	Sfx.play("kill", -4)
	-- Petit flash du cadre pour marquer la réussite.
	stroke.Transparency = 0
	stroke.Color = Color3.fromRGB(120, 255, 140)
	TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 0.4, Color = ACCENT }):Play()
	index += 1
	st = newState()
	jumpMaxVy = nil
	if index > #STEPS then
		finished = true
		Sfx.play("win")
	end
	show()
end

playButton.MouseButton1Click:Connect(function()
	lobby:FireServer("play")
end)
menuButton.MouseButton1Click:Connect(function()
	lobby:FireServer("menu")
end)
skip.MouseButton1Click:Connect(function()
	finished = true
	show()
end)

-- On a tiré (branché par Main sur Weapons.onFire).
function Tutorial.noteFire()
	if st then
		st.shots += 1
	end
end

local active = false

-- À chaque image : suivi des gestes du joueur.
function Tutorial.update(dt: number, ctrl)
	local inTuto = player:GetAttribute("Mode") == "tutorial"
	if inTuto ~= active then
		active = inTuto
		gui.Enabled = inTuto
		if inTuto then
			reset()
		end
	end
	if not active or finished or not ctrl or not ctrl.root.Parent or not st then
		return
	end
	-- Les touches ont pu changer : on rafraîchit le texte.
	textLabel.Text = stepText(STEPS[index])
	titleLabel.Text = stepTitle(STEPS[index])

	local feet = ctrl:feetPosition()
	if lastPos and ctrl.onFloor then
		st.moved += Vector2.new(feet.X - lastPos.X, feet.Z - lastPos.Z).Magnitude
	end
	lastPos = feet

	-- Sauts : on mesure la vitesse verticale max atteinte pendant le saut.
	if ctrl.onJump then
		jumpMaxVy = ctrl.vel.Y
	elseif jumpMaxVy then
		jumpMaxVy = math.max(jumpMaxVy, ctrl.vel.Y)
		if ctrl.onFloor and ctrl.vel.Y <= 0.5 then
			st.lastJumpVy = jumpMaxVy
			jumpMaxVy = nil
		end
	end
	if ctrl.gliding then
		st.glide += dt
	end
	local hs = Vector2.new(ctrl.vel.X, ctrl.vel.Z).Magnitude
	if ctrl.onFloor and (ctrl.sprinting or (ctrl.surface == "sprint" and hs > 12)) then
		st.sprint += dt
	end
	if ctrl.onWalljump then
		st.walljumps += 1
	end
	if ctrl.onKnock and ctrl.onKnock > st.knock then
		st.knock = ctrl.onKnock
	end
	if ctrl.zooming then
		st.zoom += dt
	end

	if STEPS[index].done(st) then
		advance()
	end
end

return Tutorial
