-- Client : tir de roquette avec prédiction.
--   * appui sur tir → la roquette part TOUT DE SUITE à l'écran (roquette « prédite »)
--     et la demande part au serveur ;
--   * notre roquette explose chez nous dès qu'elle touche quelque chose : effet + poussée
--     sur nous-même (rocket jump sans délai réseau) ;
--   * le serveur fait foi pour les dégâts ; les roquettes des autres joueurs arrivent par lui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rocket = require(Shared.Rocket)
local Rail = require(Shared.Rail)

local Fx = require(script.Parent.Fx)
local FpsCamera = require(script.Parent.FpsCamera)

local S = Config.STUDS_PER_METER
local R = Config.Rocket
local RL = Config.Rail
local SND = Config.Sounds

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireRemote = remotes:WaitForChild("Fire") :: RemoteEvent
local railRemote = remotes:WaitForChild("FireRail") :: RemoteEvent
local combatRemote = remotes:WaitForChild("Combat") :: RemoteEvent

local Weapons = {
	charges = R.CHARGES,
	railCharges = RL.CHARGES,
	weapon = "rocket", -- "rocket" partout, "rail" sur les plateformes Rail
	fireCd = 0,
	onDetonated = nil :: (() -> ())?,
	-- Rappels pour le HUD (branchés par Main).
	onHit = nil :: ((victimName: string, killed: boolean) -> ())?,
	onDamaged = nil :: ((fromPos: Vector3, lives: number?) -> ())?,
}

type Visual = {
	part: Part,
	pos: Vector3,
	vel: Vector3,
	prev: Vector3,
	life: number,
	own: boolean,
	exploded: boolean,
	params: RaycastParams?,
}

local own: { [number]: Visual } = {} -- nos roquettes, par identifiant client
local serverToOwn: { [number]: number } = {}
local others: { [number]: Visual } = {} -- roquettes des autres, par identifiant serveur
local nextClientId = 0

local ctrl = nil -- contrôleur de déplacement du personnage actuel

function Weapons.setController(c)
	ctrl = c
end

function Weapons.reset()
	Weapons.charges = R.CHARGES
	Weapons.railCharges = RL.CHARGES
	Weapons.fireCd = 0
end

local function shakeFrom(pos: Vector3)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local d = (cam.CFrame.Position / S - pos).Magnitude
	if d < R.SHAKE_REACH then
		FpsCamera.shake = math.max(FpsCamera.shake, R.SHAKE_STRENGTH * (1 - d / R.SHAKE_REACH))
	end
end

-- Notre propre poussée (rocket jump), calculée une seule fois par roquette.
local function selfPush(pos: Vector3, n: Vector3)
	if not ctrl then
		return
	end
	local feet = Rocket.feetOf(ctrl.character)
	if not feet then
		return
	end
	local push = Rocket.push(pos, n, feet, Rocket.worldParams())
	if push then
		ctrl:addImpulse(push)
	end
end

local function explodeVisual(v: Visual, pos: Vector3, n: Vector3)
	if v.exploded then
		return
	end
	v.exploded = true
	v.part:Destroy()
	Fx.explosion(pos)
	shakeFrom(pos)
	if v.own then
		selfPush(pos, n)
	end
end

local function canShoot(): boolean
	return ctrl ~= nil
		and not ctrl.frozen
		and ctrl.root.Parent ~= nil
		and ctrl.character:GetAttribute("CanFire") ~= false
		and Weapons.fireCd <= 0
end

local function myTeam(): number?
	local t = player:GetAttribute("Team")
	return if type(t) == "number" then t else nil
end

-- Rail : tir instantané. On montre tout de suite le rayon et la roquette détruite ;
-- le serveur confirme la touche.
local function tryFireRail()
	if not canShoot() then
		return
	end
	if Weapons.railCharges < 1 then
		Fx.play(SND.EMPTY, 0.3)
		Weapons.fireCd = 0.2
		return
	end
	Weapons.railCharges -= 1
	Weapons.fireCd = RL.COOLDOWN

	local eye = ctrl:eyePosition() / S
	local dir = FpsCamera.rotation().LookVector
	local yaw = FpsCamera.yaw
	local hit = Workspace:Raycast(eye * S, dir * RL.RANGE * S, Rocket.shotParams(ctrl.character))
	local stop = if hit then hit.Position / S else eye + dir * RL.RANGE
	local claimId, claimPoint = nil, nil
	if hit then
		local victim = Players:GetPlayerFromCharacter(hit.Instance:FindFirstAncestorOfClass("Model"))
		if victim and victim ~= player then
			claimId, claimPoint = victim.UserId, stop
		end
	end

	-- Roquette sur la trajectoire ? (prédiction visuelle, le serveur décide)
	local list = {}
	for _, v in own do
		if not v.exploded then
			table.insert(list, { key = v, pos = v.pos, vel = v.vel })
		end
	end
	for _, v in others do
		if not v.exploded then
			table.insert(list, { key = v, pos = v.pos, vel = v.vel })
		end
	end
	local v, along = Rail.rocketOnRay(eye, dir, (stop - eye).Magnitude, list, 0)
	if v then
		stop = eye + dir * (along :: number)
		explodeVisual(v :: any, stop, Vector3.yAxis)
	end

	Fx.railBeam(Rail.muzzle(eye, dir, yaw), stop, Rail.color(myTeam()))
	Fx.playAt(SND.RAIL_FIRE, eye, 0.6, 0.6)
	railRemote:FireServer(eye, dir, yaw, claimId, claimPoint)
end

