-- Serveur : profil de chaque joueur (XP, niveau, statistiques, classement de la saison),
-- gardé dans un DataStore, et classement mondial (OrderedDataStore).
--
-- Ce que voient les clients (attributs du Player, répliqués à tous) :
--   Level, XP, XPNext, Rating, RankKey ("unranked" pendant les matchs de placement),
--   RankedGames, Wins, Matches, Accuracy (%)
-- Classement mondial : attribut « Leaderboard » du dossier ReplicatedStorage.Match (JSON).
-- Fin de match : RemoteEvent Remotes.Rewards, "rewards" → { xp, level, levelUp, ratingDelta,
--   rating, rankKey, vsBot, ranked, stats } ; défi réussi : "challenge" → { id, xp, target }.
-- Détail : attributs StatsJson (toutes les statistiques) et DailyJson (défis du jour).
--
-- Dans Studio, il faut une place publiée et « Autoriser l'accès de Studio aux services d'API »
-- (Paramètres du jeu → Sécurité) ; sinon tout marche pendant la partie mais rien n'est gardé.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Challenges = require(Shared.Challenges)

local P = Config.Progress
local RK = Config.Ranked

local Profiles = {}

local rewardsRemote = Instance.new("RemoteEvent")
rewardsRemote.Name = "Rewards"
rewardsRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")

local store: DataStore? = nil
local board: OrderedDataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("CavaleProfiles_v1")
	board = DataStoreService:GetOrderedDataStore("CavaleRanked_S" .. RK.SEASON)
end)

type Profile = {
	xp: number,
	level: number,
	stats: { [string]: number },
	ranked: { season: number, rating: number, games: number, wins: number, peak: number },
	daily: { day: number, ids: { string }, progress: { [string]: number }, done: { [string]: boolean } },
}

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local matchXp: { [Player]: number } = {} -- XP gagnée pendant le match en cours (écran de fin)
local matchStats: { [Player]: { [string]: number } } = {} -- statistiques du match en cours
local MATCH_STATS = { shots = true, hits = true, kills = true, detonations = true, roundsWon = true, airshots = true }

-- Matchs non classés dans un serveur privé (branché par Main sur Rooms).
Profiles.isPrivateServer = function(): boolean
	return false
end

local function isPlayer(p: any): boolean
	return typeof(p) == "Instance" and p:IsA("Player")
end

local function newProfile(): Profile
	return {
		xp = 0,
		level = 1,
		stats = { matches = 0, wins = 0, rounds = 0, roundsWon = 0, hits = 0, shots = 0, kills = 0, detonations = 0, airshots = 0, railHits = 0, streak = 0, bestStreak = 0 },
		ranked = { season = RK.SEASON, rating = RK.START_RATING, games = 0, wins = 0, peak = RK.START_RATING },
		daily = { day = -1, ids = {}, progress = {}, done = {} },
	}
end

-- Complète un profil chargé (anciennes versions, champs manquants) ; nouvelle saison.
local function migrate(data: any): Profile
	local prof = newProfile()
	if type(data) ~= "table" then
		return prof
	end
	if type(data.xp) == "number" then
		prof.xp = math.max(0, math.floor(data.xp))
	end
	if type(data.level) == "number" then
		prof.level = math.max(1, math.floor(data.level))
	end
	if type(data.stats) == "table" then
		for k, v in data.stats do
			if type(k) == "string" and type(v) == "number" then
				prof.stats[k] = v
			end
		end
	end
	if type(data.daily) == "table" and type(data.daily.day) == "number" and type(data.daily.ids) == "table" then
		prof.daily = {
			day = data.daily.day,
			ids = data.daily.ids,
			progress = if type(data.daily.progress) == "table" then data.daily.progress else {},
			done = if type(data.daily.done) == "table" then data.daily.done else {},
		}
	end
	if type(data.ranked) == "table" and type(data.ranked.rating) == "number" then
		local r = data.ranked
		if r.season == RK.SEASON then
			prof.ranked = {
				season = RK.SEASON,
				rating = r.rating,
				games = r.games or 0,
				wins = r.wins or 0,
				peak = r.peak or r.rating,
			}
		else
			-- Nouvelle saison : on se rapproche de 1000, et on refait ses matchs de placement.
			local carried = RK.START_RATING + (r.rating - RK.START_RATING) * RK.SEASON_CARRY
			prof.ranked = { season = RK.SEASON, rating = math.floor(carried), games = 0, wins = 0, peak = math.floor(carried) }
		end
	end
	return prof
end

