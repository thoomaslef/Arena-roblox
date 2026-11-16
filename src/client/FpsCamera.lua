-- Caméra à la première personne : yaw/pitch maison, souris bloquée au centre,
-- champ de vision HORIZONTAL constant (95° comme dans Godot) quel que soit l'écran.

local UserInputService = game:GetService("UserInputService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local C = Config.Camera
local MAX_PITCH = math.rad(C.MAX_PITCH_DEG)

local FpsCamera = {
	yaw = 0,
	pitch = 0,
	zoom = 1, -- multiplicateur du champ de vision (Rail : 0,45)
	zoomTarget = 1,
	shake = 0, -- intensité du tremblement (explosions proches)
}

function FpsCamera.setYaw(yaw: number)
	FpsCamera.yaw = yaw
	FpsCamera.pitch = 0
end

function FpsCamera.applyLook(dx: number, dy: number)
	-- Au zoom, la sensibilité baisse avec le champ de vision.
	local k = FpsCamera.zoom
	FpsCamera.yaw -= dx * k
	FpsCamera.pitch = math.clamp(FpsCamera.pitch - dy * k, -MAX_PITCH, MAX_PITCH)
end

function FpsCamera.rotation(): CFrame
	return CFrame.Angles(0, FpsCamera.yaw, 0) * CFrame.Angles(FpsCamera.pitch, 0, 0)
end

function FpsCamera.update(dt: number, eye: Vector3)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	-- Zoom en douceur (plateforme Rail).
	FpsCamera.zoom += (FpsCamera.zoomTarget - FpsCamera.zoom) * math.min(1, dt * 14)

	-- FOV horizontal → vertical (Roblox règle le champ vertical).
	local vp = cam.ViewportSize
	local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
	local h = math.rad(C.HFOV) * FpsCamera.zoom
	cam.FieldOfView = math.clamp(math.deg(2 * math.atan(math.tan(h / 2) / aspect)), 1, 120)

	local offset = Vector3.zero
	if FpsCamera.shake > 0 then
		local a = FpsCamera.shake
		offset = Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
		FpsCamera.shake = math.max(0, FpsCamera.shake - dt * 2.5)
	end
	cam.CFrame = CFrame.new(eye) * FpsCamera.rotation() * CFrame.new(offset)
end

return FpsCamera
