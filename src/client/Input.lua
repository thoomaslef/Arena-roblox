-- Entrées du joueur : clavier/souris, manette et tactile, ramenées à quelques valeurs simples.
--   move       : Vector2 (x = droite, y = avant), longueur ≤ 1
--   mobHeld    : bouton de mobilité tenu
--   consumeMobPressed() : vrai une seule fois par appui
--   walk       : marcher
--   fireHeld   : tir
--   consumeLook() : rotation de caméra accumulée (dx, dy) en radians
--
-- Touches réglables (menu Réglages, touche P) : 2 touches par action, sauvegardées par
-- le serveur. Les flèches et la manette marchent toujours en plus.
-- Souris : mouvement BRUT (InputChanged), sans la sensibilité de Roblox ni aucune
-- accélération : même déplacement de souris = même rotation, quelle que soit la vitesse.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local C = Config.Camera

local Input = {
	move = Vector2.zero,
	mobHeld = false,
	walk = false,
	fireHeld = false,
	menuOpen = false, -- menu Réglages ouvert : le jeu ne reçoit plus les entrées
	sensitivity = 1.0, -- multiplicateur de sensibilité souris (réglable)
}

-- Actions réglables, dans l'ordre du menu.
Input.ACTIONS = {
	{ id = "forward", label = "Avancer" },
	{ id = "back", label = "Reculer" },
	{ id = "left", label = "Gauche" },
	{ id = "right", label = "Droite" },
	{ id = "mobility", label = "Mobilité (saut, plané, sprint)" },
	{ id = "fire", label = "Tirer" },
	{ id = "walk", label = "Marcher" },
}

-- Touches par défaut : ZQSD (AZERTY) et WASD (QWERTY) en même temps.
Input.DEFAULTS = {
	forward = { "Z", "W" },
	back = { "S", "" },
	left = { "Q", "A" },
	right = { "D", "" },
	mobility = { "Space", "MouseButton2" },
	fire = { "MouseButton1", "" },
	walk = { "LeftShift", "" },
}

local function copyBindings(src)
	local out = {}
	for id, keys in src do
		out[id] = { keys[1] or "", keys[2] or "" }
	end
	return out
end
Input.bindings = copyBindings(Input.DEFAULTS)

-- Nom → entrée Roblox (KeyCode ou bouton de souris).
local MOUSE = {
	MouseButton1 = Enum.UserInputType.MouseButton1,
	MouseButton2 = Enum.UserInputType.MouseButton2,
	MouseButton3 = Enum.UserInputType.MouseButton3,
}
local function resolve(name: string): (Enum.KeyCode | Enum.UserInputType)?
	if name == "" then
		return nil
	end
	if MOUSE[name] then
		return MOUSE[name]
	end
	local ok, key = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok then key else nil
end
Input.resolve = resolve

-- Nom lisible d'une touche, pour le menu.
local PRETTY = {
	MouseButton1 = "Clic gauche",
	MouseButton2 = "Clic droit",
	MouseButton3 = "Clic molette",
	Space = "Espace",
	LeftShift = "Maj gauche",
	RightShift = "Maj droite",
	LeftControl = "Ctrl gauche",
	RightControl = "Ctrl droite",
	LeftAlt = "Alt gauche",
	Up = "Flèche haut",
	Down = "Flèche bas",
	Left = "Flèche gauche",
	Right = "Flèche droite",
	Tab = "Tab",
	[""] = "—",
}
function Input.pretty(name: string): string
	return PRETTY[name] or name
end

local function isDown(name: string): boolean
	local k = resolve(name)
	if not k then
		return false
	end
	if MOUSE[name] then
		return UserInputService:IsMouseButtonPressed(k :: Enum.UserInputType)
	end
	return UserInputService:IsKeyDown(k :: Enum.KeyCode)
end