local function publish(player: Player)
	local prof = profiles[player]
	if not prof then
		return
	end
	player:SetAttribute("Level", prof.level)
	player:SetAttribute("XP", prof.xp)
	player:SetAttribute("XPNext", Config.xpForLevel(prof.level))
	player:SetAttribute("Rating", math.floor(prof.ranked.rating + 0.5))
	player:SetAttribute("RankedGames", prof.ranked.games)
	player:SetAttribute("RankKey", if prof.ranked.games >= RK.PLACEMENT_GAMES then (Config.rankFor(prof.ranked.rating)) else "unranked")
	player:SetAttribute("Wins", prof.stats.wins)
	player:SetAttribute("Matches", prof.stats.matches)
	local shots = prof.stats.shots
	player:SetAttribute("Accuracy", if shots > 0 then math.floor(prof.stats.hits / shots * 100 + 0.5) else 0)
	-- Détail pour l'onglet STATS et les défis du jour (JSON).
	local st = table.clone(prof.stats)
	st.peak = math.floor(prof.ranked.peak + 0.5)
	player:SetAttribute("StatsJson", HttpService:JSONEncode(st))
	local daily = {}
	for _, id in prof.daily.ids do
		local c = Challenges.get(id)
		if c then
			table.insert(daily, { id = id, progress = math.min(prof.daily.progress[id] or 0, c.target), target = c.target, xp = c.xp, done = prof.daily.done[id] == true })
		end
	end
	player:SetAttribute("DailyJson", HttpService:JSONEncode({ day = prof.daily.day, list = daily }))
end

-- Nouveaux défis si le jour a changé (minuit UTC).
local function refreshDaily(player: Player, prof: Profile): boolean
	local today = Challenges.today()
	if prof.daily.day == today and #prof.daily.ids > 0 then
		return false
	end
	prof.daily = { day = today, ids = Challenges.pick(today, player.UserId), progress = {}, done = {} }
	dirty[player] = true
	return true
end

local function save(player: Player)
	local prof = profiles[player]
	if not prof or not store or not loaded[player] then
		return
	end
	dirty[player] = false
	pcall(function()
		(store :: DataStore):SetAsync("u" .. player.UserId, prof)
	end)
end

local function load(player: Player)
	local data = nil
	if store then
		local ok, res = pcall(function()
			return (store :: DataStore):GetAsync("u" .. player.UserId)
		end)
		if ok then
			data = res
			loaded[player] = true
		else
			warn("[Cavale] Profil non chargé (DataStore indisponible) :", res)
		end
	end
	if not player.Parent then
		return
	end
	profiles[player] = migrate(data)
	refreshDaily(player, profiles[player])
	publish(player)
end

function Profiles.get(player: any): Profile?
	return if isPlayer(player) then profiles[player] else nil
end

-- Ajoute de l'XP (montée de niveau comprise). mult : 0,5 contre le bot.
function Profiles.addXP(player: any, amount: number, mult: number?)
	local prof = Profiles.get(player)
	if not prof then
		return
	end
	local gain = math.floor(amount * (mult or 1) + 0.5)
	if gain <= 0 then
		return
	end
	prof.xp += gain
	matchXp[player] = (matchXp[player] or 0) + gain
	while prof.xp >= Config.xpForLevel(prof.level) do
		prof.xp -= Config.xpForLevel(prof.level)
		prof.level += 1
	end
	dirty[player] = true
	publish(player)
end

function Profiles.stat(player: any, name: string, n: number?)
	local prof = Profiles.get(player)
	if not prof then
		return
	end
	prof.stats[name] = (prof.stats[name] or 0) + (n or 1)
	if MATCH_STATS[name] and matchStats[player] then
		matchStats[player][name] = (matchStats[player][name] or 0) + (n or 1)
	end
	dirty[player] = true
end

-- Événement de jeu pour les défis du jour (kind : voir Challenges.POOL).
function Profiles.event(player: any, kind: string, n: number?)
	local prof = Profiles.get(player)
	if not prof then
		return
	end
	refreshDaily(player, prof)
	for _, id in prof.daily.ids do
		local c = Challenges.get(id)
		if c and c.kind == kind and not prof.daily.done[id] then
			prof.daily.progress[id] = (prof.daily.progress[id] or 0) + (n or 1)
			if prof.daily.progress[id] >= c.target then
				prof.daily.done[id] = true
				Profiles.addXP(player, c.xp)
				rewardsRemote:FireClient(player, "challenge", { id = id, xp = c.xp, target = c.target })
			end
			dirty[player] = true
		end
	end
	publish(player)
end

-- Début d'un match : on remet à zéro le compteur d'XP du match.
function Profiles.matchStarted(players: { any })
	for _, p in players do
		if isPlayer(p) then
			matchXp[p] = 0
			matchStats[p] = {}
		end
	end
end

