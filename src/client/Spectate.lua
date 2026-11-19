-- Vue spectateur (3v3) : quand on n'a pas de personnage pendant un match (éliminé, ou
-- coéquipier de l'attaquant qui ne joue pas cette manche), la caméra suit le personnage
-- désigné par le serveur (ObjectValue ReplicatedStorage.Match.Spectate : en général l'attaquant).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lang = require(Shared:WaitForChild("Lang"))

local player = Players.LocalPlayer
local match = ReplicatedStorage:WaitForChild("Match")

local Spectate = {}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleSpectate"
gui.AutoLocalize = false
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.Enabled = false
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -40)
label.Size = UDim2.fromOffset(600, 30)
label.Font = Enum.Font.GothamBlack
label.TextSize = 22
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.4
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local smoothed: CFrame? = nil

-- À chaque image. hasCharacter : le joueur local a un personnage vivant (pas de spectateur).
function Spectate.update(dt: number, hasCharacter: boolean, menuOpen: boolean)
	local value = match:FindFirstChild("Spectate")
	local target = value and value:IsA("ObjectValue") and value.Value
	local active = not hasCharacter
		and not menuOpen
		and player:GetAttribute("Mode") == "play"
		and match:GetAttribute("Mode") == "elite"
		and match:GetAttribute("State") ~= "waiting"
		and target ~= nil
		and target:IsA("Model")
		and target.Parent ~= nil
	gui.Enabled = active
	if not active then
		smoothed = nil
		return
	end
	local root = (target :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = Workspace.CurrentCamera
	if not root or not cam then
		return
	end
	-- Derrière et un peu au-dessus de la cible, dans la direction où elle regarde.
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local focus = root.Position + Vector3.new(0, 2.5, 0)
	local goal = CFrame.lookAt(focus - flat * 14 + Vector3.new(0, 5, 0), focus)
	smoothed = if smoothed then smoothed:Lerp(goal, math.min(1, dt * 6)) else goal
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 70
	cam.CFrame = smoothed :: CFrame
	local name = (target :: Model).Name
	local hum = (target :: Model):FindFirstChildOfClass("Humanoid")
	if hum and hum.DisplayName ~= "" then
		name = hum.DisplayName
	end
	label.Text = Lang.t("el.spectating", name)
end

return Spectate
