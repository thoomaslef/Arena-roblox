-- Serveur : mode 3v3 « Évasion » (l'Élite de ShootMania) — portage de scripts/modes/elite.gd.
--
-- Chaque manche : 1 attaquant (3 armures, Rail partout) contre les 3 joueurs de l'autre équipe
-- (1 armure, roquettes rechargées en 1,6 s, Rail sur les plateformes). Les deux coéquipiers de
-- l'attaquant regardent la manche (vue spectateur).
--   * l'attaquant gagne la manche (+1 point pour son équipe) en éliminant les 3 défenseurs ou
--     en restant 2 s dans la zone du poteau, qui s'active au bout de 15 s ;
--   * la défense gagne en éliminant l'attaquant ou si les 60 s s'écoulent (pas de point :
--     comme dans ShootMania, seules les attaques réussies rapportent).
-- Les équipes alternent l'attaque, l'attaquant change à chaque tour de son équipe.
-- Premier à 5 points avec 2 d'écart (9 maximum). Places vides : complétées par des bots.
--
-- Même interface que Joust pour Main : init, spawnCFrame, onCharacterReady, livesFor, kill,
-- et les rappels de progression (onMatchStarted, onRoundWon, onMatchEnded, allowBot).
-- Attributs de ReplicatedStorage.Match (en plus de State, Round, Score1/2…) :
--   Mode = "elite", AttackTeam, Attacker (nom), DefendersAlive, RoundEnd, PoleUnlock
--   (heures serveur), Capture (0..1), PolePos (m) ; ObjectValue « Spectate » (personnage suivi).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rocket = require(Shared.Rocket)
local MapBuilder = require(Shared.MapBuilder)
local Bots = require(script.Parent.Bot)

local S = Config.STUDS_PER_METER
local E = Config.Elite

local Elite = {}

local map = nil
local tutorialMap = nil
local Combat = nil

local matchFolder = Instance.new("Folder")
matchFolder.Name = "Match"
matchFolder.Parent = ReplicatedStorage
local spectateValue = Instance.new("ObjectValue")
spectateValue.Name = "Spectate"
spectateValue.Parent = matchFolder

local matchRemote: RemoteEvent

local state = "waiting"
local teams: { { any } } = { {}, {} } -- [1] = Flics (camp 0), [2] = Bandits (camp 1)
local score = { 0, 0 }
local round = 0
local attacking = 0 -- camp qui attaque cette manche
local attackerIdx = { 0, 0 }
local attacker: any = nil
local defenders: { any } = {}
local alive: { [any]: boolean } = {}
local spawnFor: { [any]: CFrame } = {}
local liveStart = 0
local capture = 0
local poleAnnounced = false
local matchToken = 0
local fillToken = 0
local roundOver = false

-- Rappels (branchés par Main sur la progression et les salons privés).
function Elite.onMatchStarted(_all: { any }) end
function Elite.onRoundWon(_winners: { any }, _losers: { any }) end
function Elite.onMatchEnded(_winners: { any }, _losers: { any }, _forfeit: boolean) end
function Elite.allowBot(): boolean
	return true
end

local function setState(s: string)
	state = s
	matchFolder:SetAttribute("State", s)
end

local function teamOf(p: any): number?
	local t = p:GetAttribute("Team")
	return if type(t) == "number" then t else nil
end

local function isParticipant(p: any): boolean
	if p == attacker then
		return true
	end
	return table.find(defenders, p) ~= nil
end

local function inMatch(p: any): boolean
	return table.find(teams[1], p) ~= nil or table.find(teams[2], p) ~= nil
end

local function isBot(p: any): boolean
	return typeof(p) ~= "Instance"
end

local function aliveDefenders(): number
	local n = 0
	for _, d in defenders do
		if alive[d] then
			n += 1
		end
	end
	return n
end

local function publish()
	matchFolder:SetAttribute("Round", round)
	matchFolder:SetAttribute("Score1", score[1])
	matchFolder:SetAttribute("Score2", score[2])
	matchFolder:SetAttribute("AttackTeam", attacking)
	matchFolder:SetAttribute("Attacker", if attacker then attacker.DisplayName else "")
	matchFolder:SetAttribute("DefendersAlive", aliveDefenders())
	-- Bandeau du score : noms des camps (pas de joueur seul comme en 1v1).
	matchFolder:SetAttribute("Name1", "")
	matchFolder:SetAttribute("Name2", "")
	matchFolder:SetAttribute("UserId1", 0)
	matchFolder:SetAttribute("UserId2", 0)
end

local function readyPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Mode") == "play" then
			table.insert(list, p)
		end
	end
	return list
end

-- Poteau ----------------------------------------------------------------------------------
local pole = {}
local function buildPole()
	local cf = (map.objects.pole and map.objects.pole[1]) or CFrame.new(map.center * S)
	local base = cf.Position -- pieds (studs)
	pole.pos = base / S
	matchFolder:SetAttribute("PolePos", pole.pos)
	local model = Instance.new("Model")
	model.Name = "Pole"
	local function part(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, transparency: number?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Anchored = true
		p.CanCollide = name == "Pillar" or name == "Base"
		p.CanQuery = name == "Pillar" or name == "Base"
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material
		p.Transparency = transparency or 0
		p.Parent = model
		return p
	end
	local up = CFrame.Angles(0, 0, math.pi / 2) -- cylindre vertical
	part("Base", Enum.PartType.Cylinder, Vector3.new(0.3 * S, 1.4 * S, 1.4 * S), CFrame.new(base + Vector3.new(0, 0.15 * S, 0)) * up, Color3.fromRGB(64, 71, 89), Enum.Material.Metal)
	pole.pillar = part("Pillar", Enum.PartType.Cylinder, Vector3.new(5 * S, 0.32 * S, 0.32 * S), CFrame.new(base + Vector3.new(0, 2.6 * S, 0)) * up, Color3.fromRGB(128, 133, 148), Enum.Material.Neon)
	local r = E.CAPTURE_RADIUS * 2 * S
	pole.ring = part("Ring", Enum.PartType.Cylinder, Vector3.new(0.05 * S, r, r), CFrame.new(base + Vector3.new(0, 0.03 * S, 0)) * up, Color3.new(1, 1, 1), Enum.Material.Neon, 0.75)
	pole.fill = part("Fill", Enum.PartType.Cylinder, Vector3.new(0.06 * S, 0.01, 0.01), CFrame.new(base + Vector3.new(0, 0.05 * S, 0)) * up, Color3.new(1, 1, 1), Enum.Material.Neon, 0.35)
	pole.light = Instance.new("PointLight")
	pole.light.Range = 9 * S
	pole.light.Brightness = 0
	pole.light.Parent = pole.pillar
	model.Parent = map.model
end

local function setPole(active: boolean, frac: number, color: Color3)
	if not pole.pillar then
		return
	end
	local c = if active then color else Color3.fromRGB(128, 133, 148)
	pole.pillar.Color = c
	pole.ring.Color = if active then color else Color3.new(1, 1, 1)
	pole.ring.Transparency = if active then 0.55 else 0.8
	pole.light.Color = c
	pole.light.Brightness = if active then 2 + frac * 4 else 0
	local d = math.max(0.01, E.CAPTURE_RADIUS * 2 * S * math.clamp(frac, 0, 1))
	pole.fill.Size = Vector3.new(0.06 * S, d, d)
	pole.fill.Color = color
end

local function inZone(p: any): boolean
	local feet = Rocket.feetOf(p.Character)
	if not feet or not pole.pos then
		return false
	end
	local flat = Vector2.new(feet.X - pole.pos.X, feet.Z - pole.pos.Z).Magnitude
	return flat <= E.CAPTURE_RADIUS and math.abs(feet.Y - pole.pos.Y) < E.CAPTURE_HEIGHT
end

-- Personnages ------------------------------------------------------------------------------
function Elite.spawnCFrame(player: any): CFrame
	if typeof(player) == "Instance" and player:GetAttribute("Mode") == "tutorial" and tutorialMap then
		return tutorialMap.spawns[1]
	end
	local defSpawns = map.objects.spawn_defender or map.spawns
	return spawnFor[player] or defSpawns[1] or CFrame.new(map.center * S)
end

-- Vies au début : 3 pour l'attaquant, 1 pour un défenseur (3 en entraînement / tutoriel).
function Elite.livesFor(player: any): number
	if player == attacker then
		return E.ATTACKER_LIVES
	elseif table.find(defenders, player) then
		return E.DEFENDER_LIVES
	end
	return Config.Joust.LIVES
end

local function applyFreeze(p: any)
	local c = p.Character
	if c then
		local frozen = state == "countdown" and isParticipant(p)
		c:SetAttribute("Frozen", frozen)
		c:SetAttribute("CanFire", not frozen)
	end
end

function Elite.onCharacterReady(p: any)
	alive[p] = true
	local c = p.Character
	if c then
		-- Armes du rôle : l'attaquant a le Rail partout ; les roquettes rechargent en 1,6 s.
		c:SetAttribute("ForcedWeapon", if p == attacker then "rail" else nil)
		if isParticipant(p) then
			c:SetAttribute("RocketMax", E.ROCKET_CHARGES)
			c:SetAttribute("RocketReload", E.ROCKET_RELOAD)
		end
		p:SetAttribute("MaxLives", Elite.livesFor(p))
		Combat.resetArms(p)
	end
	applyFreeze(p)
end

function Elite.canBeHit(p: any): boolean
	if not alive[p] or not p.Character then
		return false
	end
	return state == "live" or state == "waiting"
end

local function despawn(p: any)
	alive[p] = nil
	local c = p.Character
	if c then
		p.Character = nil
		c:Destroy()
	end
	if isBot(p) and p.ctrl then
		p.ctrl:destroy()
		p.ctrl = nil
	end
end

-- Fin de manche ------------------------------------------------------------------------------
local function matchWinner(): number?
	for i = 1, 2 do
		local s, o = score[i], score[3 - i]
		if (s >= E.WIN_SCORE and s - o >= E.WIN_GAP) or s >= E.MAX_SCORE then
			return i
		end
	end
	return nil
end

local function endRound(winTeam: number, byAttack: boolean, reasonKey: string)
	if roundOver or state ~= "live" then
		return
	end
	roundOver = true
	local token = matchToken
	if byAttack then
		score[winTeam + 1] += 1
		Elite.onRoundWon({ attacker }, defenders)
	else
		local winners = {}
		for _, d in defenders do
			if alive[d] then
				table.insert(winners, d)
			end
		end
		Elite.onRoundWon(winners, { attacker })
	end
	setState("post")
	publish()
	matchRemote:FireAllClients("eliteResult", winTeam, byAttack, reasonKey)
	task.delay(E.ROUND_END_PAUSE, function()
		if token ~= matchToken then
			return
		end
		local champ = matchWinner()
		if champ then
			setState("matchEnd")
			matchRemote:FireAllClients("matchEnd", champ, score[1], score[2])
			Elite.onMatchEnded(teams[champ], teams[3 - champ], false)
			task.delay(Config.Joust.MATCH_END_PAUSE, function()
				if token == matchToken then
					Elite.startMatch()
				end
			end)
		else
			attackerIdx[attacking + 1] += 1
			attacking = 1 - attacking
			Elite.newRound()
		end
	end)
end

-- Élimine un joueur. cause : "rocket" (killer requis), "gas", "fall".
function Elite.kill(p: any, cause: string, killer: any)
	if not isParticipant(p) or state == "waiting" then
		-- Entraînement, tutoriel, spectateur : on réapparaît simplement.
		alive[p] = false
		task.delay(1.0, function()
			if typeof(p) ~= "Instance" or not p.Parent or isParticipant(p) then
				return
			end
			local mode = p:GetAttribute("Mode")
			if mode == "tutorial" or (mode == "play" and state == "waiting") then
				p:LoadCharacter()
			end
		end)
		return
	end
	if not alive[p] then
		return
	end
	local feet = Rocket.feetOf(p.Character)
	alive[p] = false
	p:SetAttribute("Lives", 0)
	local killerName, killerTeam = nil, nil
	if cause == "rocket" and killer then
		killerName = killer.DisplayName
		killerTeam = teamOf(killer)
	elseif cause == "rocket" then
		cause = "gas"
	end
	matchRemote:FireAllClients("death", feet, cause, killerName, p.DisplayName, killerTeam, math.random(6), teamOf(p) or 0)
	despawn(p)
	matchFolder:SetAttribute("DefendersAlive", aliveDefenders())
	if state ~= "live" then
		return
	end
	if p == attacker then
		endRound(1 - attacking, false, "el.reason_attacker")
	elseif aliveDefenders() == 0 then
		endRound(attacking, true, "el.reason_defense")
	else
		-- Le défenseur éliminé regarde la suite.
		spectateValue.Value = if attacker and alive[attacker] then attacker.Character else nil
	end
end

-- Manches ---------------------------------------------------------------------------------------
function Elite.newRound()
	local token = matchToken
	round += 1
	roundOver = false
	capture = 0
	poleAnnounced = false
	local attTeam = teams[attacking + 1]
	local defTeam = teams[2 - attacking]
	if #attTeam == 0 or #defTeam == 0 then
		Elite.startMatch()
		return
	end
	attacker = attTeam[attackerIdx[attacking + 1] % #attTeam + 1]
	defenders = table.clone(defTeam)

	-- Tout le monde quitte le terrain ; seuls l'attaquant et les défenseurs y reviennent.
	for _, list in teams do
		for _, p in list do
			despawn(p)
			p:SetAttribute("Role", if p == attacker then "attacker" elseif table.find(defenders, p) then "defender" else "spectator")
		end
	end
	local attSpawns = map.objects.spawn_attacker or map.spawns
	local defSpawns = map.objects.spawn_defender or map.spawns
	spawnFor[attacker] = attSpawns[1]
	for i, d in defenders do
		spawnFor[d] = defSpawns[(i - 1) % #defSpawns + 1]
	end

	setState("countdown")
	matchFolder:SetAttribute("Capture", 0)
	matchFolder:SetAttribute("RoundEnd", nil)
	matchFolder:SetAttribute("PoleUnlock", nil)
	setPole(false, 0, Config.Teams[attacking].color)
	publish()
	local participants = { attacker }
	for _, d in defenders do
		table.insert(participants, d)
	end
	for _, p in participants do
		alive[p] = false
		p:LoadCharacter()
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 6 do
			local ready = true
			for _, p in participants do
				if not alive[p] then
					ready = false
				end
			end
			if ready then
				break
			end
			task.wait(0.1)
		end
		if token ~= matchToken then
			return
		end
		spectateValue.Value = if attacker then attacker.Character else nil
		matchFolder:SetAttribute("CountdownEnd", Workspace:GetServerTimeNow() + Config.Joust.COUNTDOWN)
		matchRemote:FireAllClients("countdown", round)
		task.wait(Config.Joust.COUNTDOWN)
		if token ~= matchToken or state ~= "countdown" then
			return
		end
		setState("live")
		liveStart = os.clock()
		local now = Workspace:GetServerTimeNow()
		matchFolder:SetAttribute("RoundEnd", now + E.ROUND_TIME)
		matchFolder:SetAttribute("PoleUnlock", now + E.POLE_UNLOCK)
		matchFolder:SetAttribute("LiveStart", now)
		for _, p in participants do
			applyFreeze(p)
		end
	end)
end

local function removeBots()
	for _, list in teams do
		for i = #list, 1, -1 do
			local p = list[i]
			if isBot(p) then
				despawn(p)
				p:destroy()
				table.remove(list, i)
			end
		end
	end
end

local function newBot(team: number): any
	local b = Bots.create(Combat, team, Config.Match.BOT_SKILL)
	b:SetAttribute("Team", team)
	b.targetOf = function(me)
		-- Adversaire vivant le plus proche.
		local myFeet = Rocket.feetOf(me.Character)
		local best, bestD = nil, math.huge
		for _, list in teams do
			for _, o in list do
				if teamOf(o) ~= team and alive[o] and o.Character then
					local f = Rocket.feetOf(o.Character)
					if f and myFeet then
						local d = (f - myFeet).Magnitude
						if d < bestD then
							best, bestD = o, d
						end
					end
				end
			end
		end
		return best
	end
	b.goalOf = function(me): (Vector3?, boolean)
		local feet = Rocket.feetOf(me.Character)
		if not feet or not pole.pos then
			return nil, false
		end
		local t = os.clock() - liveStart
		if me == attacker then
			-- Approche, puis capture du poteau quand il s'active.
			local near = (feet - pole.pos).Magnitude < 16
			if state == "live" and t >= E.POLE_UNLOCK - 2 then
				return pole.pos, near and t >= E.POLE_UNLOCK
			end
			local spawn = (spawnFor[me] or CFrame.new()).Position / S
			return spawn:Lerp(pole.pos, 0.55), false
		end
		-- Défenseur : protège le poteau ; y court si l'attaquant le capture.
		if capture > 0 or (attacker and alive[attacker] and inZone(attacker)) then
			return pole.pos, true
		end
		local i = table.find(defenders, me) or 1
		local a = (i * 2.1) + round * 0.7
		return pole.pos + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8), true
	end
	return b
end

function Elite.startMatch()
	matchToken += 1
	fillToken += 1
	matchFolder:SetAttribute("BotAt", nil)
	removeBots()
	local humans = readyPlayers()
	local allowBots = Config.Match.BOT_ENABLED and Elite.allowBot()
	if #humans == 0 or (not allowBots and #humans < 2) then
		teams = { {}, {} }
		attacker, defenders = nil, {}
		setState("waiting")
		publish()
		return
	end
	-- Équipes équilibrées (6 joueurs max), puis bots pour compléter à 3 contre 3.
	teams = { {}, {} }
	for i, p in humans do
		if i > 6 then
			break
		end
		local t = (i - 1) % 2
		table.insert(teams[t + 1], p)
		p:SetAttribute("Team", t)
	end
	if allowBots then
		for t = 0, 1 do
			while #teams[t + 1] < 3 do
				table.insert(teams[t + 1], newBot(t))
			end
		end
	end
	score = { 0, 0 }
	round = 0
	attacking = 0
	attackerIdx = { 0, 0 }
	local all = {}
	for _, list in teams do
		for _, p in list do
			table.insert(all, p)
		end
	end
	Elite.onMatchStarted(all)
	Elite.newRound()
end

-- Seul(s) prêt(s) : on attend d'autres joueurs, puis on complète avec des bots.
local function scheduleFill()
	fillToken += 1
	local token = fillToken
	local wait = if #readyPlayers() >= 6 then 2 else E.FILL_WAIT
	if not (Config.Match.BOT_ENABLED and Elite.allowBot()) and #readyPlayers() < 2 then
		matchFolder:SetAttribute("BotAt", nil)
		return
	end
	matchFolder:SetAttribute("BotAt", Workspace:GetServerTimeNow() + wait)
	task.delay(wait, function()
		if token == fillToken and state == "waiting" and #readyPlayers() >= 1 then
			Elite.startMatch()
		end
	end)
end

-- Un joueur quitte le match (départ ou retour au menu) : un bot prend sa place.
local function leave(p: Player)
	alive[p] = nil
	spawnFor[p] = nil
	local t = teamOf(p)
	if not inMatch(p) or state == "waiting" then
		if state == "waiting" then
			if #readyPlayers() >= 1 then
				scheduleFill()
			else
				fillToken += 1
				matchFolder:SetAttribute("BotAt", nil)
			end
		end
		return
	end
	local list = teams[(t or 0) + 1]
	local idx = table.find(list, p)
	local wasParticipant = isParticipant(p)
	local wasAttacker = p == attacker
	if idx then
		table.remove(list, idx)
	end
	local defIdx = table.find(defenders, p)
	if defIdx then
		table.remove(defenders, defIdx)
	end
	-- Plus aucun humain dans le match : on arrête tout.
	local humansLeft = 0
	for _, l in teams do
		for _, o in l do
			if not isBot(o) then
				humansLeft += 1
			end
		end
	end
	if humansLeft == 0 then
		matchToken += 1
		removeBots()
		teams = { {}, {} }
		attacker, defenders = nil, {}
		setState("waiting")
		publish()
		return
	end
	if Config.Match.BOT_ENABLED and Elite.allowBot() and t then
		table.insert(list, newBot(t)) -- jouera à partir de la manche suivante
	end
	if wasParticipant and state == "live" then
		if wasAttacker then
			attacker = nil
			endRound(1 - attacking, false, "el.reason_attacker")
		elseif aliveDefenders() == 0 then
			endRound(attacking, true, "el.reason_defense")
		end
	end
end

-- Init ------------------------------------------------------------------------------------------
function Elite.init(combat)
	Combat = combat
	matchRemote = Instance.new("RemoteEvent")
	matchRemote.Name = "Match"
	matchRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")

	map = MapBuilder.build(require(Shared.Maps:WaitForChild(E.MAP)), Workspace)
	print(("[Cavale] Mode 3v3 Évasion · map « %s » construite"):format(map.name))
	tutorialMap = MapBuilder.build(require(Shared:WaitForChild("TutorialMap")), Workspace, "TutorialMap", Vector3.new(-320, 0, -320))
	buildPole()
	matchFolder:SetAttribute("Mode", "elite")
	matchFolder:SetAttribute("MapName", E.MAP)
	setState("waiting")
	publish()

	Combat.canBeHit = Elite.canBeHit
	Combat.canFire = function(p: any): boolean
		return alive[p] == true and p.Character ~= nil and (state ~= "countdown" or not isParticipant(p))
	end
	Combat.canDamage = function(a: any, v: any): boolean
		-- Pas de dégâts entre coéquipiers pendant un match.
		local ta, tv = teamOf(a), teamOf(v)
		return state == "waiting" or ta == nil or tv == nil or ta ~= tv
	end
	Combat.onDamage = function(victim: any, by: any, weapon: string?): boolean
		local dmg = if weapon == "rail" then E.RAIL_DAMAGE else 1
		local lives = ((victim:GetAttribute("Lives") or 1) :: number) - dmg
		victim:SetAttribute("Lives", math.max(0, lives))
		if lives <= 0 then
			Elite.kill(victim, "rocket", by)
			return true
		end
		return false
	end

	-- Poteau et chrono.
	local lastCapture = -1
	RunService.Heartbeat:Connect(function(dt)
		if state ~= "live" or roundOver then
			return
		end
		local t = os.clock() - liveStart
		local active = t >= E.POLE_UNLOCK
		if active and not poleAnnounced then
			poleAnnounced = true
			matchRemote:FireAllClients("poleActive")
		end
		if active and attacker and alive[attacker] and inZone(attacker) then
			capture += dt
		else
			capture = math.max(0, capture - dt * 1.5)
		end
		local frac = capture / E.CAPTURE_TIME
		setPole(active, frac, Config.Teams[attacking].color)
		if math.abs(frac - lastCapture) > 0.02 then
			lastCapture = frac
			matchFolder:SetAttribute("Capture", math.clamp(frac, 0, 1))
		end
		if capture >= E.CAPTURE_TIME then
			endRound(attacking, true, "el.reason_pole")
		elseif t >= E.ROUND_TIME then
			endRound(1 - attacking, false, "el.reason_time")
		end
	end)

	-- Accueil : JOUER / TUTORIEL / MENU (comme le 1v1).
	local function onPlay(p: Player)
		if p:GetAttribute("Mode") == "play" then
			return
		end
		p:SetAttribute("Mode", "play")
		if state == "waiting" then
			spawnFor[p] = nil
			p:LoadCharacter() -- entraînement libre en attendant
			scheduleFill()
		end
		-- Sinon : il regarde le match en cours et jouera au suivant.
	end
	local function toMenu(p: Player)
		local was = p:GetAttribute("Mode")
		p:SetAttribute("Mode", "menu")
		if was == "play" then
			leave(p)
		end
		despawn(p)
	end
	local function toTutorial(p: Player)
		if inMatch(p) and state ~= "waiting" then
			return
		end
		local was = p:GetAttribute("Mode")
		p:SetAttribute("Mode", "tutorial")
		if was == "play" then
			leave(p)
		end
		p:LoadCharacter()
	end
	local lobby = Instance.new("RemoteEvent")
	lobby.Name = "Lobby"
	lobby.Parent = ReplicatedStorage:WaitForChild("Remotes")
	lobby.OnServerEvent:Connect(function(p, choice)
		if choice == "play" then
			onPlay(p)
		elseif choice == "tutorial" then
			toTutorial(p)
		elseif choice == "menu" then
			toMenu(p)
		end
	end)

	Players.PlayerAdded:Connect(function(p)
		p:SetAttribute("Mode", "menu")
	end)
	Players.PlayerRemoving:Connect(function(p)
		p:SetAttribute("Mode", "gone")
		leave(p)
	end)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Mode") == nil then
			p:SetAttribute("Mode", "menu")
		end
	end
end

return Elite