-- Fin de match. winner / loser : combattants (joueur ou bot). forfeit : le perdant est parti.
function Profiles.matchEnded(winner: any, loser: any, forfeit: boolean?)
	local vsBot = not (isPlayer(winner) and isPlayer(loser))
	local ranked = not vsBot and not Profiles.isPrivateServer()
	local mult = if vsBot then P.VS_BOT_MULT else 1
	local levelsBefore = {}
	for _, p in { winner, loser } do
		local prof = Profiles.get(p)
		if prof then
			levelsBefore[p] = prof.level
			prof.stats.matches += 1
			Profiles.addXP(p, P.XP_MATCH_PLAYED, mult)
		end
	end
	if Profiles.get(winner) then
		Profiles.stat(winner, "wins")
		Profiles.addXP(winner, P.XP_MATCH_WON, mult)
		local st = (profiles[winner] :: Profile).stats
		st.streak = (st.streak or 0) + 1
		st.bestStreak = math.max(st.bestStreak or 0, st.streak)
		Profiles.event(winner, "matchWon")
	end
	if Profiles.get(loser) then
		(profiles[loser] :: Profile).stats.streak = 0
	end
	for _, p in { winner, loser } do
		Profiles.event(p, "matchPlayed")
		if ranked then
			Profiles.event(p, "rankedPlayed")
		end
	end

	-- Classé : seulement entre deux joueurs, hors serveur privé (Elo).
	local deltas = {}
	if ranked then
		local a, b = profiles[winner :: Player], profiles[loser :: Player]
		if a and b then
			local ra, rb = a.ranked.rating, b.ranked.rating
			local expected = 1 / (1 + 10 ^ ((rb - ra) / 400))
			local delta = math.max(1, math.floor(RK.K * (1 - expected) + 0.5))
			a.ranked.rating += delta
			b.ranked.rating = math.max(0, b.ranked.rating - delta)
			a.ranked.games += 1
			b.ranked.games += 1
			a.ranked.wins += 1
			a.ranked.peak = math.max(a.ranked.peak, a.ranked.rating)
			deltas[winner], deltas[loser] = delta, -delta
			for _, p in { winner :: Player, loser :: Player } do
				publish(p)
				local prof = profiles[p]
				if board and prof.ranked.games >= RK.PLACEMENT_GAMES then
					task.spawn(function()
						pcall(function()
							(board :: OrderedDataStore):SetAsync(tostring(p.UserId), math.floor(prof.ranked.rating))
						end)
					end)
				end
			end
		end
	end

	-- Écran de fin : ce que chacun a gagné.
	for _, p in { winner, loser } do
		local prof = Profiles.get(p)
		if prof and p.Parent then
			local ms = matchStats[p] or {}
			rewardsRemote:FireClient(p, "rewards", {
				stats = {
					accuracy = if (ms.shots or 0) > 0 then math.floor((ms.hits or 0) / ms.shots * 100 + 0.5) else 0,
					hits = ms.hits or 0,
					kills = ms.kills or 0,
				},
				ranked = ranked,
				xp = matchXp[p] or 0,
				level = prof.level,
				levelUp = prof.level > (levelsBefore[p] or prof.level),
				ratingDelta = deltas[p],
				rating = math.floor(prof.ranked.rating + 0.5),
				rankKey = p:GetAttribute("RankKey"),
				vsBot = vsBot,
				forfeit = forfeit == true,
			})
			matchXp[p] = 0
			matchStats[p] = nil
			publish(p)
			task.spawn(save, p)
		end
	end
end

-- Classement mondial : rafraîchi régulièrement et publié dans ReplicatedStorage.Match.
local nameCache: { [number]: string } = {}
local function refreshBoard()
	if not board then
		return
	end
	local ok, pages = pcall(function()
		return (board :: OrderedDataStore):GetSortedAsync(false, RK.LEADERBOARD_SIZE)
	end)
	if not ok then
		return
	end
	local list = {}
	for i, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = userId and nameCache[userId]
		if userId and not name then
			local okName, res = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			name = if okName then res else ("#" .. entry.key)
			nameCache[userId] = name
		end
		table.insert(list, { rank = i, name = name or "?", rating = entry.value })
	end
	local match = ReplicatedStorage:FindFirstChild("Match")
	if match then
		match:SetAttribute("Leaderboard", HttpService:JSONEncode(list))
	end
end

Players.PlayerAdded:Connect(load)
for _, p in Players:GetPlayers() do
	task.spawn(load, p)
end
Players.PlayerRemoving:Connect(function(player)
	-- On laisse d'abord le mode traiter le départ (un forfait en plein match compte comme
	-- une défaite classée : partir ne doit pas éviter de perdre des points).
	task.wait()
	save(player)
	profiles[player] = nil
	loaded[player] = nil
	dirty[player] = nil
	matchXp[player] = nil
	matchStats[player] = nil
end)
game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		save(p)
	end
end)

-- Sauvegarde régulière (en cas de plantage du serveur) et classement mondial.
task.spawn(function()
	refreshBoard()
	while true do
		task.wait(90)
		for p, prof in profiles do
			if refreshDaily(p, prof) then
				publish(p) -- minuit UTC passé : nouveaux défis
			end
		end
		for p, isDirty in dirty do
			if isDirty and p.Parent then
				task.spawn(save, p)
			end
		end
		refreshBoard()
	end
end)

return Profiles
