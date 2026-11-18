-- Défis du jour : 3 défis tirés chaque jour (minuit UTC) dans cette liste, propres à chaque
-- joueur. Le serveur compte la progression (Profiles), l'XP est donnée dès qu'un défi est
-- réussi. Texte affiché : clé Lang « dc.<id> » (avec l'objectif en %d).
--   kind : événement compté (envoyé par Profiles.event)

local Challenges = {}

Challenges.PER_DAY = 3

Challenges.POOL = {
	{ id = "win_rounds", kind = "roundWon", target = 5, xp = 120 },
	{ id = "hits", kind = "hit", target = 20, xp = 100 },
	{ id = "rail_hits", kind = "railHit", target = 3, xp = 150 },
	{ id = "detonate", kind = "detonate", target = 1, xp = 150 },
	{ id = "airshot", kind = "airshot", target = 3, xp = 150 },
	{ id = "win_match", kind = "matchWon", target = 1, xp = 150 },
	{ id = "play_matches", kind = "matchPlayed", target = 3, xp = 120 },
	{ id = "ranked", kind = "rankedPlayed", target = 1, xp = 120 },
	{ id = "flawless", kind = "flawless", target = 1, xp = 180 },
	{ id = "kills", kind = "kill", target = 5, xp = 120 },
}

local byId = {}
for _, c in Challenges.POOL do
	byId[c.id] = c
end

function Challenges.get(id: string)
	return byId[id]
end

-- Numéro du jour (UTC).
function Challenges.today(): number
	return math.floor(os.time() / 86400)
end

-- Les défis du jour `day` pour ce joueur (toujours les mêmes pour un jour donné).
function Challenges.pick(day: number, userId: number): { string }
	local rng = Random.new(day * 7919 + (userId % 1000003))
	local ids = {}
	for _, c in Challenges.POOL do
		table.insert(ids, c.id)
	end
	local out = {}
	for _ = 1, math.min(Challenges.PER_DAY, #ids) do
		local i = rng:NextInteger(1, #ids)
		table.insert(out, table.remove(ids, i))
	end
	return out
end

return Challenges
