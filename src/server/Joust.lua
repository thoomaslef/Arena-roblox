-- Serveur : mode 1v1 « Règlement de comptes » (portage de scripts/modes/joust.gd).
--
-- États : "waiting" (moins de 2 joueurs : entraînement libre) → "countdown" (3 s, on vise
-- sans bouger ni tirer) → "live" (le gaz se resserre) → "post" (3 s) → manche suivante,
-- ou "matchEnd" quand un joueur a 11 points avec 2 d'écart.
--
-- L'état est répliqué par les attributs du dossier ReplicatedStorage.Match ; les
-- événements ponctuels passent par le RemoteEvent Remotes.Match :
--   "countdown", round          début du compte à rebours
--   "result", winner            1 ou 2 (camp gagnant de la manche), 0 = égalité
--   "matchEnd", winner, s1, s2
--   "death", pos(m), cause, killerName, victimName, killerTeam, verbIndex, victimTeam
--   "info", titleKey, subKey    message central simple (clés de texte Lang)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local JoustRules = require(Shared.JoustRules)
local Rocket = require(Shared.Rocket)
local MapBuilder = require(Shared.MapBuilder)
local Bots = require(script.Parent.Bot)

local S = Config.STUDS_PER_METER
local J = Config.Joust

local Joust = {}

local map = nil
local Combat = nil

local matchFolder = Instance.new("Folder")
matchFolder.Name = "Match"
matchFolder.Parent = ReplicatedStorage

local matchRemote: RemoteEvent

-- Les deux combattants : [1] = Flics (camp 0), [2] = Bandits (camp 1).
local fighters: { Player? } = { nil, nil }
local score = { 0, 0 }
local round = 0
local state = "waiting"
local alive: { [Player]: boolean } = {}
local spawnFor: { [Player]: CFrame } = {}
local liveStart = 0 -- os.clock() du GO
local r0 = 30
local judging = false
local matchToken = 0 -- invalide les minuteurs d'un match précédent

local function setState(s: string)
	state = s
	matchFolder:SetAttribute("State", s)
end

local function publish()
	matchFolder:SetAttribute("Round", round)
	matchFolder:SetAttribute("Score1", score[1])
	matchFolder:SetAttribute("Score2", score[2])
	for i = 1, 2 do
		local p = fighters[i]
		matchFolder:SetAttribute("Name" .. i, if p then p.DisplayName else "")
		matchFolder:SetAttribute("UserId" .. i, if p then p.UserId else 0)
	end
end

local function indexOf(player: Player): number?
	if fighters[1] == player then
		return 1
	elseif fighters[2] == player then
		return 2
	end
	return nil
end

-- Événements pour la progression (branchés par Main sur Profiles).
function Joust.onMatchStarted(_fighters: { any }) end
-- Le bot peut-il venir ? (pas dans un salon privé entre amis : branché par Main)
function Joust.allowBot(): boolean
	return true
end
function Joust.onRoundWon(_winner: any, _loser: any) end
function Joust.onMatchEnded(_winner: any, _loser: any, _forfeit: boolean) end

function Joust.state(): string
	return state
end

-- Modes d'un joueur (attribut « Mode », lu aussi par le client) :
--   "menu"     : écran d'accueil, pas de personnage, pas compté pour les matchs ;
--   "play"     : a cliqué sur JOUER, compté pour les matchs (et le bot) ;
--   "tutorial" : sur le terrain du tutoriel, à l'écart de l'arène.
local tutorialMap = nil

local function readyPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Mode") == "play" then
			table.insert(list, p)
		end
	end
	return list
end

-- Point d'apparition (pieds) du joueur.
function Joust.spawnCFrame(player: Player): CFrame
	if typeof(player) == "Instance" and player:GetAttribute("Mode") == "tutorial" and tutorialMap then
		return tutorialMap.spawns[1]
	end
	return spawnFor[player] or map.spawns[1]
end

-- Gel (compte à rebours) : lu par le client via l'attribut « Frozen » du personnage.
local function applyFreeze(player: Player)
	local c = player.Character
	if c then
		-- Seuls les deux combattants sont gelés (pas un joueur dans le tutoriel).
		local frozen = state == "countdown" and indexOf(player) ~= nil
		c:SetAttribute("Frozen", frozen)
		c:SetAttribute("CanFire", not frozen)
	end
end

