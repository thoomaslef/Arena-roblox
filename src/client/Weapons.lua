-- Client : tir de roquette avec prédiction.
--   * appui sur tir → la roquette part TOUT DE SUITE à l'écran (roquette « prédite »)
--     et la demande part au serveur ;
--   * notre roquette explose chez nous dès qu'elle touche quelque chose : effet + poussée
--     sur nous-même (rocket jump sans délai réseau) ;
--   * le serveur fait foi pour les dégâts ; les roquettes des autres joueurs arrivent par lui.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rocket = require(Shared.Rocket)
local Rail = require(Shared.Rail)

local Fx = require(script.Parent.Fx)
local Sfx = require(script.Parent.Sfx)
local FpsCamera = require(script.Parent.FpsCamera)

local S = Config.STUDS_PER_METER
local R = Config.Rocket
local RL = Config.Rail

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
	onOtherShot = nil :: ((muzzle: Vector3) -> ())?, -- un autre personnage vient de tirer
	onFire = nil :: (() -> ())?, -- on vient de tirer (recul de l'arme à l'écran)
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

-- Roquettes du joueur : nombre max et recharge (3v3 : 4 roquettes, 1,6 s ; sinon Config).
function Weapons.rocketParams(): (number, number)
	local c = ctrl and ctrl.character
	local maxR = c and c:GetAttribute("RocketMax")
	local reload = c and c:GetAttribute("RocketReload")
	return (if type(maxR) == "number" then maxR else R.CHARGES), (if type(reload) == "number" then reload else R.RELOAD)
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
	Sfx.playAt("explosion", pos, 0)
	shakeFrom(pos)
	if v.own then
		selfPush(pos, n)
	end
end

-- Aide à la visée (tactile et manette seulement) : si l'adversaire est presque sous le
-- réticule (moins de 6°) et visible, le tir est légèrement ramené vers lui.
local ASSIST_CONE = math.rad(6)
local ASSIST_PULL = 0.7
local function aimAssist(eye: Vector3, dir: Vector3): Vector3
	local last = UserInputService:GetLastInputType()
	local assisted = last == Enum.UserInputType.Touch or last.Name:sub(1, 7) == "Gamepad"
	if not assisted or not ctrl then
		return dir
	end
	local best, bestAng = nil, ASSIST_CONE
	for _, model in Workspace:GetChildren() do
		if model:IsA("Model") and model ~= ctrl.character and model:FindFirstChildOfClass("Humanoid") then
			local feet = Rocket.feetOf(model)
			if feet then
				local target = feet + Vector3.new(0, 1.0, 0)
				local to = target - eye
				local ang = math.acos(math.clamp(dir:Dot(to.Unit), -1, 1))
				if ang < bestAng and Workspace:Raycast(eye * S, to * S, Rocket.worldParams()) == nil then
					best, bestAng = to.Unit, ang
				end
			end
		end
	end
	if best then
		return dir:Lerp(best, ASSIST_PULL).Unit
	end
	return dir
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
		Sfx.play("empty", -6)
		Weapons.fireCd = 0.2
		return
	end
	Weapons.railCharges -= 1
	Weapons.fireCd = RL.COOLDOWN

	local eye = ctrl:eyePosition() / S
	local dir = aimAssist(ctrl:eyePosition() / S, FpsCamera.rotation().LookVector)
	local yaw = FpsCamera.yaw
	local hit = Workspace:Raycast(eye * S, dir * RL.RANGE * S, Rocket.shotParams(ctrl.character))
	local stop = if hit then hit.Position / S else eye + dir * RL.RANGE
	-- Touche vue chez nous : on envoie le personnage touché (joueur ou bot) et le point.
	local claimModel, claimPoint = nil, nil
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model ~= ctrl.character and model:FindFirstChildOfClass("Humanoid") then
			claimModel, claimPoint = model, stop
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
	Sfx.play("rail", 0)
	railRemote:FireServer(eye, dir, yaw, claimModel, claimPoint)
	if Weapons.onFire then
		Weapons.onFire()
	end
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
		Sfx.play("empty", -6)
		Weapons.fireCd = 0.2
		return
	end
	Weapons.charges -= 1
	Weapons.fireCd = R.MIN_INTERVAL

	local eye = ctrl:eyePosition() / S
	local dir = aimAssist(ctrl:eyePosition() / S, FpsCamera.rotation().LookVector)
	local yaw = FpsCamera.yaw
	local params = Rocket.shotParams(ctrl.character)
	local spawn, vel = Rocket.launch(eye, dir, yaw, params)

	nextClientId += 1
	local id = nextClientId
	local part = Fx.newRocket(nil)
	Fx.placeRocket(part, spawn, vel)
	own[id] = { part = part, pos = spawn, vel = vel, prev = eye, life = 0, own = true, exploded = false, params = params }
	Sfx.play("rocket", -3)
	fireRemote:FireServer(id, eye, dir, yaw)
	if Weapons.onFire then
		Weapons.onFire()
	end
