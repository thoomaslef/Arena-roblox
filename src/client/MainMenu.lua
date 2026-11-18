-- Écran d'accueil : titre, présentation des deux camps, boutons JOUER / TUTORIEL / RÉGLAGES,
-- carte du joueur (niveau, XP, rang de la saison, statistiques) et classement mondial.
-- Affiché tant que le joueur est en mode « menu » (attribut Mode posé par le serveur).
-- Pendant ce temps, la caméra tourne lentement autour de l'arène.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Lang = require(Shared:WaitForChild("Lang"))
local Input = require(script.Parent.Input)
local FpsCamera = require(script.Parent.FpsCamera)
local UiScale = require(script.Parent.UiScale)

local S = Config.STUDS_PER_METER
local TEAMS = Config.Teams
local ACCENT = Color3.fromRGB(255, 200, 80)
local CARD = Color3.fromRGB(22, 25, 36)

local player = Players.LocalPlayer
local lobby = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby") :: RemoteEvent
local match = ReplicatedStorage:WaitForChild("Match")

local MainMenu = {
	onSettings = nil :: (() -> ())?, -- branché par Main (ouvre le menu Réglages)
}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleMainMenu"
gui.AutoLocalize = false -- nos textes sont déjà traduits (Lang) : pas de traduction auto de Roblox
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

local function text(parent: Instance, props): TextLabel
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.Parent = parent
	return make("TextLabel", props)
end

-- Voile sombre (l'arène reste visible au centre).
local shade = make("Frame", {
	BackgroundColor3 = Color3.fromRGB(8, 10, 16),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
})
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.45, 0.45),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 0.25),
	}),
	Parent = shade,
})

-- Colonne de gauche : titre, présentation, boutons ----------------------------------------
local column = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 60, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(560, 600),
	Parent = gui,
})

text(column, { Text = "CAVALE", Font = Enum.Font.GothamBlack, TextSize = 96, TextColor3 = ACCENT, TextStrokeTransparency = 0.6, Size = UDim2.new(1, 0, 0, 100) })
Lang.bind(text(column, { Font = Enum.Font.GothamBold, TextSize = 20, Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, 0, 0, 26) }), "menu.subtitle")
Lang.bind(text(column, {
	Font = Enum.Font.Gotham,
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(205, 210, 225),
	Position = UDim2.fromOffset(4, 134),
	Size = UDim2.new(1, -10, 0, 44),
	TextYAlignment = Enum.TextYAlignment.Top,
}), "menu.pitch")

local function teamCard(team: number, x: number, key: string)
	local card = make("Frame", {
		BackgroundColor3 = TEAMS[team].color,
		BackgroundTransparency = 0.2,
		Position = UDim2.new(x, 0, 0, 192),
		Size = UDim2.new(0.48, 0, 0, 96),
		Parent = column,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
	local name = text(card, { Font = Enum.Font.GothamBlack, TextSize = 22, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 26) })
	local function setName()
		name.Text = Lang.teamName(team):upper()
	end
	setName()
	Lang.changed:Connect(setName)
	Lang.bind(text(card, {
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 1, -42),
		TextYAlignment = Enum.TextYAlignment.Top,
	}), key)
end
teamCard(0, 0, "menu.cops")
teamCard(1, 0.52, "menu.robbers")

local function bigButton(key: string, y: number, primary: boolean): TextButton
	local b = make("TextButton", {
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
	Lang.bind(b, key)
	return b
end
local playButton = bigButton("menu.play", 312, true)
local tutoButton = bigButton("menu.tutorial", 396, false)
local settingsButton = bigButton("menu.settings", 396, false)
settingsButton.Position = UDim2.new(0.52, 0, 0, 396)

Lang.bind(text(column, {
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(180, 186, 200),
	Position = UDim2.fromOffset(2, 460),
	Size = UDim2.new(1, 0, 0, 40),
	TextYAlignment = Enum.TextYAlignment.Top,
}), "menu.hint")

-- Colonne de droite : carte du joueur et classement mondial --------------------------------
local side = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -60, 0.5, 0),
	Size = UDim2.fromOffset(380, 560),
	Parent = gui,
})

local profileCard = make("Frame", { BackgroundColor3 = CARD, BackgroundTransparency = 0.1, Size = UDim2.new(1, 0, 0, 200), Parent = side })
make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = profileCard })
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), Parent = profileCard })

