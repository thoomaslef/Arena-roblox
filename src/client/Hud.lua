-- HUD minimal : réticule, endurance, charges de roquette, vies, marqueur de touche,
-- « +1 », infos de réglage, joystick tactile.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Lang = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("Lang"))
local Input = require(script.Parent.Input)
local Prefs = require(script.Parent.Prefs)
local UiScale = require(script.Parent.UiScale)

local Hud = {}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleHud"
gui.AutoLocalize = false -- nos textes sont déjà traduits (Lang) : pas de traduction auto de Roblox
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function frame(props): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
end

-- Réticule (forme et couleur réglables : onglet JEU des Réglages).
local crosshair = frame({ Name = "Crosshair", Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
local function buildCrosshair()
	crosshair:ClearAllChildren()
	local color = Prefs.COLOR_VALUES[Prefs.crosshairColor] or Color3.new(1, 1, 1)
	local shape = Prefs.crosshair
	local function piece(size: UDim2, pos: UDim2, round: boolean)
		local f = frame({ Size = size, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, BackgroundColor3 = color, Parent = crosshair })
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.55
		stroke.Thickness = 1
		stroke.Parent = f
		if round then
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		end
	end
	if shape == "dot" or shape == "crossdot" then
		piece(UDim2.fromOffset(5, 5), UDim2.fromScale(0.5, 0.5), true)
	end
	if shape == "cross" or shape == "crossdot" then
		for _, d in { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) } do
			piece(if d.X ~= 0 then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8), UDim2.new(0.5, d.X * 11, 0.5, d.Y * 11), false)
		end
		if shape == "cross" then
			piece(UDim2.fromOffset(3, 3), UDim2.fromScale(0.5, 0.5), true)
		end
	elseif shape == "circle" then
		local ring = frame({ Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = crosshair })
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = 2
		s.Parent = ring
		piece(UDim2.fromOffset(3, 3), UDim2.fromScale(0.5, 0.5), true)
	end
end
buildCrosshair()
Prefs.changed:Connect(buildCrosshair)

-- Endurance.
local staminaBack = frame({ Name = "Stamina", Size = UDim2.fromOffset(260, 10), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -36), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = gui })
Instance.new("UICorner", staminaBack).CornerRadius = UDim.new(1, 0)
local staminaFill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 120), Parent = staminaBack })
Instance.new("UICorner", staminaFill).CornerRadius = UDim.new(1, 0)

-- Infos de réglage (vitesse, état) : pratique pour comparer avec Godot.
local debugLabel = Instance.new("TextLabel")
debugLabel.Name = "Debug"
debugLabel.BackgroundTransparency = 1
debugLabel.Position = UDim2.fromOffset(12, 220) -- sous le menu et le chat de Roblox
debugLabel.Size = UDim2.fromOffset(360, 80)
debugLabel.Font = Enum.Font.Code
debugLabel.TextSize = 14
debugLabel.TextColor3 = Color3.new(1, 1, 1)
debugLabel.TextStrokeTransparency = 0.5
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.TextYAlignment = Enum.TextYAlignment.Top
debugLabel.Parent = gui
-- Seulement dans Studio : en jeu publié, les joueurs ne voient pas ces infos de réglage.
debugLabel.Visible = game:GetService("RunService"):IsStudio()

-- Charges de roquette : 5 segments qui se remplissent.
local CHARGES = Config.Rocket.CHARGES
local chargeBar = frame({ Name = "Charges", Size = UDim2.fromOffset(260, 14), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -54), BackgroundTransparency = 1, Parent = gui })
local chargeLayout = Instance.new("UIListLayout")
chargeLayout.FillDirection = Enum.FillDirection.Horizontal
chargeLayout.Padding = UDim.new(0, 4)
chargeLayout.Parent = chargeBar
local chargeFills = {}
for i = 1, CHARGES do
	local seg = frame({ Size = UDim2.new(1 / CHARGES, -4 + 4 / CHARGES, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, LayoutOrder = i, Parent = chargeBar })
	Instance.new("UICorner", seg).CornerRadius = UDim.new(0, 3)
	local fill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 160, 70), Parent = seg })
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
	chargeFills[i] = fill
end

-- Nom de l'arme en main et charge du Rail (un segment cyan).
local weaponLabel = Instance.new("TextLabel")
weaponLabel.Name = "Weapon"
weaponLabel.BackgroundTransparency = 1
weaponLabel.AnchorPoint = Vector2.new(0, 1)
weaponLabel.Position = UDim2.new(0.5, 140, 1, -50)
weaponLabel.Size = UDim2.fromOffset(120, 22)
weaponLabel.Font = Enum.Font.GothamBlack
weaponLabel.TextSize = 16
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.TextColor3 = Color3.new(1, 1, 1)
weaponLabel.TextStrokeTransparency = 0.4
weaponLabel.Text = Lang.t("hud.rocket")
weaponLabel.Parent = gui