local function actionDown(id: string, extra: Enum.KeyCode?): boolean
	for _, name in Input.bindings[id] do
		if isDown(name) then
			return true
		end
	end
	return extra ~= nil and UserInputService:IsKeyDown(extra)
end

local mobPressed = false
local lookX, lookY = 0, 0
local mouseDelta = Vector2.zero
local gamepadLook = Vector2.zero
local gamepadMove = Vector2.zero
local touchLook: { [InputObject]: Vector3 } = {}
local touchMob = false
local touchFire = false
local keyMob = false
local keyFire = false

-- Joystick tactile : on pose le doigt dans le tiers gauche de l'écran, il apparaît là.
local STICK_RADIUS = 60 -- pixels
local stickTouch: InputObject? = nil
Input.stick = { active = false, origin = Vector2.zero, pos = Vector2.zero, radius = STICK_RADIUS }

local function refreshMob()
	local held = (keyMob or touchMob) and not Input.menuOpen
	if held and not Input.mobHeld then
		mobPressed = true
	end
	Input.mobHeld = held
end

local function refreshFire()
	Input.fireHeld = (keyFire or touchFire) and not Input.menuOpen
end

-- Actions à appui (mobilité, tir, marche) : ContextActionService, priorité haute, pour passer
-- avant les raccourcis par défaut de Roblox. Rebranchées quand on change une touche.
local function inputsFor(id: string, gamepad: { Enum.KeyCode }): { any }
	local list: { any } = {}
	for _, name in Input.bindings[id] do
		local k = resolve(name)
		if k then
			table.insert(list, k)
		end
	end
	for _, g in gamepad do
		table.insert(list, g)
	end
	return list
end

function Input.applyBindings()
	ContextActionService:UnbindAction("CavaleMobility")
	ContextActionService:UnbindAction("CavaleWalk")
	ContextActionService:UnbindAction("CavaleFire")
	keyMob, keyFire, Input.walk = false, false, false
	refreshMob()
	refreshFire()

	ContextActionService:BindActionAtPriority("CavaleMobility", function(_, state)
		if state == Enum.UserInputState.Begin then
			keyMob = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			keyMob = false
		end
		refreshMob()
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(inputsFor("mobility", { Enum.KeyCode.ButtonA })))

	ContextActionService:BindActionAtPriority("CavaleWalk", function(_, state)
		Input.walk = state == Enum.UserInputState.Begin and not Input.menuOpen
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(inputsFor("walk", { Enum.KeyCode.ButtonL3 })))

	ContextActionService:BindActionAtPriority("CavaleFire", function(_, state)
		if state == Enum.UserInputState.Begin then
			keyFire = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			keyFire = false
		end
		refreshFire()
		return Enum.ContextActionResult.Pass
	end, false, 3000, table.unpack(inputsFor("fire", { Enum.KeyCode.ButtonR2 })))
end

-- Change une touche (slot 1 ou 2). name = "" pour l'effacer.
function Input.setBinding(id: string, slot: number, name: string)
	if not Input.bindings[id] then
		return
	end
	-- Une touche ne sert qu'à une action : on la retire ailleurs.
	if name ~= "" then
		for _, keys in Input.bindings do
			for i, k in keys do
				if k == name then
					keys[i] = ""
				end
			end
		end
	end
	Input.bindings[id][slot] = name
	Input.applyBindings()
end

function Input.resetBindings()
	Input.bindings = copyBindings(Input.DEFAULTS)
	Input.applyBindings()
end

-- Applique des réglages sauvegardés (venant du serveur). Tolère les données incomplètes.
function Input.load(data: any)
	if type(data) ~= "table" then
		return
	end
	if type(data.bindings) == "table" then
		for id, keys in data.bindings do
			if Input.bindings[id] and type(keys) == "table" then
				for slot = 1, 2 do
					local name = keys[slot]
					if type(name) == "string" and (name == "" or resolve(name)) then
						Input.bindings[id][slot] = name
					end
				end
			end
		end
	end
	if type(data.sensitivity) == "number" then
		Input.sensitivity = math.clamp(data.sensitivity, 0.05, 5)
	end
	Input.applyBindings()
