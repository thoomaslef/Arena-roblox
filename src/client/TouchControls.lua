-- Boutons tactiles (téléphones, tablettes) : TIR et SAUT, en bas à droite, sous le pouce.
-- Leur taille suit la HAUTEUR de l'écran (gros sur téléphone, raisonnables sur tablette).
-- Le joystick de déplacement apparaît là où le pouce gauche se pose (Input / Hud).
-- Sur une plateforme Rail, le bouton SAUT devient ZOOM.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Input = require(script.Parent.Input)

local TouchControls = {}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleTouch"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Enabled = false

local function roundButton(name: string, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.4
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Parent = gui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.22, 0), UDim.new(0.22, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.3, 0), UDim.new(0.3, 0)
	pad.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	return b
end

local fire = roundButton("Fire", "TIR", Color3.fromRGB(190, 70, 20))
local mobility = roundButton("Mobility", "SAUT", Color3.fromRGB(20, 24, 34))

local function hold(b: TextButton, set: (boolean) -> ())
	local touches = 0
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches += 1
			set(true)
			b.BackgroundTransparency = 0.1
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches = math.max(0, touches - 1)
			if touches == 0 then
				set(false)
				b.BackgroundTransparency = 0.4
			end
		end
	end)
end
hold(fire, Input.setTouchFire)
hold(mobility, Input.setTouchMobility)

-- Placement selon la taille de l'écran : le pouce droit tombe entre les deux boutons.
local function layout()
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local h = vp.Y
	local big = math.clamp(h * 0.24, 80, 170) -- TIR
	local small = math.clamp(h * 0.19, 66, 130) -- SAUT
	fire.Size = UDim2.fromOffset(big, big)
	mobility.Size = UDim2.fromOffset(small, small)
	-- TIR un peu plus haut et plus à l'intérieur ; SAUT dans le coin.
	fire.Position = UDim2.new(1, -(small + big * 0.62 + 28), 1, -(big * 0.5 + small * 0.55 + 24))
	mobility.Position = UDim2.new(1, -(small * 0.5 + 28), 1, -(small * 0.5 + 28))
end
layout()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	layout()
end)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- À chaque image : visible en jeu sur écran tactile ; libellé ZOOM sur une plateforme Rail.
function TouchControls.update(ctrl, visible: boolean)
	gui.Enabled = visible and UserInputService.TouchEnabled and ctrl ~= nil
	if gui.Enabled then
		local onRail = ctrl.onFloor and ctrl.surface == "rail"
		mobility.Text = if onRail then "ZOOM" else "SAUT"
	end
end

return TouchControls
