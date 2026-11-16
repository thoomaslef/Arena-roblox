-- HUD minimal : réticule, endurance, charges de roquette, vies, marqueur de touche,
-- « +1 », infos de réglage, et boutons tactiles (mobilité, tir).

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Input = require(script.Parent.Input)

local Hud = {}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleHud"
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

-- Réticule : un point et quatre traits.
local cross = frame({ Name = "Crosshair", Size = UDim2.fromOffset(4, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui })
Instance.new("UICorner", cross).CornerRadius = UDim.new(1, 0)
for _, d in { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) } do
	frame({
		Size = if d.X ~= 0 then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, d.X * 11, 0.5, d.Y * 11),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
end

-- Endurance.
local staminaBack = frame({ Name = "Stamina", Size = UDim2.fromOffset(260, 10), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -36), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = gui })
Instance.new("UICorner", staminaBack).CornerRadius = UDim.new(1, 0)
local staminaFill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 120), Parent = staminaBack })
Instance.new("UICorner", staminaFill).CornerRadius = UDim.new(1, 0)

-- Infos de réglage (vitesse, état) : pratique pour comparer avec Godot.
local debugLabel = Instance.new("TextLabel")
debugLabel.Name = "Debug"
debugLabel.BackgroundTransparency = 1
debugLabel.Position = UDim2.fromOffset(12, 60)
debugLabel.Size = UDim2.fromOffset(360, 80)
debugLabel.Font = Enum.Font.Code
debugLabel.TextSize = 14
debugLabel.TextColor3 = Color3.new(1, 1, 1)
debugLabel.TextStrokeTransparency = 0.5
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.TextYAlignment = Enum.TextYAlignment.Top
debugLabel.Parent = gui

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

-- Voile rouge quand on est touché.
local damageFlash = frame({ Name = "DamageFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 40), BackgroundTransparency = 1, ZIndex = 0, Active = false, Parent = gui })

-- Bouton de mobilité tactile (en bas à droite).
if UserInputService.TouchEnabled then
	local btn = Instance.new("TextButton")
	btn.Name = "Mobility"
	btn.Text = "SAUT"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BackgroundColor3 = Color3.new(0, 0, 0)
	btn.BackgroundTransparency = 0.45
	btn.AutoButtonColor = false
	btn.Size = UDim2.fromOffset(96, 96)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -40, 1, -60)
	btn.Parent = gui
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Input.setTouchMobility(true)
			btn.BackgroundTransparency = 0.2
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Input.setTouchMobility(false)
			btn.BackgroundTransparency = 0.45
		end
	end)

	local fire = btn:Clone()
	fire.Name = "Fire"
	fire.Text = "TIR"
	fire.Size = UDim2.fromOffset(84, 84)
	fire.Position = UDim2.new(1, -150, 1, -150)
	fire.BackgroundColor3 = Color3.fromRGB(120, 40, 10)
	fire.Parent = gui
	fire.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Input.setTouchFire(true)
			fire.BackgroundTransparency = 0.2
		end
	end)
	fire.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Input.setTouchFire(false)
			fire.BackgroundTransparency = 0.45
		end
	end)
end

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

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

function Hud.updateWeapons(charges: number)
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