end

function Input.save(): any
	return { bindings = copyBindings(Input.bindings), sensitivity = Input.sensitivity }
end

Input.applyBindings()

-- Souris (mouvement brut) et manette.
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		mouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		gamepadLook = if p.Magnitude > 0.15 then p else Vector2.zero
	elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		gamepadMove = if p.Magnitude > 0.15 then p else Vector2.zero
	end
end)

-- Tactile : glisser sur l'écran (hors joystick et boutons) pour viser.
UserInputService.TouchStarted:Connect(function(touch, processed)
	if processed then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and touch.Position.X < cam.ViewportSize.X * 0.35 then
		-- Zone du joystick.
		if not stickTouch then
			stickTouch = touch
			local p = Vector2.new(touch.Position.X, touch.Position.Y)
			Input.stick.active, Input.stick.origin, Input.stick.pos = true, p, p
		end
		return
	end
	touchLook[touch] = touch.Position
end)
UserInputService.TouchMoved:Connect(function(touch)
	if touch == stickTouch then
		Input.stick.pos = Vector2.new(touch.Position.X, touch.Position.Y)
		return
	end
	local last = touchLook[touch]
	if last then
		local d = touch.Position - last
		touchLook[touch] = touch.Position
		lookX += d.X * C.TOUCH_SENS * Input.sensitivity
		lookY += d.Y * C.TOUCH_SENS * Input.sensitivity
	end
end)
UserInputService.TouchEnded:Connect(function(touch)
	touchLook[touch] = nil
	if touch == stickTouch then
		stickTouch = nil
		Input.stick.active = false
	end
end)

function Input.setTouchMobility(held: boolean)
	touchMob = held
	refreshMob()
end

function Input.setTouchFire(held: boolean)
	touchFire = held
	refreshFire()
end

function Input.consumeMobPressed(): boolean
	local p = mobPressed
	mobPressed = false
	return p
end

-- À appeler une fois par image (avant la caméra).
function Input.update(dt: number)
	local d = mouseDelta
	mouseDelta = Vector2.zero
	if Input.menuOpen then
		Input.move = Vector2.zero
		refreshMob()
		refreshFire()
		return
	end

	local v = Vector2.zero
	-- Clavier (sauf pendant qu'on écrit dans le chat). Les flèches marchent toujours.
	if not UserInputService:GetFocusedTextBox() then
		local x = (if actionDown("right", Enum.KeyCode.Right) then 1 else 0) - (if actionDown("left", Enum.KeyCode.Left) then 1 else 0)
		local y = (if actionDown("forward", Enum.KeyCode.Up) then 1 else 0) - (if actionDown("back", Enum.KeyCode.Down) then 1 else 0)
		v = Vector2.new(x, y)
	end
	-- Manette.
	if gamepadMove ~= Vector2.zero then
		v += gamepadMove
	end
	-- Joystick tactile.
	if Input.stick.active then
		local s = (Input.stick.pos - Input.stick.origin) / STICK_RADIUS
		v += Vector2.new(s.X, -s.Y)
	end
	Input.move = if v.Magnitude > 1 then v.Unit else v

	-- Souris : linéaire, uniquement quand elle est bloquée au centre (en jeu).
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local sens = C.MOUSE_SENS * Input.sensitivity
		lookX += d.X * sens
		lookY += d.Y * sens
	end
	if gamepadLook ~= Vector2.zero then
		lookX += gamepadLook.X * C.GAMEPAD_SENS * dt
		lookY -= gamepadLook.Y * C.GAMEPAD_SENS * dt
	end
end

function Input.consumeLook(): (number, number)
	local x, y = lookX, lookY
	lookX, lookY = 0, 0
	return x, y
end

return Input
