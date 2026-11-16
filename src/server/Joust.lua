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
--   "death", pos(m), text, victimTeam
--   "info", title, sub          message central simple (adversaire parti, etc.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local JoustRules = require(Shared.JoustRules)
local Rocket = require(Shared.Rocket)
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

function Joust.state(): string
	return state
end

-- Point d'apparition (pieds) du joueur.
function Joust.spawnCFrame(player: Player): CFrame
	return spawnFor[player] or map.spawns[1]
end

-- Gel (compte à rebours) : lu par le client via l'attribut « Frozen » du personnage.
local function applyFreeze(player: Player)
	local c = player.Character
	if c then
		c:SetAttribute("Frozen", state == "countdown")
		c:SetAttribute("CanFire", state ~= "countdown")
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
			matchRemote:FireAllClients("matchEnd", champ, score[1], score[2])
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
		-- Entraînement : on réapparaît simplement.
		alive[player] = false
		task.delay(1.0, function()
			if player.Parent and state == "waiting" then
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
	local text
	if cause == "rocket" and killer then
		local ki = indexOf(killer) or 1
		local verbs = JoustRules.KILL_VERBS[ki - 1]
		text = ("%s %s %s"):format(killer.DisplayName, verbs[math.random(#verbs)], player.DisplayName)
	elseif cause == "fall" then
		text = ("%s %s"):format(player.DisplayName, JoustRules.FALL_TEXT[vTeam])
	else
		text = ("%s — Gaz lacrymo"):format(player.DisplayName)
	end
	matchRemote:FireAllClients("death", feet, text, vTeam)

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
		end
	end)
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
	if not Config.Match.BOT_ENABLED then
		matchFolder:SetAttribute("BotAt", nil)
		return
	end
	matchFolder:SetAttribute("BotAt", Workspace:GetServerTimeNow() + Config.Match.BOT_WAIT)
	task.delay(Config.Match.BOT_WAIT, function()
		if token == botToken and state == "waiting" and #Players:GetPlayers() == 1 then
			Joust.startMatch(true)
		end
	end)
end

function Joust.startMatch(withBot: boolean?)
	matchToken += 1
	botToken += 1
	matchFolder:SetAttribute("BotAt", nil)
	local list: { any } = Players:GetPlayers()
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
	fighters = { list[1], list[2] }
	fighters[1]:SetAttribute("Team", 0)
	fighters[2]:SetAttribute("Team", 1)
	score = { 0, 0 }
	round = 0
	Joust.newRound()
end

function Joust.init(builtMap, combat)
	map = builtMap
	Combat = combat
	matchRemote = Instance.new("RemoteEvent")
	matchRemote.Name = "Match"
	matchRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")

	-- Gaz : même rayon que le client, à partir du centre de la map.
	local spawnsM = {}
	for _, cf in map.spawns do
		table.insert(spawnsM, cf.Position / S)
	end
	r0 = JoustRules.initialRadius(map.sizeCells, map.zoneCenter, spawnsM)
	matchFolder:SetAttribute("GasR0", r0)
	matchFolder:SetAttribute("GasCenter", map.zoneCenter)
	setState("waiting")
	publish()

	-- Dégâts de roquette : -1 vie, à 0 c'est éliminé.
	Combat.canBeHit = Joust.canBeHit
	Combat.canFire = function(player: Player): boolean
		-- On peut tirer pendant la pause de fin de manche (sans dégâts), pas au compte à rebours.
		return alive[player] == true and player.Character ~= nil and state ~= "countdown"
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

	Players.PlayerAdded:Connect(function(player)
		if bot and #Players:GetPlayers() >= 2 then
			-- Un vrai adversaire arrive : il remplace le bot tout de suite.
			matchToken += 1
			removeBot()
			fighters = { nil, nil }
			setState("waiting")
			publish()
			matchRemote:FireAllClients("info", "UN ADVERSAIRE ARRIVE", "Le bot laisse sa place · nouveau match")
			task.delay(2, function()
				if state == "waiting" and #Players:GetPlayers() >= 2 then
					Joust.startMatch()
				end
			end)
		elseif state == "waiting" then
			if #Players:GetPlayers() >= 2 then
				botToken += 1
				matchFolder:SetAttribute("BotAt", nil)
				task.delay(2, function()
					if state == "waiting" and #Players:GetPlayers() >= 2 then
						Joust.startMatch()
					end
				end)
			else
				player:LoadCharacter()
				scheduleBot()
			end
		end
		-- Sinon (3e joueur) : spectateur. Les serveurs sont limités à 2 places (voir README).
	end)

	Players.PlayerRemoving:Connect(function(player)
		alive[player] = nil
		spawnFor[player] = nil
		local i = indexOf(player)
		if i and state ~= "waiting" then
			matchToken += 1
			local other = fighters[3 - i]
			if other == bot then
				removeBot()
				other = nil
			end
			fighters = { nil, nil }
			setState("waiting")
			publish()
			matchRemote:FireAllClients("info", "ADVERSAIRE PARTI", "Victoire par forfait · en attente d'un adversaire")
			task.delay(3, function()
				if state ~= "waiting" then
					return
				end
				if #Players:GetPlayers() >= 2 then
					Joust.startMatch()
				elseif other and other.Parent then
					spawnFor[other] = nil
					other:LoadCharacter()
					scheduleBot()
				end
			end)
		end
	end)

	for _, p in Players:GetPlayers() do
		if not p.Character then
			p:LoadCharacter()
		end
	end
	if #Players:GetPlayers() >= 2 then
		Joust.startMatch()
	elseif #Players:GetPlayers() == 1 then
		scheduleBot()
	end
end

return Joust
