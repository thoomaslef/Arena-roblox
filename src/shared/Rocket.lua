-- Calculs de la roquette partagés par le serveur (qui fait foi) et le client (prédiction
-- pour l'affichage immédiat et le rocket jump). Portage de arena.gd (spawn_projectile,
-- explode, _bump) et projectile.gd. Logique en MÈTRES, requêtes en studs.

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local S = Config.STUDS_PER_METER
local R = Config.Rocket
local B = Config.Body

local Rocket = {}

-- Requêtes « monde seulement » (lignes de vue des explosions) : la map actuelle.
-- Gardées en cache tant que la map ne change pas (elle change à chaque match).
local cachedMap: Instance? = nil
local cachedParams: RaycastParams? = nil
function Rocket.worldParams(): RaycastParams
	local map = Workspace:FindFirstChild("Map")
	if cachedParams and map == cachedMap and map ~= nil then
		return cachedParams
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = if map then { map } else {}
	cachedMap, cachedParams = map, p
	return p
end

-- Requêtes d'un tir : la map + les corps des joueurs, sauf le tireur.
function Rocket.shotParams(shooterCharacter: Instance?): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {}
	if shooterCharacter then
		table.insert(ex, shooterCharacter)
	end
	local fx = Workspace:FindFirstChild("CavaleFx")
	if fx then
		table.insert(ex, fx)
	end
	p.FilterDescendantsInstances = ex
	p.RespectCanCollide = false -- les membres des avatars ne « collident » pas mais restent des cibles
	return p
end

-- Point visé sous le réticule (250 m), puis départ et vitesse de la roquette.
-- eye, dir en mètres ; yaw du joueur pour le décalage à droite.
function Rocket.launch(eye: Vector3, dir: Vector3, yaw: number, params: RaycastParams): (Vector3, Vector3)
	dir = dir.Unit
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local spawn = eye + dir * R.MUZZLE_FORWARD + right * 0.14 + Vector3.new(0, -0.14, 0)
	local hit = Workspace:Raycast(eye * S, dir * 250 * S, params)
	local target = if hit then hit.Position / S else eye + dir * 250
	local vdir = dir
	if (target - eye).Magnitude > 2.0 then
		vdir = (target - spawn).Unit
	end
	return spawn, vdir * R.SPEED
end

-- Balayage d'un segment (m) : renvoie (position, normale, instance) du premier obstacle.
function Rocket.sweep(from: Vector3, to: Vector3, params: RaycastParams)
	local d = to - from
	if d.Magnitude < 1e-6 then
		return nil
	end
	local hit = Workspace:Raycast(from * S, d * S, params)
	if hit then
		return hit.Position / S, hit.Normal, hit.Instance
	end
	return nil
end

local function closestOnSegment(p: Vector3, a: Vector3, b: Vector3): Vector3
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return a + ab * t
end

local function blocked(a: Vector3, b: Vector3, worldParams: RaycastParams): boolean
	local d = b - a
	if d.Magnitude < 1e-4 then
		return false
	end
	return Workspace:Raycast(a * S, d * S, worldParams) ~= nil
end

-- L'explosion en `pos` (normale `n`) touche-t-elle un joueur dont les pieds sont en `feet` ?
function Rocket.damages(pos: Vector3, n: Vector3, feet: Vector3, worldParams: RaycastParams): boolean
	local cp = closestOnSegment(pos, feet + Vector3.new(0, 0.45, 0), feet + Vector3.new(0, 1.4, 0))
	if (cp - pos).Magnitude > R.HIT_RADIUS + B.RADIUS then
		return false
	end
	return not blocked(pos + n * 0.12, cp, worldParams)
end

-- Poussée (m/s) subie par un joueur dont les pieds sont en `feet`, ou nil.
-- Touche tout le monde, tireur compris (rocket jump).
function Rocket.push(pos: Vector3, n: Vector3, feet: Vector3, worldParams: RaycastParams): Vector3?
	local reach = R.PUSH_RADIUS + B.RADIUS
	local cp = closestOnSegment(pos, feet + Vector3.new(0, 0.3, 0), feet + Vector3.new(0, 1.5, 0))
	local d = (cp - pos).Magnitude
	if d > reach then
		return nil
	end
	if blocked(pos + n * 0.12, cp, worldParams) then
		return nil
	end
	local dir = (feet + Vector3.new(0, 0.9, 0)) - pos
	if dir.Magnitude < 0.05 then
		dir = Vector3.yAxis
	end
	dir = (dir.Unit + Vector3.new(0, R.PUSH_UP, 0)).Unit
	local k = math.clamp(1 - d / reach, 0, 1)
	return dir * R.PUSH_FORCE * (0.35 + 0.65 * k)
end

-- Pieds d'un personnage (m), ou nil.
function Rocket.feetOf(character: Model?): Vector3?
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local off = character:GetAttribute("FeetOffset")
	if not root or type(off) ~= "number" then
		return nil
	end
	local p = root.Position
	return Vector3.new(p.X, p.Y - off, p.Z) / S
end

return Rocket
