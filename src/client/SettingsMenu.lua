-- Menu Réglages (touche P, ou bouton ⚙ en haut à droite), en deux onglets :
--   COMMANDES : 2 touches par action (clic sur une case puis appui sur la nouvelle touche ;
--               Échap : annuler, Retour arrière : effacer), sensibilité de la souris ;
--   JEU       : volume, champ de vision, sensibilités tactile et manette, réticule
--               (forme, couleur), langue.
-- Les réglages sont envoyés au serveur, qui les garde pour ton compte (DataStore).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lang"))
local Input = require(script.Parent.Input)
local Prefs = require(script.Parent.Prefs)
local FpsCamera = require(script.Parent.FpsCamera)
local UiScale = require(script.Parent.UiScale)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Settings") :: RemoteEvent

local SettingsMenu = {}

local ACCENT = Color3.fromRGB(255, 200, 80)
local BG = Color3.fromRGB(18, 20, 28)
local CELL = Color3.fromRGB(40, 44, 58)

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleSettings"
gui.AutoLocalize = false -- nos textes sont déjà traduits (Lang) : pas de traduction auto de Roblox
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
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

local function corner(o: Instance, r: number)
	make("UICorner", { CornerRadius = UDim.new(0, r), Parent = o })
end

-- Bouton ⚙ (toujours visible, utile sur mobile).
local gear = make("TextButton", {
	Name = "Gear",
	Text = "⚙",
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	Size = UDim2.fromOffset(40, 40),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Parent = gui,
})
corner(gear, 8)

local panel = make("Frame", {
	Name = "Panel",
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.05,
	Size = UDim2.fromOffset(600, 580),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Visible = false,
	Parent = gui,
})
corner(panel, 12)
make("UIStroke", { Color = ACCENT, Thickness = 2, Transparency = 0.4, Parent = panel })
make("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), Parent = panel })

local title = make("TextLabel", {
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextColor3 = ACCENT,
	BackgroundTransparency = 1,
	Size = UDim2.new(0.4, 0, 0, 32),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})
Lang.bind(title, "set.title")

-- Onglets.
local function tabButton(key: string, x: number): TextButton
	local b = make("TextButton", {
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = CELL,
		Position = UDim2.new(x, 0, 0, 2),
		Size = UDim2.new(0.28, 0, 0, 30),
		Parent = panel,
	})
	corner(b, 6)
	Lang.bind(b, key)
	return b
end
local tabControls = tabButton("set.tab_controls", 0.42)
local tabGame = tabButton("set.tab_game", 0.72)

local controlsPage = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -104), Parent = panel })
local gamePage = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -104), Visible = false, Parent = panel })

local hint = make("TextLabel", {
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(190, 195, 210),
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = controlsPage,
})
Lang.bind(hint, "set.hint")

local ROW_H = 36

local function rowLabel(page: Instance, key: string, y: number)
	local l = make("TextLabel", {
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(0.44, 0, 0, ROW_H),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = page,
	})
	Lang.bind(l, key)
end

-- Ligne « − valeur + » (ou « ‹ valeur › ») : getText donne la valeur affichée.
type Stepper = { refresh: () -> () }
local steppers: { Stepper } = {}
local function stepper(page: Instance, key: string, y: number, getText: () -> string, onPrev: () -> (), onNext: () -> (), arrows: boolean?)
	rowLabel(page, key, y)
	local function small(text: string, x: number, cb: () -> ()): TextButton
		local b = make("TextButton", {
			Text = text,
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = CELL,
			Position = UDim2.new(x, 0, 0, y),
			Size = UDim2.new(0.1, 0, 0, ROW_H),
			Parent = page,
		})
		corner(b, 6)
		b.MouseButton1Click:Connect(cb)
		return b
	end
	small(if arrows then "‹" else "−", 0.46, onPrev)
	local value = make("TextLabel", {
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = ACCENT,
		BackgroundTransparency = 1,
		Position = UDim2.new(0.57, 0, 0, y),
		Size = UDim2.new(0.32, 0, 0, ROW_H),
		Parent = page,
	})
	small(if arrows then "›" else "+", 0.9, onNext)
	local st = {
		refresh = function()
			value.Text = getText()
		end,
	}
	table.insert(steppers, st)
	st.refresh()
end

