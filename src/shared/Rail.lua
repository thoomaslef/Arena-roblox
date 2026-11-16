-- Calculs du Rail partagés serveur / client (portage de arena.gd : fire_rail).
-- Tir instantané (220 m) ; une roquette sur la trajectoire, avant l'obstacle, explose en vol.

local Config = require(script.Parent.Config)

local RL = Config.Rail

local Rail = {}

-- Bout du canon (m), pour le rayon visible.
function Rail.muzzle(eye: Vector3, dir: Vector3, yaw: number): Vector3
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	return eye + dir * 0.6 + right * 0.16 + Vector3.new(0, -0.16, 0)
end

-- Couleur du rayon : cyan teinté de la couleur du camp.
function Rail.color(team: number?): Color3
	local t = if team ~= nil then Config.Teams[team] else nil
	return if t then RL.BEAM_COLOR:Lerp(t.color, 0.35) else RL.BEAM_COLOR
end

-- Cherche, parmi `rockets` (liste de {key, pos, vel}), la plus proche du tireur qui coupe le
-- rayon avant la distance `best`. `lag` (s) : on teste aussi la trajectoire récente.
-- Renvoie (key, distance le long du rayon) ou nil.
function Rail.rocketOnRay(eye: Vector3, dir: Vector3, best: number, rockets, lag: number?)
	local found, foundAlong = nil, best
	local samples = if lag and lag > 0 then 5 else 1
	for _, r in rockets do
		for k = 0, samples - 1 do
			local back = if samples > 1 then (lag :: number) * k / (samples - 1) else 0
			local pos = r.pos - r.vel * back
			local along = (pos - eye):Dot(dir)
			if along > 0.3 and along < foundAlong then
				if ((eye + dir * along) - pos).Magnitude <= RL.ROCKET_DESTROY_DIST then
					found, foundAlong = r.key, along
					break
				end
			end
		end
	end
	if found ~= nil then
		return found, foundAlong
	end
	return nil
end

return Rail
