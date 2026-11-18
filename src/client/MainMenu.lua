-- Écran d'accueil : titre, présentation des deux camps, boutons JOUER / TUTORIEL / RÉGLAGES.
-- Affiché tant que le joueur est en mode « menu » (attribut Mode posé par le serveur).
-- Pendant ce temps, la caméra tourne lentement autour de l'arène.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Input = require(script.Parent.Input)
local FpsCamera = require(script.Parent.FpsCamera)
local UiScale = require(script.Parent.UiScale)

local S = Config.STUDS_PER_METER
local TEAMS = Config.Teams
local ACCENT = Color3.fromRGB(255, 200, 80)

local player = Players.LocalPlayer
local lobby = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby") :: RemoteEvent
local match = ReplicatedStorage:WaitForChild("Match")

local MainMenu = {
	onSettings = nil :: (() -> ())?, -- branché par Main (ouvre le menu Réglages)
}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleMainMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
UiScale.attach(gui)

local function make(className: string, props): any
	local o = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(o :: any)[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end

-- Voile sombre à gauche (l'arène reste visible à droite).
local shade = make("Frame", {
	BackgroundColor3 = Color3.fromRGB(8, 10, 16),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
})
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.55, 0.35),
		NumberSequenceKeypoint.new(1, 0.85),
	}),
	Parent = shade,
})

local column = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 60, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(560, 600),
	Parent = gui,
})

make("TextLabel", {
	Text = "CAVALE",
	Font = Enum.Font.GothamBlack,
	TextSize = 96,
	TextColor3 = ACCENT,
	TextStrokeTransparency = 0.6,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 100),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = column,
})
make("TextLabel", {
	Text = "RÈGLEMENT DE COMPTES  ·  1 CONTRE 1",
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(4, 100),
	Size = UDim2.new(1, 0, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = column,
})
make("TextLabel", {
	Text = "Roquettes, rocket jumps et gaz lacrymo qui se resserre. 3 vies par manche, "
		.. "le dernier debout marque le point. Premier à 11 points (2 d'écart) !",
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(205, 210, 225),
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(4, 134),
	Size = UDim2.new(1, -10, 0, 44),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = column,
})

-- Cartes des deux camps.
local function teamCard(team: number, x: number, lines: string)
	local card = make("Frame", {
		BackgroundColor3 = TEAMS[team].color,
		BackgroundTransparency = 0.2,
		Position = UDim2.new(x, 0, 0, 192),
		Size = UDim2.new(0.48, 0, 0, 96),
		Parent = column,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
	make("TextLabel", {
		Text = TEAMS[team].name:upper(),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	make("TextLabel", {
		Text = lines,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 1, -42),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
end
teamCard(0, 0, "Sirène au départ. On serre, on coffre, on menotte : la loi, c'est vous.")
teamCard(1, 0.52, "Coup de sifflet au départ. On fume, on efface, on file : jamais pris.")

local function bigButton(text: string, y: number, primary: boolean): TextButton
	local b = make("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = if primary then 30 else 22,
		TextColor3 = if primary then Color3.fromRGB(20, 20, 28) else Color3.new(1, 1, 1),
		BackgroundColor3 = if primary then ACCENT else Color3.fromRGB(40, 44, 58),
		AutoButtonColor = true,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(if primary then 1 else 0.48, 0, 0, if primary then 70 else 54),
		Parent = column,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
	return b
end
local playButton = bigButton("JOUER", 312, true)
local tutoButton = bigButton("TUTORIEL", 396, false)
local settingsButton = bigButton("RÉGLAGES", 396, false)
settingsButton.Position = UDim2.new(0.52, 0, 0, 396)

make("TextLabel", {
	Text = "Nouveau ? Fais le tutoriel (2 minutes) : le saut, le plané et le sprint se font avec un seul bouton.",
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(180, 186, 200),
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(2, 460),
	Size = UDim2.new(1, 0, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = column,
})

gui.Parent = player:WaitForChild("PlayerGui")

-- Logique ------------------------------------------------------------------------------------
local visible = false
local orbitT = 0

local function isMenu(): boolean
	local mode = player:GetAttribute("Mode")
	return mode == nil or mode == "menu"
end

function MainMenu.isOpen(): boolean
	return visible
end

local function setVisible(v: boolean)
	if v == visible then
		return
	end
	visible = v
	gui.Enabled = v
	Input.menuOpen = v
	FpsCamera.cursorFree = v
end

playButton.MouseButton1Click:Connect(function()
	lobby:FireServer("play")
end)
tutoButton.MouseButton1Click:Connect(function()
	lobby:FireServer("tutorial")
end)
settingsButton.MouseButton1Click:Connect(function()
	if MainMenu.onSettings then
		MainMenu.onSettings()
	end
end)

-- Retour au menu (depuis les Réglages ou la fin du tutoriel).
function MainMenu.backToMenu()
	lobby:FireServer("menu")
end

-- À chaque image : visibilité selon le mode, et caméra qui tourne autour de l'arène.
function MainMenu.update(dt: number, settingsOpen: boolean)
	setVisible(isMenu())
	if not visible then
		return
	end
	-- Le menu Réglages peut s'ouvrir par-dessus : on lui laisse la souris.
	Input.menuOpen = true
	FpsCamera.cursorFree = true
	gui.Enabled = not settingsOpen
	local cam = Workspace.CurrentCamera
	local center = match:GetAttribute("GasCenter")
	local r0 = match:GetAttribute("GasR0")
	if cam and typeof(center) == "Vector3" and type(r0) == "number" then
		orbitT += dt
		local a = orbitT * 0.08
		local radius = r0 * 1.15
		local eye = Vector3.new(center.X + math.cos(a) * radius, center.Y + 16, center.Z + math.sin(a) * radius)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 60
		cam.CFrame = CFrame.lookAt(eye * S, (center + Vector3.new(0, 1, 0)) * S)
	end
end

setVisible(isMenu())
gui.Enabled = visible

return MainMenu