local railBack = frame({ Name = "RailCharge", Size = UDim2.fromOffset(260, 14), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -54), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Visible = false, Parent = gui })
Instance.new("UICorner", railBack).CornerRadius = UDim.new(0, 3)
local railFill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Config.Rail.BEAM_COLOR, Parent = railBack })
Instance.new("UICorner", railFill).CornerRadius = UDim.new(0, 3)

-- Vies : 3 pastilles.
local LIVES = Config.Joust.LIVES
local livesRow = frame({ Name = "Lives", Size = UDim2.fromOffset(LIVES * 26, 20), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), BackgroundTransparency = 1, Parent = gui })
local livesLayout = Instance.new("UIListLayout")
livesLayout.FillDirection = Enum.FillDirection.Horizontal
livesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
livesLayout.Padding = UDim.new(0, 6)
livesLayout.Parent = livesRow
local lifePips = {}
for i = 1, LIVES do
	local pip = frame({ Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.fromRGB(255, 90, 110), LayoutOrder = i, Parent = livesRow })
	Instance.new("UICorner", pip).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = pip
	lifePips[i] = pip
end

-- Marqueur de touche (un X autour du réticule) et « +1 ».
local hitMarker = frame({ Name = "HitMarker", Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
local hitLines = {}
for _, rot in { 45, -45 } do
	local l = frame({ Size = UDim2.fromOffset(34, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = rot, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = hitMarker })
	table.insert(hitLines, l)
end

local plusOne = Instance.new("TextLabel")
plusOne.Name = "PlusOne"
plusOne.BackgroundTransparency = 1
plusOne.AnchorPoint = Vector2.new(0, 0.5)
plusOne.Position = UDim2.new(0.5, 26, 0.5, -22)
plusOne.Size = UDim2.fromOffset(80, 30)
plusOne.Font = Enum.Font.GothamBlack
plusOne.TextSize = 26
plusOne.Text = "+1"
plusOne.TextColor3 = Color3.fromRGB(255, 220, 90)
plusOne.TextStrokeTransparency = 0.3
plusOne.TextTransparency = 1
plusOne.TextStrokeColor3 = Color3.new(0, 0, 0)
plusOne.TextXAlignment = Enum.TextXAlignment.Left
plusOne.Parent = gui
local hitCount = 0
local lastHitTime = 0

-- Gros message au centre : « DERNIÈRE VIE ! », « ÉLIMINÉ ! ».
local bigHit = Instance.new("TextLabel")
bigHit.Name = "BigHit"
bigHit.BackgroundTransparency = 1
bigHit.AnchorPoint = Vector2.new(0.5, 0.5)
bigHit.Position = UDim2.new(0.5, 0, 0.5, 70)
bigHit.Size = UDim2.fromOffset(500, 50)
bigHit.Font = Enum.Font.GothamBlack
bigHit.TextSize = 34
bigHit.TextStrokeTransparency = 0.2
bigHit.TextTransparency = 1
bigHit.TextStrokeColor3 = Color3.new(0, 0, 0)
bigHit.Text = ""
bigHit.Parent = gui
local bigScale = Instance.new("UIScale")
bigScale.Parent = bigHit

local function popText(text: string, color: Color3)
	bigHit.Text = text
	bigHit.TextColor3 = color
	bigHit.TextTransparency = 0
	bigHit.TextStrokeTransparency = 0.2
	bigScale.Scale = 1.6
	TweenService:Create(bigScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(0.7, function()
		if bigHit.Text == text then
			TweenService:Create(bigHit, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
Hud.popText = popText

-- Flash de l'écran (couleurs plus contrastées un instant) à l'élimination.
local Lighting = game:GetService("Lighting")
local punchCC = Instance.new("ColorCorrectionEffect")
punchCC.Name = "CavaleKillPunch"
punchCC.Enabled = true
punchCC.Parent = Lighting

-- Voile rouge quand on est touché.
local damageFlash = frame({ Name = "DamageFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 40), BackgroundTransparency = 1, ZIndex = 0, Active = false, Parent = gui })

-- Joystick tactile (dessiné là où le pouce se pose, voir Input.stick).
local stickBase = frame({ Name = "StickBase", Size = UDim2.fromOffset(120, 120), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Visible = false, Parent = gui })
Instance.new("UICorner", stickBase).CornerRadius = UDim.new(1, 0)
local stickKnob = frame({ Name = "StickKnob", Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, Visible = false, Parent = gui })
Instance.new("UICorner", stickKnob).CornerRadius = UDim.new(1, 0)

-- (Les boutons tactiles sont dans TouchControls.)

UiScale.attach(gui)
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

function Hud.setVisible(v: boolean)
	gui.Enabled = v
end
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- Flash du personnage touché (blanc ; rouge à l'élimination).
local function flashModel(model: Instance?, killed: boolean)
	if not model or not model:IsA("Model") or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = if killed then Color3.fromRGB(255, 60, 60) else Color3.new(1, 1, 1)
	h.OutlineColor = h.FillColor
	h.FillTransparency = 0.2
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	TweenService:Create(h, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(h, 0.3)
end

-- Touche confirmée par le serveur : marqueur, « +1 », flash de la cible, messages.
function Hud.onHit(killed: boolean, model: Instance?, livesLeft: number?)
	Hud.showHit(killed)
	flashModel(model, killed)
	if killed then
		popText(Lang.t("hud.eliminated"), Color3.fromRGB(255, 80, 80))
		-- « Coup de poing » visuel : contraste et saturation qui claquent puis reviennent.
		punchCC.Contrast, punchCC.Saturation, punchCC.Brightness = 0.35, 0.4, 0.08
		TweenService:Create(punchCC, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Contrast = 0, Saturation = 0, Brightness = 0 }):Play()
	elseif livesLeft == 1 then
		popText(Lang.t("hud.lastlife"), Color3.fromRGB(255, 200, 80))
	end
end

function Hud.showHit(killed: boolean)
	local now = os.clock()
	if now - lastHitTime > 3 then
		hitCount = 0
	end
	lastHitTime = now
	hitCount += 1
	local color = if killed then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
	for _, l in hitLines do
		l.BackgroundColor3 = color
		l.BackgroundTransparency = 0
		TweenService:Create(l, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end
	plusOne.Text = if hitCount > 1 then ("+%d"):format(hitCount) else "+1"
	plusOne.TextTransparency = 0
	plusOne.TextStrokeTransparency = 0.3
	plusOne.Position = UDim2.new(0.5, 26, 0.5, -22)
	TweenService:Create(plusOne, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Position = UDim2.new(0.5, 26, 0.5, -46),
	}):Play()
end

function Hud.showDamaged()
	damageFlash.BackgroundTransparency = 0.55
	TweenService:Create(damageFlash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

function Hud.updateWeapons(charges: number, weapon: string?, railCharges: number?)
	local rail = weapon == "rail"
	chargeBar.Visible = not rail
	railBack.Visible = rail
	weaponLabel.Text = Lang.t(if rail then "hud.rail" else "hud.rocket")
	weaponLabel.TextColor3 = if rail then Config.Rail.BEAM_COLOR else Color3.new(1, 1, 1)
	local rc = math.clamp(railCharges or 0, 0, 1)
	railFill.Size = UDim2.fromScale(rc, 1)
	railFill.BackgroundTransparency = if rc < 1 then 0.45 else 0
	for i, fill in chargeFills do
		local k = math.clamp(charges - (i - 1), 0, 1)
		fill.Size = UDim2.fromScale(k, 1)
		fill.BackgroundTransparency = if k < 1 then 0.45 else 0
	end
	local lives = Players.LocalPlayer:GetAttribute("Lives")
	lives = if type(lives) == "number" then lives else LIVES
	for i, pip in lifePips do
		pip.BackgroundTransparency = if i <= lives then 0 else 0.85
	end
end

function Hud.update(ctrl)
	local st = Input.stick
	stickBase.Visible = st.active
	stickKnob.Visible = st.active
	if st.active then
		local d = st.pos - st.origin
		if d.Magnitude > st.radius then
			d = d.Unit * st.radius
		end
		-- Le HUD est mis à l'échelle (UiScale) : on ramène la position du doigt à cette échelle.
		local k = UiScale.factor()
		stickBase.Position = UDim2.fromOffset(st.origin.X / k, st.origin.Y / k)
		stickKnob.Position = UDim2.fromOffset((st.origin.X + d.X) / k, (st.origin.Y + d.Y) / k)
	end
	if not ctrl then
		return
	end
	staminaFill.Size = UDim2.fromScale(math.clamp(ctrl.stamina, 0, 1), 1)
	staminaFill.BackgroundColor3 = if ctrl.stamina < 0.12 then Color3.fromRGB(255, 90, 70) else Color3.fromRGB(255, 230, 120)
	local v = ctrl.vel
	local hs = Vector3.new(v.X, 0, v.Z).Magnitude
	local state = if ctrl.onFloor then (if ctrl.sprinting then "sprint" else "sol") elseif ctrl.gliding then "plané" elseif ctrl.boosting then "saut (boost)" else "air"
	debugLabel.Text = ("vitesse  %5.1f m/s\nvertical %5.1f m/s\nétat     %s\nsurface  %s"):format(hs, v.Y, state, tostring(ctrl.surface))
end

return Hud
