-- Serveur : roquettes faisant foi. Le client affiche son tir tout de suite (prédiction),
-- le serveur vérifie le tir (charges, cadence, position), simule la roquette, applique
-- les dégâts et envoie les poussées aux joueurs touchés.
--
-- Messages vers les clients (RemoteEvent « Combat », un seul canal pour garder l'ordre) :
--   "spawn",   id, shooterUserId, clientId, spawn(m), vel(m/s), serverTime
--   "explode", id, ownerUserId, pos(m) ou nil (roquette expirée), normal
--   "rail",    shooterUserId, muzzle(m), end(m), team   → rayon visible (sauf chez le tireur)
--   "detonated"                                 → au tireur du Rail (« Roquette détruite en vol ! »)
--   "push",    impulse(m/s)                     → au joueur poussé (sauf le tireur)
--   "hit",     victimName, killed               → au tireur (marqueur de touche, « +1 »)
--   "damaged", fromPos(m), livesLeft            → à la victime
--   "reject",  clientId, charges                → au tireur (tir refusé)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rocket = require(Shared.Rocket)
local Rail = require(Shared.Rail)

local R = Config.Rocket
local RL = Config.Rail

local Combat = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local fireRemote = Instance.new("RemoteEvent")
fireRemote.Name = "Fire"
fireRemote.Parent = remotes
local railRemote = Instance.new("RemoteEvent")
railRemote.Name = "FireRail"
railRemote.Parent = remotes
local combatRemote = Instance.new("RemoteEvent")
combatRemote.Name = "Combat"
combatRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

-- Combattants : joueurs + bots. Un bot est une table qui imite un Player (Name, UserId,
-- Character, Parent, Get/SetAttribute) et reçoit les messages par onCombatEvent.
Combat.bots = {} :: { any }

function Combat.combatants(): { any }
	local list: { any } = Players:GetPlayers()
	for _, b in Combat.bots do
		table.insert(list, b)
	end
	return list
end

function Combat.ownerOf(model: Instance?): any
	if not model then
		return nil
	end
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p
	end
	for _, b in Combat.bots do
		if b.Character == model then
			return b
		end
	end
	return nil
end

local function send(target: any, ...)
	if typeof(target) == "Instance" then
		combatRemote:FireClient(target, ...)
	elseif target and target.onCombatEvent then
		target:onCombatEvent(...)
	end
end

-- État d'arme par joueur.
type Arms = { charges: number, rail: number, t: number, lastFire: number, lastRail: number }
local arms: { [any]: Arms } = {}

-- Roquettes en vol.
type Live = {
	id: number,
	owner: any, -- qui a tiré la roquette (calcule sa propre poussée)
	shooter: any, -- à qui reviennent les dégâts (change si un Rail la fait exploser)
	pos: Vector3,
	prev: Vector3,
	vel: Vector3,
	life: number,
	params: RaycastParams,
}
local rockets: { [number]: Live } = {}
Combat.rockets = rockets
local nextId = 0

local worldParams: RaycastParams? = nil
local function world(): RaycastParams
	if not worldParams then
		worldParams = Rocket.worldParams()
	end
	return worldParams :: RaycastParams
end

-- Remis à zéro (début de manche, réapparition).
function Combat.resetArms(player: any)
	arms[player] = { charges = R.CHARGES, rail = RL.CHARGES, t = os.clock(), lastFire = -math.huge, lastRail = -math.huge }
end

local function armsOf(player: any): Arms
	local a = arms[player]
	if not a then
		Combat.resetArms(player)
		a = arms[player]
	end
	local now = os.clock()
	-- Les deux armes se rechargent en continu, même celle qu'on n'a pas en main.
	a.charges = math.min(R.CHARGES, a.charges + (now - a.t) / R.RELOAD)
	a.rail = math.min(RL.CHARGES, a.rail + (now - a.t) / RL.RELOAD)
	a.t = now
	return a
end

-- Gestion des dégâts : remplacée par les règles du mode à l'étape 5.
-- Par défaut : -1 vie, et à 0 on réapparaît avec 3 vies.
function Combat.defaultDamage(victim: Player, attacker: Player?): boolean
	local lives = ((victim:GetAttribute("Lives") or Config.Joust.LIVES) :: number) - 1
	victim:SetAttribute("Lives", math.max(0, lives))
	if lives <= 0 then
		task.delay(1.0, function()
			if victim.Parent then
				victim:LoadCharacter()
			end
		end)
		return true
	end
	return false
end
Combat.onDamage = Combat.defaultDamage

-- Le joueur peut-il être touché ? (vivant, en jeu) — le mode pourra le remplacer.
function Combat.canBeHit(player: Player): boolean
	local lives = player:GetAttribute("Lives")
	return player.Character ~= nil and (lives == nil or (lives :: number) > 0)
end

-- Le joueur peut-il tirer ? — le mode pourra le remplacer.
function Combat.canFire(player: Player): boolean
	return Combat.canBeHit(player)
end

-- Applique une touche (1 vie) et prévient le tireur et la victime.
local function applyHit(victim: any, attacker: any, from: Vector3)
	local killed = Combat.onDamage(victim, attacker)
	if attacker.Parent then
		send(attacker, "hit", victim.DisplayName, killed)
	end
	send(victim, "damaged", from, victim:GetAttribute("Lives"))
end

local function explode(rk: Live, pos: Vector3, n: Vector3)
	rockets[rk.id] = nil
	local shooter = rk.shooter
	combatRemote:FireAllClients("explode", rk.id, rk.owner.UserId, pos, n)
	local wp = world()
	for _, p in Combat.combatants() do
		if not Combat.canBeHit(p) then
			continue
		end
		local feet = Rocket.feetOf(p.Character)
		if not feet then
			continue
		end
		-- Dégâts : jamais sur soi (ni sur un allié, sans objet en 1v1).
		if p ~= shooter and Rocket.damages(pos, n, feet, wp) then
			applyHit(p, shooter, pos)
		end
		-- Poussée : tout le monde ; le lanceur calcule la sienne lui-même (réactivité du rocket jump).
		if p ~= rk.owner then
			local push = Rocket.push(pos, n, feet, wp)
			if push then
				send(p, "push", push)
			end
		end
	end
end

-- Fait exploser une roquette en vol (Rail) : les dégâts reviennent au tireur du Rail.
function Combat.detonate(id: number, by: any)
	local rk = rockets[id]
	if rk then
		rk.shooter = by
		explode(rk, rk.pos, Vector3.yAxis)
	end
end

local function isFiniteVec(v: any): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	for _, c in { v.X, v.Y, v.Z } do
		if c ~= c or c == math.huge or c == -math.huge then
			return false
		end
	end
	return true
end

-- Tir de roquette (joueur via le RemoteEvent, ou bot directement).
function Combat.fireRocket(player: any, clientId: any, eye: any, dir: any, yaw: any)
	if type(clientId) ~= "number" or not isFiniteVec(eye) or not isFiniteVec(dir) or type(yaw) ~= "number" or yaw ~= yaw then
		return
	end
	if dir.Magnitude < 0.5 then
		return
	end
	local a = armsOf(player)
	local now = os.clock()
	local feet = Rocket.feetOf(player.Character)
	local ok = feet ~= nil
		and Combat.canFire(player)
		and a.charges >= R.SERVER_MIN_CHARGE
		and now - a.lastFire >= R.SERVER_MIN_INTERVAL
		and player.Character:GetAttribute("CanFire") ~= false
	if ok then
		local serverEye = (feet :: Vector3) + Vector3.new(0, Config.Body.EYE_HEIGHT, 0)
		ok = (serverEye - eye).Magnitude <= R.SERVER_EYE_TOLERANCE
	end
	if not ok then
		send(player, "reject", clientId, a.charges)
		return
	end
	a.charges -= 1
	a.lastFire = now

	local params = Rocket.shotParams(player.Character)
	local spawn, vel = Rocket.launch(eye, dir, yaw, params)
	nextId += 1
	local rk: Live = { id = nextId, owner = player, shooter = player, pos = spawn, prev = eye, vel = vel, life = 0, params = params }
	rockets[rk.id] = rk
	combatRemote:FireAllClients("spawn", rk.id, player.UserId, clientId, spawn, vel, Workspace:GetServerTimeNow())
end
fireRemote.OnServerEvent:Connect(Combat.fireRocket)

-- Rail --------------------------------------------------------------------------------
-- Dernière fois que le serveur a vu le joueur debout sur une plateforme Rail.
local railSeen: { [any]: number } = {}

local function standingSurface(character: Model?): string?
	local feet = Rocket.feetOf(character)
	if not feet then
		return nil
	end
	local S = Config.STUDS_PER_METER
	local hit = Workspace:Raycast((feet + Vector3.new(0, 0.2, 0)) * S, Vector3.new(0, -0.6 * S, 0), world())
	return hit and hit.Instance:GetAttribute("Surface") or nil
end

task.spawn(function()
	while true do
		task.wait(0.15)
		for _, p in Combat.combatants() do
			if standingSurface(p.Character) == "rail" then
				railSeen[p] = os.clock()
			end
		end
	end
end)

-- Le point vu touché par le tireur est-il crédible côté serveur ?
local function claimValid(victim: any, claim: Vector3, eye: Vector3, dir: Vector3): boolean
	local feet = Rocket.feetOf(victim.Character)
	if not feet then
		return false
	end
	local a, b = feet, feet + Vector3.new(0, Config.Body.HEIGHT, 0)
	local ab = b - a
	local t = math.clamp((claim - a):Dot(ab) / ab:Dot(ab), 0, 1)
	if (claim - (a + ab * t)).Magnitude > Config.Body.RADIUS + RL.SERVER_HIT_TOLERANCE then
		return false
	end
	local to = claim - eye
	if to.Magnitude > RL.RANGE or to.Magnitude < 1e-3 or to.Unit:Dot(dir) < 0.995 then
		return false
	end
	-- Rien de solide entre l'œil et la touche.
	return Workspace:Raycast(eye * Config.STUDS_PER_METER, to * 0.98 * Config.STUDS_PER_METER, world()) == nil
end

-- Tir de Rail. claimModel / claimPoint : personnage et point que le tireur a vus touchés.
function Combat.fireRail(player: any, eye: any, dir: any, yaw: any, claimModel: any, claimPoint: any)
	if not isFiniteVec(eye) or not isFiniteVec(dir) or type(yaw) ~= "number" or yaw ~= yaw or dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local a = armsOf(player)
	local now = os.clock()
	local feet = Rocket.feetOf(player.Character)
	local ok = feet ~= nil
		and Combat.canFire(player)
		and a.rail >= R.SERVER_MIN_CHARGE
		and now - a.lastRail >= RL.SERVER_MIN_INTERVAL
		and now - (railSeen[player] or -math.huge) <= RL.SERVER_RAIL_MEMORY
		and player.Character:GetAttribute("CanFire") ~= false
	if ok then
		local serverEye = (feet :: Vector3) + Vector3.new(0, Config.Body.EYE_HEIGHT, 0)
		ok = (serverEye - eye).Magnitude <= R.SERVER_EYE_TOLERANCE
	end
	if not ok then
		return
	end
	a.rail -= 1
	a.lastRail = now

	local S = Config.STUDS_PER_METER
	local params = Rocket.shotParams(player.Character)
	local hit = Workspace:Raycast(eye * S, dir * RL.RANGE * S, params)
	local stop = if hit then hit.Position / S else eye + dir * RL.RANGE
	local hitPlayer = if hit then Combat.ownerOf(hit.Instance:FindFirstAncestorOfClass("Model")) else nil

	-- Le tireur a vu une touche : on la retient si elle est crédible (favorise le tireur).
	local victim: any = nil
	if typeof(claimModel) == "Instance" and isFiniteVec(claimPoint) then
		local claimed = Combat.ownerOf(claimModel)
		if claimed and claimed ~= player and Combat.canBeHit(claimed) and claimValid(claimed, claimPoint, eye, dir) then
			victim = claimed
			stop = claimPoint
		end
	end
	if not victim and hitPlayer and hitPlayer ~= player and Combat.canBeHit(hitPlayer) then
		victim = hitPlayer
	end

	-- Une roquette sur la trajectoire, avant l'obstacle : elle explose en vol.
	local list = {}
	for id, rk in rockets do
		table.insert(list, { key = id, pos = rk.pos, vel = rk.vel })
	end
	local rid, along = Rail.rocketOnRay(eye, dir, (stop - eye).Magnitude, list, RL.SERVER_ROCKET_LAG)
	local muzzle = Rail.muzzle(eye, dir, yaw)
	local team = player:GetAttribute("Team")
	if rid then
		stop = eye + dir * (along :: number)
		combatRemote:FireAllClients("rail", player.UserId, muzzle, stop, team)
		send(player, "detonated")
		Combat.detonate(rid, player)
		return
	end
	combatRemote:FireAllClients("rail", player.UserId, muzzle, stop, team)
	if victim then
		applyHit(victim, player, eye)
	end
end
railRemote.OnServerEvent:Connect(Combat.fireRail)

RunService.Heartbeat:Connect(function(dt)
	for id, rk in rockets do
		rk.life += dt
		local to = rk.pos + rk.vel * dt
		local hitPos, n = Rocket.sweep(rk.prev, to, rk.params)
		rk.prev = to
		if hitPos then
			explode(rk, hitPos + n * 0.05, n)
		elseif rk.life > R.LIFETIME then
			rockets[id] = nil
			combatRemote:FireAllClients("explode", id, rk.owner.UserId, nil, nil)
		else
			rk.pos = to
		end
	end
end)

function Combat.forget(who: any)
	arms[who] = nil
	railSeen[who] = nil
end
Players.PlayerRemoving:Connect(Combat.forget)

return Combat
