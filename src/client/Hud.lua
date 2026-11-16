-- HUD minimal de l'étape 2 : réticule, barre d'endurance, infos de réglage,
-- et bouton de mobilité sur écran tactile.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

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
end

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

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