-- Appelé par Main quand le personnage est prêt (rig fait, posé au spawn).
function Joust.onCharacterReady(player: Player)
	alive[player] = true
	applyFreeze(player)
end

function Joust.canBeHit(player: Player): boolean
	if not alive[player] or not player.Character then
		return false
	end
	return state == "live" or state == "waiting"
end

local function judge(token: number)
	judging = false
	if token ~= matchToken or state ~= "live" then
		return
	end
	local a1 = fighters[1] and alive[fighters[1] :: Player]
	local a2 = fighters[2] and alive[fighters[2] :: Player]
	local winner = 0
	if a1 and not a2 then
		winner = 1
	elseif a2 and not a1 then
		winner = 2
	elseif a1 and a2 then
		return -- personne n'est mort (ne devrait pas arriver)
	end
	setState("post")
	if winner == 0 then
		round -= 1 -- manche rejouée
	else
		score[winner] += 1
		Joust.onRoundWon(fighters[winner], fighters[3 - winner])
	end
	publish()
	matchRemote:FireAllClients("result", winner)
	task.delay(J.ROUND_END_PAUSE, function()
		if token ~= matchToken then
			return
		end
		local champ = JoustRules.matchWinner(score[1], score[2])
		if champ then
			setState("matchEnd")
			Joust.startVote() -- (défini plus bas : on passe par la table Joust)
			matchRemote:FireAllClients("matchEnd", champ, score[1], score[2])
			Joust.onMatchEnded(fighters[champ], fighters[3 - champ], false)
			task.delay(J.MATCH_END_PAUSE, function()
				if token == matchToken then
					Joust.startMatch()
				end
			end)
		else
			Joust.newRound()
		end
	end)
end

-- Élimine un joueur. cause : "rocket" (killer requis), "gas", "fall".
function Joust.kill(player: Player, cause: string, killer: Player?)
	local character = player.Character
	local feet = Rocket.feetOf(character)
	if state == "waiting" or not indexOf(player) then
		-- Entraînement ou tutoriel : on réapparaît simplement.
		alive[player] = false
		task.delay(1.0, function()
			if not player.Parent or indexOf(player) then
				return
			end
			local mode = player:GetAttribute("Mode")
			if mode == "tutorial" or (mode == "play" and state == "waiting") then
				player:LoadCharacter()
			end
		end)
		return
	end
	if not alive[player] then
		return
	end
	alive[player] = false
	player:SetAttribute("Lives", 0)

	local vi = indexOf(player) :: number
	local vTeam = vi - 1
	-- Le texte du fil des éliminations est composé par chaque client, dans sa langue (Lang).
	local killerName, killerTeam = nil, nil
	if cause == "rocket" and killer then
		killerName = killer.DisplayName
		killerTeam = (indexOf(killer) or 1) - 1
	elseif cause == "rocket" then
		cause = "gas"
	end
	matchRemote:FireAllClients("death", feet, cause, killerName, player.DisplayName, killerTeam, math.random(6), vTeam)

	-- Le mort regarde la fin de la manche depuis l'endroit où il est tombé.
	if character then
		player.Character = nil
		character:Destroy()
	end

	if state == "live" and not judging then
		judging = true
		task.delay(J.TIE_GRACE, judge, matchToken)
	end
end

function Joust.newRound()
	local p1, p2 = fighters[1], fighters[2]
	if not p1 or not p2 then
		return
	end
	round += 1
	-- Les côtés alternent à chaque manche.
	local side = round % 2
	spawnFor[p1] = map.spawns[side + 1]
	spawnFor[p2] = map.spawns[2 - side]
	setState("countdown")
	publish()
	judging = false
	local token = matchToken
	for _, p in { p1, p2 } do
		alive[p] = false
		p:LoadCharacter()
	end
	task.spawn(function()
		-- On attend que les deux personnages soient prêts (au plus 5 s).
		local t0 = os.clock()
		while os.clock() - t0 < 5 do
			if alive[p1] and alive[p2] then
				break
			end
			task.wait(0.1)
		end
		if token ~= matchToken then
			return
		end
		matchFolder:SetAttribute("CountdownEnd", Workspace:GetServerTimeNow() + J.COUNTDOWN)
		matchRemote:FireAllClients("countdown", round)
		task.wait(J.COUNTDOWN)
		if token ~= matchToken or state ~= "countdown" then
			return
		end
		setState("live")
		liveStart = os.clock()
		matchFolder:SetAttribute("LiveStart", Workspace:GetServerTimeNow())
		for _, p in { p1, p2 } do
			applyFreeze(p)
			-- GO : réserve de roquettes vide, la recharge part de maintenant.
			if Config.Rocket.START_EMPTY then
				Combat.emptyRockets(p)
			end
		end
	end)
