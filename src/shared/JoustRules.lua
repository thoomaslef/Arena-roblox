-- Règles du 1v1 « Règlement de comptes » partagées serveur / client (portage de joust.gd).
-- Le gaz se calcule à partir du temps de manche : le serveur n'envoie que l'heure de
-- départ, chaque client recalcule le même rayon.

local Config = require(script.Parent.Config)

local J = Config.Joust

local JoustRules = {}

-- Rayon initial (m) : presque le bord de la map, et au moins (spawn le plus loin + 4 m).
function JoustRules.initialRadius(sizeCells: Vector2, center: Vector3, spawnsM: { Vector3 }): number
	local w, d = sizeCells.X * 2, sizeCells.Y * 2
	local r0 = math.min(w, d) * 0.5 - 1.0
	for _, p in spawnsM do
		local dist = Vector2.new(center.X - p.X, center.Z - p.Z).Magnitude
		r0 = math.max(r0, dist + 4.0)
	end
	return r0
end

-- Rayon du gaz (m) au temps t (s) depuis le GO.
function JoustRules.gasRadius(t: number, r0: number): number
	local acc, prev = 0, 1.0
	for _, step in J.GAS_STEPS do
		local dur, target = step[1], step[2]
		if t < acc + dur then
			local k = (t - acc) / dur
			return math.max(J.GAS_MIN_RADIUS, r0 * (prev + (target - prev) * k))
		end
		acc += dur
		prev = target
	end
	return math.max(J.GAS_MIN_RADIUS, r0 * prev)
end

-- Palier du gaz (0..3) : nombre de resserrements commencés.
function JoustRules.gasStage(t: number): number
	local acc, shrinks = 0, 0
	for i, step in J.GAS_STEPS do
		acc += step[1]
		local shrinking = i % 2 == 0 -- paliers 2, 4, 6 (1-indexés) = resserrements
		if t < acc then
			return shrinks + (if shrinking then 1 else 0)
		end
		if shrinking then
			shrinks += 1
		end
	end
	return 3
end

function JoustRules.isShrinking(t: number): boolean
	local acc = 0
	for i, step in J.GAS_STEPS do
		acc += step[1]
		if t < acc then
			return i % 2 == 0
		end
	end
	return false
end

-- Distance horizontale au centre du gaz (m).
function JoustRules.distToCenter(p: Vector3, center: Vector3): number
	return Vector2.new(p.X - center.X, p.Z - center.Z).Magnitude
end

-- Gagnant du match : 1, 2 ou nil (11 points avec 2 d'écart).
function JoustRules.matchWinner(a: number, b: number): number?
	if a >= J.WIN_SCORE and a - b >= J.WIN_GAP then
		return 1
	end
	if b >= J.WIN_SCORE and b - a >= J.WIN_GAP then
		return 2
	end
	return nil
end

-- Fil des éliminations, dans le vocabulaire du camp du tireur.
JoustRules.KILL_VERBS = {
	[0] = { "a serré", "a coffré", "a menotté", "a neutralisé", "a mis au trou", "a embarqué" },
	[1] = { "a refroidi", "a planté", "a descendu", "a fumé", "a effacé", "a rayé de la carte" },
}
JoustRules.FALL_TEXT = {
	[0] = "est tombé en service",
	[1] = "s'est vautré",
}

return JoustRules
