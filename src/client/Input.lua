-- Entrées du joueur : clavier/souris, manette et tactile, ramenées à quelques valeurs simples.
--   move       : Vector2 (x = droite, y = avant), longueur ≤ 1
--   mobHeld    : bouton de mobilité tenu (Espace / clic droit / A / bouton tactile)
--   consumeMobPressed() : vrai une seule fois par appui
--   walk       : marcher (Maj / L3)
--   fireHeld   : tir (clic gauche / RT / bouton tactile)
--   consumeLook() : rotation de caméra accumulée (dx, dy) en radians

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local C = Config.Camera

local Input = {
	move = Vector2.zero,
	mobHeld = false,
	walk = false,
	fireHeld = false,
}

local mobPressed = false
local lookX, lookY = 0, 0
local gamepadLook = Vector2.zero
local touchLook: { [InputObject]: Vector3 } = {}
local touchMob = false
local touchFire = false
local keyMob = false
local keyFire = false

local controls = nil
task.spawn(function()
	local playerModule = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
	controls = (require(playerModule :: ModuleScript) :: any):GetControls()
end)

local function refreshMob()
	local held = keyMob or touchMob
	if held and not Input.mobHeld then
		mobPressed = true
	end
	Input.mobHeld = held
end

local function refreshFire()
	Input.fireHeld = keyFire or touchFire
end

-- Priorité haute : on passe avant le saut par défaut de Roblox et on « mange » l'entrée.
ContextActionService:BindActionAtPriority("CavaleMobility", function(_, state)
	if state == Enum.UserInputState.Begin then
		keyMob = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		keyMob = false
	end
	refreshMob()
	return Enum.ContextActionResult.Sink
end, false, 3000, Enum.KeyCode.Space, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonA)

ContextActionService:BindActionAtPriority("CavaleWalk", function(_, state)
	Input.walk = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end, false, 3000, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)

ContextActionService:BindActionAtPriority("CavaleFire", function(_, state)
	if state == Enum.UserInputState.Begin then
		keyFire = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		keyFire = false
	end
	refreshFire()
	return Enum.ContextActionResult.Pass
end, false, 3000, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

-- Manette : stick droit pour viser.
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		gamepadLook = if p.Magnitude > 0.15 then p else Vector2.zero
	end
end)

-- Tactile : glisser sur l'écran (hors joystick et boutons) pour viser.
UserInputService.TouchStarted:Connect(function(touch, processed)
	if processed then
		return
	end
	local cam = workspace.CurrentCamera
	if cam and touch.Position.X < cam.ViewportSize.X * 0.35 then
		return -- zone du joystick
	end
	touchLook[touch] = touch.Position
end)
UserInputService.TouchMoved:Connect(function(touch)
	local last = touchLook[touch]
	if last then
		local d = touch.Position - last
		touchLook[touch] = touch.Position
		lookX += d.X * C.TOUCH_SENS
		lookY += d.Y * C.TOUCH_SENS
	end
end)
UserInputService.TouchEnded:Connect(function(touch)
	touchLook[touch] = nil
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
	if controls then
		local mv: Vector3 = controls:GetMoveVector()
		local v = Vector2.new(mv.X, -mv.Z)
		Input.move = if v.Magnitude > 1 then v.Unit else v
	end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		local d = UserInputService:GetMouseDelta()
		local sens = C.MOUSE_SENS * UserSettings():GetService("UserGameSettings").MouseSensitivity
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