end

-- Maps --------------------------------------------------------------------------------
local currentMap: string? = nil

-- Map du prochain match : au hasard parmi Config.Match.MAPS, différente de l'actuelle.
-- Vote de map en fin de match : 3 maps proposées, chaque joueur vote (clic ou 1 / 2 / 3).
-- Attributs de Match : VoteMaps ("a,b,c"), VoteCounts ("0,1,0"), VoteEnd (heure serveur).
local voteMaps: { string } = {}
local votes: { [Player]: string } = {}
local voteResult: string? = nil

local function publishVotes()
	local counts = {}
	for i, m in voteMaps do
		counts[i] = 0
		for _, v in votes do
			if v == m then
				counts[i] += 1
			end
		end
	end
	matchFolder:SetAttribute("VoteMaps", table.concat(voteMaps, ","))
	matchFolder:SetAttribute("VoteCounts", table.concat(counts, ","))
end

local function startVote()
	if not Config.Match.RANDOM_MAP or not Config.Match.MAP_VOTE then
		return
	end
	local pool = {}
	for _, n in Config.Match.MAPS do
		if n ~= currentMap then
			table.insert(pool, n)
		end
	end
	if #pool < 3 then
		pool = table.clone(Config.Match.MAPS)
	end
	voteMaps = {}
	for _ = 1, math.min(3, #pool) do
		table.insert(voteMaps, table.remove(pool, math.random(#pool)))
	end
	votes = {}
	voteResult = nil
	matchFolder:SetAttribute("VoteEnd", Workspace:GetServerTimeNow() + J.MATCH_END_PAUSE)
	publishVotes()
end

Joust.startVote = startVote

-- Fin du vote : la map la plus votée (égalité ou aucun vote : au hasard parmi les meilleures).
local function endVote()
	if #voteMaps == 0 then
		return
	end
	local best, bestCount = {}, -1
	for _, m in voteMaps do
		local n = 0
		for _, v in votes do
			if v == m then
				n += 1
			end
		end
		if n > bestCount then
			best, bestCount = { m }, n
		elseif n == bestCount then
			table.insert(best, m)
		end
	end
	voteResult = best[math.random(#best)]
	voteMaps, votes = {}, {}
	matchFolder:SetAttribute("VoteMaps", nil)
	matchFolder:SetAttribute("VoteCounts", nil)
	matchFolder:SetAttribute("VoteEnd", nil)
end

function Joust.vote(player: Player, key: any)
	if state == "matchEnd" and type(key) == "string" and table.find(voteMaps, key) then
		votes[player] = key
		publishVotes()
	end
end

local function pickMap(): string
	if voteResult then
		local m = voteResult
		voteResult = nil
		return m
	end
	local pool = Config.Match.MAPS
	if not Config.Match.RANDOM_MAP or #pool <= 1 then
		return pool[1]
	end
	local choices = {}
	for _, name in pool do
		if name ~= currentMap then
			table.insert(choices, name)
		end
	end
	return choices[math.random(#choices)]
end

-- Bot de remplacement ------------------------------------------------------------------
local bot = nil -- bot en jeu (ou nil)
local botToken = 0

local function removeBot()
	if bot then
		alive[bot] = nil
		spawnFor[bot] = nil
		bot:destroy()
		bot = nil
	end
end

-- Objectif du bot (bot_goal de joust.gd) : rester dans le gaz, sinon aller vers l'adversaire.
local function botGoal(b): (Vector3?, boolean)
	local feet = Rocket.feetOf(b.Character)
	if not feet then
		return nil, false
	end
	local radius = if state == "live" then JoustRules.gasRadius(os.clock() - liveStart, r0) else r0
	local safe = radius - J.GAS_WARN_DIST - 2
	local center = map.zoneCenter
	if JoustRules.distToCenter(feet, center) > safe then
		return center, true
	end
	local i = indexOf(b)
	local enemy = i and fighters[3 - i]
	local ef = enemy and alive[enemy] and Rocket.feetOf(enemy.Character)
	if ef and JoustRules.distToCenter(ef, center) < safe then
		return ef, false
	end
	return center, false
end

-- Seul sur le serveur : un bot arrive après Config.Match.BOT_WAIT secondes.
local function scheduleBot()
	botToken += 1
	local token = botToken
	if not Config.Match.BOT_ENABLED or not Joust.allowBot() then
		matchFolder:SetAttribute("BotAt", nil)
		return
	end
	matchFolder:SetAttribute("BotAt", Workspace:GetServerTimeNow() + Config.Match.BOT_WAIT)
	task.delay(Config.Match.BOT_WAIT, function()
		if token == botToken and state == "waiting" and #readyPlayers() == 1 then
			Joust.startMatch(true)
		end
	end)
end

-- Construit la map `name` (src/shared/Maps) à la place de l'ancienne, et recalcule le gaz.
function Joust.loadMap(name: string)
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local data = require(ReplicatedStorage.Shared.Maps:WaitForChild(name))
	map = MapBuilder.build(data, Workspace)
	currentMap = name
	print(("[Cavale] Map « %s » construite, %d spawns"):format(map.name, #map.spawns))
	-- Gaz : même rayon que le client, à partir du centre de la map.
	local spawnsM = {}
	for _, cf in map.spawns do
		table.insert(spawnsM, cf.Position / S)
	end
	r0 = JoustRules.initialRadius(map.sizeCells, map.zoneCenter, spawnsM)
	matchFolder:SetAttribute("GasR0", r0)
	matchFolder:SetAttribute("GasCenter", map.zoneCenter)
	matchFolder:SetAttribute("MapName", name) -- clé de la map (nom traduit par le client)
end

function Joust.startMatch(withBot: boolean?)
	endVote() -- s'il y avait un vote de map en cours, son résultat choisit la prochaine map
	matchToken += 1
	botToken += 1
	matchFolder:SetAttribute("BotAt", nil)
	local list: { any } = readyPlayers()
	if #list >= 2 then
		removeBot()
	elseif #list == 1 and (withBot or bot ~= nil) then
		if not bot then
			bot = Bots.create(Combat, 1, Config.Match.BOT_SKILL)
			bot.targetOf = function(b)
				local i = indexOf(b)
				return i and fighters[3 - i]
			end
			bot.goalOf = botGoal
		end
		list = { list[1], bot }
	else
		removeBot()
		fighters = { nil, nil }
		setState("waiting")
		publish()
		for _, p in list do
			if not p.Character then
				spawnFor[p] = nil
				p:LoadCharacter()
			end
		end
		if #list == 1 then
			scheduleBot()
		end
		return
	end
	-- Nouveau match : nouvelle map (tirée au hasard).
	local nextMap = pickMap()
	if nextMap ~= currentMap then
		Joust.loadMap(nextMap)
	end
	fighters = { list[1], list[2] }
	fighters[1]:SetAttribute("Team", 0)
	fighters[2]:SetAttribute("Team", 1)
	score = { 0, 0 }
	round = 0
	Joust.onMatchStarted(fighters)
	Joust.newRound()
end

function Joust.init(combat)
	Combat = combat
	matchRemote = Instance.new("RemoteEvent")
	matchRemote.Name = "Match"
	matchRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")

	Joust.loadMap(pickMap())
	-- Terrain du tutoriel, construit une fois, loin de l'arène (aucune interférence).
	tutorialMap = MapBuilder.build(require(ReplicatedStorage.Shared:WaitForChild("TutorialMap")), Workspace, "TutorialMap", Vector3.new(-320, 0, -320))
	setState("waiting")
	publish()

	-- Dégâts de roquette : -1 vie, à 0 c'est éliminé.
	Combat.canBeHit = Joust.canBeHit
	Combat.canFire = function(player: Player): boolean
		-- On peut tirer pendant la pause de fin de manche (sans dégâts), pas au compte à rebours
		-- (sauf dans le tutoriel, qui ne participe pas au match).
		return alive[player] == true and player.Character ~= nil and (state ~= "countdown" or indexOf(player) == nil)
	end
	Combat.onDamage = function(victim: Player, attacker: Player?): boolean
		local lives = ((victim:GetAttribute("Lives") or J.LIVES) :: number) - 1
		victim:SetAttribute("Lives", math.max(0, lives))
		if lives <= 0 then
			Joust.kill(victim, "rocket", attacker)
			return true
		end
		return false
	end

	-- Hors du gaz = mort immédiate.
	RunService.Heartbeat:Connect(function()
		if state ~= "live" then
			return
		end
		local radius = JoustRules.gasRadius(os.clock() - liveStart, r0)
		for _, p in fighters do
			if p and alive[p] then
				local feet = Rocket.feetOf(p.Character)
				if feet and JoustRules.distToCenter(feet, map.zoneCenter) > radius then
					Joust.kill(p, "gas")
				end
			end
		end
	end)

	-- Un joueur clique sur JOUER : il entre dans la file (2 joueurs = match, seul = bot).
	local function onPlay(player: Player)
		if player:GetAttribute("Mode") == "play" then
			return
		end
		player:SetAttribute("Mode", "play")
		local ready = readyPlayers()
		if bot and #ready >= 2 then
			-- Un vrai adversaire arrive : il remplace le bot tout de suite.
			matchToken += 1
			removeBot()
			fighters = { nil, nil }
			setState("waiting")
			publish()
			matchRemote:FireAllClients("info", "info.opponent_joining", "info.opponent_joining_sub")
			task.delay(2, function()
				if state == "waiting" and #readyPlayers() >= 2 then
					Joust.startMatch()
				end
			end)
		elseif state == "waiting" then
			spawnFor[player] = nil
			player:LoadCharacter() -- entraînement libre en attendant
			if #ready >= 2 then
				botToken += 1
				matchFolder:SetAttribute("BotAt", nil)
				task.delay(2, function()
					if state == "waiting" and #readyPlayers() >= 2 then
						Joust.startMatch()
					end
				end)
			else
				scheduleBot()
			end
		end
		-- Sinon (match déjà complet) : il attend la fin. Serveurs limités à 2 places (README).
	end

	-- Un joueur quitte le match (départ du serveur ou retour au menu) : forfait.
	local function leave(player: Player)
		alive[player] = nil
		spawnFor[player] = nil
		local i = indexOf(player)
		if i and state ~= "waiting" then
			matchToken += 1
			local other = fighters[3 - i]
			-- Forfait : le match compte (victoire pour celui qui reste), sauf s'il était déjà fini.
			if state ~= "matchEnd" and other then
				Joust.onMatchEnded(other, player, true)
			end
			if other == bot then
				removeBot()
				other = nil
			end
			fighters = { nil, nil }
			setState("waiting")
			publish()
			matchRemote:FireAllClients("info", "info.opponent_left", "info.opponent_left_sub")
			task.delay(3, function()
				if state ~= "waiting" then
					return
				end
				if #readyPlayers() >= 2 then
					Joust.startMatch()
				elseif other and other.Parent then
					spawnFor[other] = nil
					other:LoadCharacter()
					scheduleBot()
				end
			end)
		elseif state == "waiting" and #readyPlayers() <= 1 then
			-- Plus qu'un joueur prêt (ou aucun) : on relance l'attente du bot.
			if #readyPlayers() == 1 then
				scheduleBot()
			else
				botToken += 1
				matchFolder:SetAttribute("BotAt", nil)
			end
		end
	end

	local function toMenu(player: Player)
		local wasMode = player:GetAttribute("Mode")
		player:SetAttribute("Mode", "menu")
		if wasMode == "play" then
			leave(player)
		end
		local c = player.Character
		if c then
			alive[player] = nil
			player.Character = nil
			c:Destroy()
		end
	end

	local function toTutorial(player: Player)
		if indexOf(player) and state ~= "waiting" then
			return -- en plein match : pas de tutoriel
		end
		local wasMode = player:GetAttribute("Mode")
		player:SetAttribute("Mode", "tutorial")
		if wasMode == "play" then
			leave(player)
		end
		player:LoadCharacter()
	end

	-- Écran d'accueil → serveur.
	local lobby = Instance.new("RemoteEvent")
	lobby.Name = "Lobby"
	lobby.Parent = ReplicatedStorage:WaitForChild("Remotes")
	lobby.OnServerEvent:Connect(function(player, choice, arg)
		if choice == "vote" then
			Joust.vote(player, arg)
		elseif choice == "play" then
			onPlay(player)
		elseif choice == "tutorial" then
			toTutorial(player)
		elseif choice == "menu" then
			toMenu(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Mode", "menu")
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("Mode", "gone")
		leave(player)
	end)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Mode") == nil then
			p:SetAttribute("Mode", "menu")
		end
	end
end

return Joust