local nameLabel = text(profileCard, { Text = player.DisplayName, Font = Enum.Font.GothamBlack, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd })
local levelLabel = text(profileCard, { Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = ACCENT, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(0.5, 0, 0, 20) })
local xpLabel = text(profileCard, { Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Color3.fromRGB(190, 195, 210), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.new(0.5, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
local xpBack = make("Frame", { BackgroundColor3 = Color3.fromRGB(45, 50, 66), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 10), Parent = profileCard })
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = xpBack })
local xpFill = make("Frame", { BackgroundColor3 = ACCENT, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = xpBack })
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = xpFill })

local seasonLabel = text(profileCard, { Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(170, 176, 192), Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 18) })
local rankLabel = text(profileCard, { Font = Enum.Font.GothamBlack, TextSize = 24, Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 30), TextWrapped = true })
local statsLabel = text(profileCard, { Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Color3.fromRGB(190, 195, 210), Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 20) })

local boardCard = make("Frame", { BackgroundColor3 = CARD, BackgroundTransparency = 0.1, Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 340), Parent = side })
make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = boardCard })
make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), Parent = boardCard })
Lang.bind(text(boardCard, { Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = ACCENT, Size = UDim2.new(1, 0, 0, 22) }), "menu.leaderboard")
local boardRows: { TextLabel } = {}
for i = 1, Config.Ranked.LEADERBOARD_SIZE do
	boardRows[i] = text(boardCard, { Font = Enum.Font.GothamMedium, TextSize = 15, Position = UDim2.fromOffset(0, 30 + (i - 1) * 29), Size = UDim2.new(1, 0, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd })
end

local function refreshProfile()
	local level = player:GetAttribute("Level") or 1
	local xp, xpNext = player:GetAttribute("XP") or 0, player:GetAttribute("XPNext") or Config.xpForLevel(1)
	levelLabel.Text = Lang.t("menu.level", level)
	xpLabel.Text = Lang.t("menu.xp", xp, xpNext)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / math.max(1, xpNext), 0, 1), 1)
	seasonLabel.Text = Lang.t("menu.ranked", Config.Ranked.SEASON)
	local rankKey = player:GetAttribute("RankKey")
	local rating = player:GetAttribute("Rating") or Config.Ranked.START_RATING
	if rankKey == nil or rankKey == "unranked" then
		local left = Config.Ranked.PLACEMENT_GAMES - (player:GetAttribute("RankedGames") or 0)
		rankLabel.Text = Lang.t("menu.unranked", math.max(1, left))
		rankLabel.TextSize = 15
		rankLabel.TextColor3 = Color3.fromRGB(200, 205, 215)
	else
		local _, color = Config.rankFor(rating)
		rankLabel.Text = Lang.t("menu.rating", Lang.t("rank." .. rankKey), rating)
		rankLabel.TextSize = 24
		rankLabel.TextColor3 = color
	end
	statsLabel.Text = Lang.t("menu.stats", player:GetAttribute("Wins") or 0, player:GetAttribute("Matches") or 0, player:GetAttribute("Accuracy") or 0)
	nameLabel.Text = player.DisplayName
end

local function refreshBoard()
	local raw = match:GetAttribute("Leaderboard")
	local list = {}
	if type(raw) == "string" then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(data) == "table" then
			list = data
		end
	end
	for i, row in boardRows do
		local e = list[i]
		if e then
			local rankKey, color = Config.rankFor(e.rating or 0)
			row.Text = ("%d.  %s  ·  %s %d"):format(i, tostring(e.name), Lang.t("rank." .. rankKey), e.rating or 0)
			row.TextColor3 = if e.name == player.Name then ACCENT else color
		elseif i == 1 then
			row.Text = Lang.t("menu.lb_empty")
			row.TextColor3 = Color3.fromRGB(170, 176, 192)
		else
			row.Text = ""
		end
	end
end

for _, attr in { "Level", "XP", "XPNext", "Rating", "RankKey", "RankedGames", "Wins", "Matches", "Accuracy" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshProfile)
end
match:GetAttributeChangedSignal("Leaderboard"):Connect(refreshBoard)
Lang.changed:Connect(function()
	refreshProfile()
	refreshBoard()
end)
refreshProfile()
refreshBoard()

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
