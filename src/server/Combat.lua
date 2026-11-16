-- Serveur : roquettes faisant foi. Le client affiche son tir tout de suite (prédiction),
-- le serveur vérifie le tir (charges, cadence, position), simule la roquette, applique
-- les dégâts et envoie les poussées aux joueurs touchés.
--
-- Messages vers les clients (RemoteEvent « Combat », un seul canal pour garder l'ordre) :
--   "spawn",   id, shooterUserId, clientId, spawn(m), vel(m/s), serverTime
--   "explode", id, shooterUserId, pos(m) ou nil (roquette expirée), normal
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

local R = Config.Rocket

local Combat = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local fireRemote = Instance.new("RemoteEvent")
fireRemote.Name = "Fire"
fireRemote.Parent = remotes
local combatRemote = Instance.new("RemoteEvent")
combatRemote.Name = "Combat"
combatRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

-- État d'arme par joueur.
type Arms = { charges: number, t: number, lastFire: number }
local arms: { [Player]: Arms } = {}

-- Roquettes en vol.
type Live = {
	id: number,
	shooter: Player,
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
function Combat.resetArms(player: Player)
	arms[player] = { charges = R.CHARGES, t = os.clock(), lastFire = -math.huge }
end

local function armsOf(player: Player): Arms
	local a = arms[player]
	if not a then
		Combat.resetArms(player)
		a = arms[player]
	end
	local now = os.clock()
	a.charges = math.min(R.CHARGES, a.charges + (now - a.t) / R.RELOAD)
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

local function explode(rk: Live, pos: Vector3, n: Vector3)
	rockets[rk.id] = nil
	local shooter = rk.shooter
	combatRemote:FireAllClients("explode", rk.id, shooter.UserId, pos, n)
	local wp = world()
	for _, p in Players:GetPlayers() do
		if not Combat.canBeHit(p) then
			continue
		end
		local feet = Rocket.feetOf(p.Character)
		if not feet then
			continue
		end
		-- Dégâts : jamais sur soi (ni sur un allié, sans objet en 1v1).
		if p ~= shooter and Rocket.damages(pos, n, feet, wp) then
			local killed = Combat.onDamage(p, shooter)
			if shooter.Parent then
				combatRemote:FireClient(shooter, "hit", p.DisplayName, killed)
			end
			combatRemote:FireClient(p, "damaged", pos, p:GetAttribute("Lives"))
		end
		-- Poussée : tout le monde ; le tireur calcule la sienne lui-même (réactivité du rocket jump).
		if p ~= shooter then
			local push = Rocket.push(pos, n, feet, wp)
			if push then
				combatRemote:FireClient(p, "push", push)
			end
		end
	end
end

-- Exposé pour le Rail (étape 6) : fait exploser une roquette en vol.
function Combat.detonate(id: number, by: Player)
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

fireRemote.OnServerEvent:Connect(function(player, clientId, eye, dir, yaw)
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
		and Combat.canBeHit(player)
		and a.charges >= R.SERVER_MIN_CHARGE
		and now - a.lastFire >= R.SERVER_MIN_INTERVAL
		and player.Character:GetAttribute("CanFire") ~= false
	if ok then
		local serverEye = (feet :: Vector3) + Vector3.new(0, Config.Body.EYE_HEIGHT, 0)
		ok = (serverEye - eye).Magnitude <= R.SERVER_EYE_TOLERANCE
	end
	if not ok then
		combatRemote:FireClient(player, "reject", clientId, a.charges)
		return
	end
	a.charges -= 1
	a.lastFire = now

	local params = Rocket.shotParams(player.Character)
	local spawn, vel = Rocket.launch(eye, dir, yaw, params)
	nextId += 1
	local rk: Live = { id = nextId, shooter = player, pos = spawn, prev = eye, vel = vel, life = 0, params = params }
	rockets[rk.id] = rk
	combatRemote:FireAllClients("spawn", rk.id, player.UserId, clientId, spawn, vel, Workspace:GetServerTimeNow())
end)

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
			combatRemote:FireAllClients("explode", id, rk.shooter.UserId, nil, nil)
		else
			rk.pos = to
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	arms[player] = nil
end)

return Combat
