-- Mise à l'échelle des interfaces selon la taille de l'écran (téléphones, tablettes, PC).
-- Les interfaces sont dessinées pour un écran de 1280 × 720 ; sur un téléphone en paysage
-- (~ 850 × 390), tout est réduit pour tenir, sans descendre trop bas pour rester lisible.

local Workspace = game:GetService("Workspace")

local UiScale = {}

local scales: { UIScale } = {}

function UiScale.factor(): number
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.25)
end

local function refresh()
	local f = UiScale.factor()
	for _, s in scales do
		s.Scale = f
	end
end

-- Ajoute une UIScale réglée automatiquement à cette interface.
function UiScale.attach(gui: Instance)
	local s = Instance.new("UIScale")
	s.Parent = gui
	table.insert(scales, s)
	refresh()
end

local function watch()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
watch()

return UiScale