-- Onglet COMMANDES : touches.
local cells: { [string]: { TextButton } } = {}
local TOP = 24
for i, action in Input.ACTIONS do
	local y = TOP + (i - 1) * (ROW_H + 4)
	rowLabel(controlsPage, "act." .. action.id, y)
	cells[action.id] = {}
	for slot = 1, 2 do
		local b = make("TextButton", {
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = CELL,
			AutoButtonColor = true,
			Position = UDim2.new(0.46 + (slot - 1) * 0.28, 0, 0, y),
			Size = UDim2.new(0.26, 0, 0, ROW_H),
			Parent = controlsPage,
		})
		corner(b, 6)
		cells[action.id][slot] = b
	end
end

local saveToken = 0
local function save()
	-- On attend un peu avant d'envoyer, pour regrouper plusieurs changements.
	saveToken += 1
	local token = saveToken
	task.delay(1.5, function()
		if token == saveToken then
			local data = Input.save()
			data.prefs = Prefs.save()
			remote:FireServer("save", data)
		end
	end)
end

local sensY = TOP + #Input.ACTIONS * (ROW_H + 4) + 10
stepper(controlsPage, "set.sens", sensY, function()
	return ("%.2f"):format(Input.sensitivity)
end, function()
	Input.sensitivity = math.clamp(math.floor((Input.sensitivity - 0.05) * 100 + 0.5) / 100, 0.05, 5)
	save()
end, function()
	Input.sensitivity = math.clamp(math.floor((Input.sensitivity + 0.05) * 100 + 0.5) / 100, 0.05, 5)
	save()
end)