end

-- À chaque image.
function Weapons.update(dt: number, fireHeld: boolean)
	Weapons.fireCd = math.max(0, Weapons.fireCd - dt)
	-- Les deux armes se rechargent en continu, même celle qu'on n'a pas en main.
	local maxR, reload = Weapons.rocketParams()
	if Weapons.charges < maxR then
		Weapons.charges = math.min(maxR, Weapons.charges + dt / reload)
	elseif Weapons.charges > maxR then
		Weapons.charges = maxR
	end
	if Weapons.railCharges < RL.CHARGES then
		Weapons.railCharges = math.min(RL.CHARGES, Weapons.railCharges + dt / RL.RELOAD)
	end
	-- Compte à rebours d'une manche : aucune roquette (comme le serveur), recharge dès le GO.
	local matchMode = ReplicatedStorage:FindFirstChild("Match") and ReplicatedStorage.Match:GetAttribute("Mode")
	if R.START_EMPTY and matchMode ~= "elite" and ctrl and ctrl.character:GetAttribute("Frozen") == true then
		Weapons.charges = 0
	end
	-- L'arme dépend du bloc sous les pieds (gardée en l'air jusqu'au prochain sol).
	if ctrl then
		-- 3v3 : l'attaquant a le Rail partout (attribut ForcedWeapon posé par le serveur).
		local forced = ctrl.character:GetAttribute("ForcedWeapon")
		Weapons.weapon = if forced == "rail" or ctrl.surface == "rail" then "rail" else "rocket"
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
		if Weapons.onOtherShot then
			Weapons.onOtherShot(spawn)
		end
		Sfx.playAt("rocket", spawn, -3)
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
			Sfx.playAt("explosion", pos, 0)
			shakeFrom(pos)
		end
	elseif kind == "rail" then
		local shooterId, muzzle, stop, team = ...
		if shooterId ~= player.UserId and typeof(muzzle) == "Vector3" and typeof(stop) == "Vector3" then
			Fx.railBeam(muzzle, stop, Rail.color(team))
			Sfx.playAt("rail", muzzle, 0)
			if Weapons.onOtherShot then
				Weapons.onOtherShot(muzzle)
			end
		end
	elseif kind == "detonated" then
		Sfx.play("hit", -2, 1.5)
		if Weapons.onDetonated then
			Weapons.onDetonated()
		end
	elseif kind == "push" then
		local impulse = ...
		if ctrl and typeof(impulse) == "Vector3" then
			ctrl:addImpulse(impulse)
		end
	elseif kind == "hit" then
		local victimName, killed, victimModel, livesLeft = ...
		if killed then
			Sfx.play("kill", 0)
		elseif livesLeft == 1 then
			Sfx.play("hit", 2, 0.8) -- plus grave et plus fort : il ne lui reste qu'une vie
		else
			Sfx.play("hit", 0)
		end
		if Weapons.onHit then
			Weapons.onHit(victimName, killed, victimModel, livesLeft)
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
