-- Serveur : anti-triche des déplacements.
--
-- Le client calcule lui-même ses déplacements (réactivité). Le serveur vérifie qu'ils
-- restent possibles avec les règles du jeu, et remet le joueur à sa dernière position
-- valide sinon :
--   * VITESSE : distance parcourue sur ~0,5 s comparée à la vitesse max permise
--     (sprint, accélérateur, pad ; beaucoup plus juste après une explosion) ;
--   * VOL : en l'air sans sol sous les pieds et sans redescendre pendant trop longtemps
--     (même en plané on redescend : seul un vrai « vol » reste en l'air sans descendre) ;
--   * MURS : le corps est passé à travers une partie solide de la map.
-- Les marges sont larges pour ne jamais gêner un joueur honnête avec un réseau moyen.
-- Trop d'infractions en peu de temps : le joueur est expulsé.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rocket = require(Shared.Rocket)

local S = Config.STUDS_PER_METER

local MoveGuard = {}

local G = {
	CHECK_EVERY = 0.1, -- s
	WINDOW = 0.5, -- s : on compare la position à celle d'il y a ~0,5 s
	MAX_SPEED = 26.0, -- m/s : accélérateur 24 m/s + marge
	MAX_SPEED_PUSHED = 48.0, -- m/s : juste après une explosion (rocket jump, poussée)
	MAX_RISE = 20.0, -- m/s : pad 17 m/s + marge
	MAX_RISE_PUSHED = 34.0,
	PUSH_GRACE = 1.6, -- s pendant lesquelles une poussée relève les limites
	SLACK = 2.5, -- m de marge (saccades du réseau)
	FLY_TIME = 3.0, -- s en l'air sans redescendre d'au moins FLY_DROP
	FLY_DROP = 1.0, -- m
	SPAWN_GRACE = 2.0, -- s après une apparition ou une correction
	KICK_STRIKES = 25, -- infractions…
	KICK_WINDOW = 60, -- …en 60 s → expulsion
}
MoveGuard.LIMITS = G

type Track = {
	history: { { t: number, pos: Vector3 } },
	lastValid: CFrame?,
	grace: number, -- os.clock() jusqu'auquel on ne vérifie pas
	pushedUntil: number,
	airSince: number?,
	airTopY: number,
	strikes: { number },
	character: Model?,
}
local tracks: { [Player]: Track } = {}

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = { history = {}, lastValid = nil, grace = 0, pushedUntil = 0, airSince = nil, airTopY = 0, strikes = {}, character = nil }
		tracks[player] = t
	end
	return t
end

-- Apparition / téléportation voulue par le serveur : on repart de zéro.
function MoveGuard.reset(player: Player)
	local t = track(player)
	t.history = {}
	t.lastValid = nil
	t.airSince = nil
	t.grace = os.clock() + G.SPAWN_GRACE
end

-- Une explosion vient de pousser ce joueur (y compris son propre rocket jump).
function MoveGuard.notePush(player: any)
	if typeof(player) == "Instance" and player:IsA("Player") then
		track(player).pushedUntil = os.clock() + G.PUSH_GRACE
	end
end

-- Sol sous les pieds : une sphère presque aussi large que le joueur (on tient debout sur
-- l'arête d'un bloc même si le centre des pieds est dans le vide).
local function onGround(feet: Vector3): boolean
	local from = feet + Vector3.new(0, 0.6, 0)
	return Workspace:Spherecast(from * S, 0.38 * S, Vector3.new(0, -1.8 * S, 0), Rocket.worldParams()) ~= nil
end

-- Le corps est-il passé à travers une paroi solide entre a et b ? On lance un rayon dans les
-- deux sens : la distance entre l'entrée et la sortie donne l'épaisseur traversée. Frôler
-- un coin de mur donne une épaisseur presque nulle : seule une vraie traversée compte.
local MIN_THICKNESS = 0.6 -- m (les murs font 2 m ; les cloisons fines de 0,3 m sont ignorées)
local function wallBetween(a: Vector3, b: Vector3): boolean
	local from = (a + Vector3.new(0, 0.9, 0)) * S
	local to = (b + Vector3.new(0, 0.9, 0)) * S
	local d = to - from
	if d.Magnitude < 0.8 * S then
		return false
	end
	local params = Rocket.worldParams()
	local hitA = Workspace:Raycast(from, d, params)
	if not hitA or not hitA.Instance.CanCollide then
		return false
	end
	local hitB = Workspace:Raycast(to, -d, params)
	if not hitB then
		return false -- b est à l'intérieur d'un bloc : on laisse la vitesse / le vol juger
	end
	return (hitB.Position - hitA.Position).Magnitude >= MIN_THICKNESS * S
end

local function strike(player: Player, t: Track, reason: string)
	local now = os.clock()
	table.insert(t.strikes, now)
	while #t.strikes > 0 and now - t.strikes[1] > G.KICK_WINDOW do
		table.remove(t.strikes, 1)
	end
	warn(("[Cavale] Mouvement refusé pour %s : %s (%d)"):format(player.Name, reason, #t.strikes))
	-- Retour à la dernière position valide.
	local character = player.Character
	if character and t.lastValid then
		character:PivotTo(t.lastValid)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	t.history = {}
	t.airSince = nil
	t.grace = now + 0.5
	if #t.strikes >= G.KICK_STRIKES then
		player:Kick("Mouvement anormal détecté (anti-triche). Si c'est une erreur, relance le jeu.")
	end
end

local function check(player: Player, now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local feet = Rocket.feetOf(character)
	local t = track(player)
	if not root or not feet then
		return
	end
	if t.character ~= character then
		t.character = character
		MoveGuard.reset(player)
	end
	if character:GetAttribute("Frozen") == true or now < t.grace then
		t.history = {}
		t.lastValid = root.CFrame
		t.airSince = nil
		return
	end

	local hist = t.history
	table.insert(hist, { t = now, pos = feet })
	while #hist > 2 and now - hist[2].t >= G.WINDOW do
		table.remove(hist, 1)
	end

	local pushed = now < t.pushedUntil
	local first = hist[1]
	local dt = now - first.t
	if dt > 0.05 then
		local d = feet - first.pos
		local flat = Vector2.new(d.X, d.Z).Magnitude
		local maxFlat = (if pushed then G.MAX_SPEED_PUSHED else G.MAX_SPEED) * dt + G.SLACK
		local maxUp = (if pushed then G.MAX_RISE_PUSHED else G.MAX_RISE) * dt + G.SLACK
		if flat > maxFlat then
			strike(player, t, ("vitesse %.0f m/s"):format(flat / dt))
			return
		end
		if d.Y > maxUp then
			strike(player, t, ("montée %.0f m/s"):format(d.Y / dt))
			return
		end
	end

	-- Passage à travers un mur depuis la mesure précédente.
	local prev = hist[#hist - 1]
	if prev and wallBetween(prev.pos, feet) then
		strike(player, t, "à travers un mur")
		return
	end

	-- Vol : en l'air sans redescendre.
	if onGround(feet) then
		t.airSince = nil
	else
		if not t.airSince or pushed then
			t.airSince = now
			t.airTopY = feet.Y
		end
		t.airTopY = math.max(t.airTopY, feet.Y)
		if now - (t.airSince :: number) > G.FLY_TIME and feet.Y > t.airTopY - G.FLY_DROP then
			strike(player, t, "vol")
			return
		end
		-- Il redescend : on repart de son point actuel.
		if feet.Y < t.airTopY - G.FLY_DROP then
			t.airSince = now
			t.airTopY = feet.Y
		end
	end

	t.lastValid = root.CFrame
end

task.spawn(function()
	while true do
		task.wait(G.CHECK_EVERY)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(check, player, now)
			if not ok then
				warn("[Cavale] MoveGuard :", err)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	tracks[player] = nil
end)

return MoveGuard
