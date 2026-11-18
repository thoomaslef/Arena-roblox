-- Menu Réglages (touche P, ou bouton ⚙ en haut à droite) :
--   * touches : 2 touches par action, clic sur une case puis appui sur la nouvelle touche
--     (Échap : annuler, Retour arrière : effacer) ;
--   * sensibilité de la souris (− / +).
-- Les réglages sont envoyés au serveur, qui les garde pour ton compte (DataStore).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Input = require(script.Parent.Input)
local FpsCamera = require(script.Parent.FpsCamera)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Settings") :: RemoteEvent

local SettingsMenu = {}

local ACCENT = Color3.fromRGB(255, 200, 80)
local BG = Color3.fromRGB(18, 20, 28)
local CELL = Color3.fromRGB(40, 44, 58)

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleSettings"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10

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
	Size = UDim2.fromOffset(560, 520),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Visible = false,
	Parent = gui,
})
corner(panel, 12)
make("UIStroke", { Color = ACCENT, Thickness = 2, Transparency = 0.4, Parent = panel })
make("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), Parent = panel })

make("TextLabel", {
	Text = "RÉGLAGES",
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextColor3 = ACCENT,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 32),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})
local hint = make("TextLabel", {
	Text = "Clique sur une case puis appuie sur une touche · Échap : annuler · Retour arrière : effacer",
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(190, 195, 210),
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 34),
	Size = UDim2.new(1, 0, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

-- Lignes : action | touche 1 | touche 2
local cells: { [string]: { TextButton } } = {}
local ROW_H, TOP = 38, 64
for i, action in Input.ACTIONS do
	local y = TOP + (i - 1) * (ROW_H + 4)
	make("TextLabel", {
		Text = action.label,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(0.44, 0, 0, ROW_H),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
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
			Parent = panel,
		})
		corner(b, 6)
		cells[action.id][slot] = b
	end
end

-- Sensibilité souris.
local sensY = TOP + #Input.ACTIONS * (ROW_H + 4) + 12
make("TextLabel", {
	Text = "Sensibilité souris",
	Font = Enum.Font.GothamMedium,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, sensY),
	Size = UDim2.new(0.44, 0, 0, ROW_H),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})
local function smallButton(text: string, x: number): TextButton
	local b = make("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = CELL,
		Position = UDim2.new(x, 0, 0, sensY),
		Size = UDim2.new(0.1, 0, 0, ROW_H),
		Parent = panel,
	})
	corner(b, 6)
	return b
end
local minus = smallButton("−", 0.46)
local sensLabel = make("TextLabel", {
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextColor3 = ACCENT,
	BackgroundTransparency = 1,
	Position = UDim2.new(0.57, 0, 0, sensY),
	Size = UDim2.new(0.21, 0, 0, ROW_H),
	Parent = panel,
})
local plus = smallButton("+", 0.8)

-- Bas : réinitialiser / fermer.
local function bottomButton(text: string, x: number, color: Color3): TextButton
	local b = make("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(x, 0, 1, 0),
		Size = UDim2.new(0.48, 0, 0, 40),
		Parent = panel,
	})
	corner(b, 8)
	return b
end
local resetButton = bottomButton("Touches par défaut", 0, CELL)
local closeButton = bottomButton("Fermer (P)", 0.52, Color3.fromRGB(200, 120, 30))

gui.Parent = player:WaitForChild("PlayerGui")

-- Affichage ---------------------------------------------------------------------------------
local waiting: { id: string, slot: number }? = nil

local function refresh()
	for id, row in cells do
		for slot, b in row do
			if waiting and waiting.id == id and waiting.slot == slot then
				b.Text = "…appuie"
				b.BackgroundColor3 = ACCENT
				b.TextColor3 = BG
			else
				b.Text = Input.pretty(Input.bindings[id][slot])
				b.BackgroundColor3 = CELL
				b.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end
	sensLabel.Text = ("%.2f"):format(Input.sensitivity)
end

local saveToken = 0
local function save()
	-- On attend un peu avant d'envoyer, pour regrouper plusieurs changements.
	saveToken += 1
	local token = saveToken
	task.delay(1.5, function()
		if token == saveToken then
			remote:FireServer("save", Input.save())
		end
	end)
end

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

for id, row in cells do
	for slot, b in row do
		b.MouseButton1Click:Connect(function()
			waiting = { id = id, slot = slot }
			refresh()
		end)
	end
end

local function changeSens(delta: number)
	Input.sensitivity = math.clamp(math.floor((Input.sensitivity + delta) * 100 + 0.5) / 100, 0.05, 5)
	refresh()
	save()
end
minus.MouseButton1Click:Connect(function()
	changeSens(-0.05)
end)
plus.MouseButton1Click:Connect(function()
	changeSens(0.05)
end)
resetButton.MouseButton1Click:Connect(function()
	Input.resetBindings()
	refresh()
	save()
end)
closeButton.MouseButton1Click:Connect(function()
	SettingsMenu.setOpen(false)
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
		refresh()
	elseif kind == "info" and type(data) == "string" then
		hint.Text = data
	end
end)
remote:FireServer("load")

refresh()

return SettingsMenu