local function tryFire()
	if Weapons.weapon == "rail" then
		tryFireRail()
		return
	end
	if not canShoot() then
		return
	end
	if Weapons.charges < 1 then
		Fx.play(SND.EMPTY, 0.3)
		Weapons.fireCd = 0.2
		return
	end
	Weapons.charges -= 1
	Weapons.fireCd = R.MIN_INTERVAL

	local eye = ctrl:eyePosition() / S
	local dir = FpsCamera.rotation().LookVector
	local yaw = FpsCamera.yaw
	local params = Rocket.shotParams(ctrl.character)
	local spawn, vel = Rocket.launch(eye, dir, yaw, params)

	nextClientId += 1
	local id = nextClientId
	local part = Fx.newRocket(nil)
	Fx.placeRocket(part, spawn, vel)
	own[id] = { part = part, pos = spawn, vel = vel, prev = eye, life = 0, own = true, exploded = false, params = params }
	Fx.playAt(SND.ROCKET_FIRE, spawn, 0.5)
	fireRemote:FireServer(id, eye, dir, yaw)
end

-- À chaque image.
function Weapons.update(dt: number, fireHeld: boolean)
	Weapons.fireCd = math.max(0, Weapons.fireCd - dt)
	-- Les deux armes se rechargent en continu, même celle qu'on n'a pas en main.
	if Weapons.charges < R.CHARGES then
		Weapons.charges = math.min(R.CHARGES, Weapons.charges + dt / R.RELOAD)
	end
	if Weapons.railCharges < RL.CHARGES then
		Weapons.railCharges = math.min(RL.CHARGES, Weapons.railCharges + dt / RL.RELOAD)
	end
	-- L'arme dépend du bloc sous les pieds (gardée en l'air jusqu'au prochain sol).
	if ctrl then
		Weapons.weapon = if ctrl.surface == "rail" then "rail" else "rocket"
	end
	if fireHeld then
		tryFire()
	end

	-- Nos roquettes : même balayage que le serveur.
	for id, v in own do
		if v.exploded then
			own[id] = nil
			continue
		end
		v.life += dt
		local to = v.pos + v.vel * dt
		local hitPos, n = Rocket.sweep(v.prev, to, v.params :: RaycastParams)
		v.prev = to
		if hitPos then
			explodeVisual(v, hitPos + n * 0.05, n)
		elseif v.life > R.LIFETIME then
			v.exploded = true
			v.part:Destroy()
		else
			v.pos = to
			Fx.placeRocket(v.part, to, v.vel)
		end
	end
	-- Roquettes des autres : ligne droite, le serveur dit quand elles explosent.
	for id, v in others do
		v.life += dt
		v.pos += v.vel * dt
		Fx.placeRocket(v.part, v.pos, v.vel)
		if v.life > R.LIFETIME + 1 then
			v.part:Destroy()
			others[id] = nil
		end
	end
end

local function teamOf(userId: number): number?
	local p = Players:GetPlayerByUserId(userId)
	local t = p and p:GetAttribute("Team")
	return if type(t) == "number" then t else nil
end

combatRemote.OnClientEvent:Connect(function(kind: string, ...)
	if kind == "spawn" then
		local id, shooterId, clientId, spawn, vel, serverTime = ...
		if shooterId == player.UserId then
			serverToOwn[id] = clientId
			return
		end
		local late = math.clamp(Workspace:GetServerTimeNow() - serverTime, 0, 0.3)
		local part = Fx.newRocket(teamOf(shooterId))
		local pos = spawn + vel * late
		Fx.placeRocket(part, pos, vel)
		others[id] = { part = part, pos = pos, vel = vel, prev = pos, life = late, own = false, exploded = false }
		Fx.playAt(SND.ROCKET_FIRE, spawn, 0.5)
	elseif kind == "explode" then
		local id, shooterId, pos, n = ...
		if shooterId == player.UserId then
			local cid = serverToOwn[id]
			serverToOwn[id] = nil
			local v = cid and own[cid]
			if v and not v.exploded then
				if pos then
					-- Le serveur a explosé avant nous (ex. sur l'adversaire) : on suit le serveur.
					explodeVisual(v, pos, n)
				else
					v.exploded = true
					v.part:Destroy()
				end
			end
			return
		end
		local v = others[id]
		others[id] = nil
		if v then
			if pos then
				explodeVisual(v, pos, n)
			else
				v.part:Destroy()
			end
		elseif pos then
			Fx.explosion(pos)
			shakeFrom(pos)
		end
	elseif kind == "rail" then
		local shooterId, muzzle, stop, team = ...
		if shooterId ~= player.UserId and typeof(muzzle) == "Vector3" and typeof(stop) == "Vector3" then
			Fx.railBeam(muzzle, stop, Rail.color(team))
			Fx.playAt(SND.RAIL_FIRE, muzzle, 0.6, 0.6)
		end
	elseif kind == "detonated" then
		Fx.play(SND.DETONATE, 0.7, 1.6)
		if Weapons.onDetonated then
			Weapons.onDetonated()
		end
	elseif kind == "push" then
		local impulse = ...
		if ctrl and typeof(impulse) == "Vector3" then
			ctrl:addImpulse(impulse)
		end
	elseif kind == "hit" then
		local victimName, killed = ...
		if killed then
			Fx.play(SND.KILL, 0.9, 0.7)
		else
			Fx.play(SND.HIT, 0.6, 1.2)
		end
		if Weapons.onHit then
			Weapons.onHit(victimName, killed)
		end
	elseif kind == "damaged" then
		local fromPos, lives = ...
		if Weapons.onDamaged then
			Weapons.onDamaged(fromPos, lives)
		end
	elseif kind == "reject" then
		local clientId, charges = ...
		local v = own[clientId]
		if v and not v.exploded then
			v.exploded = true
			v.part:Destroy()
		end
		own[clientId] = nil
		if type(charges) == "number" then
			Weapons.charges = charges
		end
	end
end)

return Weapons