-- Onglet JEU.
local function cycle(list: { string }, current: string, dir: number): string
	local idx = 1
	for i, v in list do
		if v == current then
			idx = i
		end
	end
	return list[(idx - 1 + dir) % #list + 1]
end

local gy = 0
local function nextRow(): number
	local y = gy
	gy += ROW_H + 8
	return y
end
stepper(gamePage, "set.volume", nextRow(), function()
	return ("%d %%"):format(math.floor(Prefs.volume * 100 + 0.5))
end, function()
	Prefs.set("volume", Prefs.volume - 0.1)
	save()
end, function()
	Prefs.set("volume", Prefs.volume + 0.1)
	save()
end)
stepper(gamePage, "set.fov", nextRow(), function()
	return ("%d°"):format(Prefs.fov)
end, function()
	Prefs.set("fov", Prefs.fov - 5)
	save()
end, function()
	Prefs.set("fov", Prefs.fov + 5)
	save()
end)
stepper(gamePage, "set.sens_touch", nextRow(), function()
	return ("%.1f"):format(Prefs.sensTouch)
end, function()
	Prefs.set("sensTouch", Prefs.sensTouch - 0.1)
	save()
end, function()
	Prefs.set("sensTouch", Prefs.sensTouch + 0.1)
	save()
end)
stepper(gamePage, "set.sens_pad", nextRow(), function()
	return ("%.1f"):format(Prefs.sensPad)
end, function()
	Prefs.set("sensPad", Prefs.sensPad - 0.1)
	save()
end, function()
	Prefs.set("sensPad", Prefs.sensPad + 0.1)
	save()
end)
stepper(gamePage, "set.crosshair", nextRow(), function()
	return Lang.t("ch." .. Prefs.crosshair)
end, function()
	Prefs.set("crosshair", cycle(Prefs.CROSSHAIRS, Prefs.crosshair, -1))
	save()
end, function()
	Prefs.set("crosshair", cycle(Prefs.CROSSHAIRS, Prefs.crosshair, 1))
	save()
end, true)
stepper(gamePage, "set.crosshair_color", nextRow(), function()
	return Lang.t("col." .. Prefs.crosshairColor)
end, function()
	Prefs.set("crosshairColor", cycle(Prefs.COLORS, Prefs.crosshairColor, -1))
	save()
end, function()
	Prefs.set("crosshairColor", cycle(Prefs.COLORS, Prefs.crosshairColor, 1))
	save()
end, true)
stepper(gamePage, "set.language", nextRow(), function()
	return Lang.t("lang." .. Prefs.language)
end, function()
	Prefs.set("language", cycle(Lang.LANGUAGES, Prefs.language, -1))
	save()
end, function()
	Prefs.set("language", cycle(Lang.LANGUAGES, Prefs.language, 1))
	save()
end, true)

-- Bas : réinitialiser / menu principal / fermer.
local function bottomButton(key: string, x: number, color: Color3): TextButton
	local b = make("TextButton", {
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(x, 0, 1, 0),
		Size = UDim2.new(0.32, 0, 0, 40),
		Parent = panel,
	})
	corner(b, 8)
	Lang.bind(b, key)
	return b
end
local resetButton = bottomButton("set.reset", 0, CELL)
local menuButton = bottomButton("set.menu", 0.34, CELL)
local closeButton = bottomButton("set.close", 0.68, Color3.fromRGB(200, 120, 30))

gui.Parent = player:WaitForChild("PlayerGui")

-- Affichage ---------------------------------------------------------------------------------
local waiting: { id: string, slot: number }? = nil
local page = "controls"

local function refresh()
	for id, row in cells do
		for slot, b in row do
			if waiting and waiting.id == id and waiting.slot == slot then
				b.Text = Lang.t("set.press")
				b.BackgroundColor3 = ACCENT
				b.TextColor3 = BG
			else
				b.Text = Input.pretty(Input.bindings[id][slot])
				b.BackgroundColor3 = CELL
				b.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end
	for _, st in steppers do
		st.refresh()
	end
	controlsPage.Visible = page == "controls"
	gamePage.Visible = page == "game"
	resetButton.Visible = page == "controls"
	tabControls.BackgroundColor3 = if page == "controls" then ACCENT else CELL
	tabControls.TextColor3 = if page == "controls" then BG else Color3.new(1, 1, 1)
	tabGame.BackgroundColor3 = if page == "game" then ACCENT else CELL
	tabGame.TextColor3 = if page == "game" then BG else Color3.new(1, 1, 1)
end
Prefs.changed:Connect(refresh)
Lang.changed:Connect(refresh)

function SettingsMenu.setOpen(open: boolean)
	panel.Visible = open
	Input.menuOpen = open
	FpsCamera.cursorFree = open
	waiting = nil
	refresh()
end

function SettingsMenu.toggle()
	SettingsMenu.setOpen(not panel.Visible)
end

function SettingsMenu.isOpen(): boolean
	return panel.Visible
end

tabControls.MouseButton1Click:Connect(function()
	page = "controls"
	waiting = nil
	refresh()
end)
tabGame.MouseButton1Click:Connect(function()
	page = "game"
	waiting = nil
	refresh()
end)

for id, row in cells do
	for slot, b in row do
		b.MouseButton1Click:Connect(function()
			waiting = { id = id, slot = slot }
			refresh()
		end)
	end
end

resetButton.MouseButton1Click:Connect(function()
	Input.resetBindings()
	refresh()
	save()
end)
closeButton.MouseButton1Click:Connect(function()
	SettingsMenu.setOpen(false)
end)
-- Retour à l'écran d'accueil (quitter un match compte comme un forfait).
menuButton.MouseButton1Click:Connect(function()
	SettingsMenu.setOpen(false)
	ReplicatedStorage.Remotes:WaitForChild("Lobby"):FireServer("menu")
end)
gear.MouseButton1Click:Connect(SettingsMenu.toggle)

-- Capture de la nouvelle touche, et touche P pour ouvrir / fermer.
UserInputService.InputBegan:Connect(function(input, processed)
	if waiting then
		local name: string? = nil
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				waiting = nil
				refresh()
				return
			elseif input.KeyCode == Enum.KeyCode.Backspace then
				name = ""
			elseif input.KeyCode ~= Enum.KeyCode.P then -- P reste réservé au menu
				name = input.KeyCode.Name
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			name = "MouseButton2"
		elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
			name = "MouseButton3"
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Le clic gauche sert aussi à cliquer sur la case : on ne le prend que hors des boutons.
			if not processed then
				name = "MouseButton1"
			end
		end
		if name then
			Input.setBinding(waiting.id, waiting.slot, name)
			waiting = nil
			refresh()
			save()
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.P and not UserInputService:GetFocusedTextBox() then
		SettingsMenu.toggle()
	end
end)

-- Réglages sauvegardés : on les demande au serveur au démarrage.
remote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "load" then
		Input.load(data)
		if type(data) == "table" then
			Prefs.load(data.prefs)
		end
		refresh()
	elseif kind == "info" and type(data) == "string" then
		hint.Text = Lang.t(data)
	end
end)
remote:FireServer("load")

refresh()

return SettingsMenu
