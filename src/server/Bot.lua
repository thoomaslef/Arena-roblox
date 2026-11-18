-- Bot de remplacement (serveur) — portage simplifié de scripts/player/bot_brain.gd.
--
-- Le bot imite un Player (Name, DisplayName, UserId négatif, Character, Parent,
-- Get/SetAttribute, LoadCharacter) pour que le mode et le combat le traitent comme un joueur.
-- Son corps est un avatar R15 piloté par LE MÊME contrôleur de déplacement que les joueurs
-- (Shared/Movement), simulé sur le serveur (propriétaire physique : le serveur).
--
-- Cerveau : perception (ligne de vue + champ de vision), visée avec temps de réaction,
-- anticipation et bruit, strafe et esquives par sauts, navigation par PathfindingService
-- (le jeu Godot utilisait sa propre grille).

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Movement = require(Shared.Movement)
local Rocket = require(Shared.Rocket)

local S = Config.STUDS_PER_METER
local R = Config.Rocket
local EYE = Config.Body.EYE_HEIGHT

-- Niveaux de bot_brain.gd (facile, moyen, difficile).
local SKILLS = {
	{ reaction = 0.55, aim_err = 6.0, turn = 230.0, lead = 0.45, fire_tol = 8.0, fov = 110.0, dodge = 0.15 },
	{ reaction = 0.32, aim_err = 3.2, turn = 380.0, lead = 0.8, fire_tol = 5.5, fov = 140.0, dodge = 0.3 },
	{ reaction = 0.18, aim_err = 1.6, turn = 600.0, lead = 0.95, fire_tol = 3.5, fov = 170.0, dodge = 0.5 },
}
local NAMES = { "Vortex", "Néon", "Krypto", "Ombre", "Pixel", "Zénith", "Rafale", "Écho", "Fusée", "Orage" }

local Bots = {}

local spawner: ((any, Model) -> ())? = nil
local combat = nil
local list: { any } = {}
local nextUserId = -1

-- Main fournit la préparation commune des personnages ; Combat est injecté par Joust.
function Bots.setSpawner(fn)
	spawner = fn
end

local Bot = {}
Bot.__index = Bot

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

function Bots.create(combatModule, team: number, skillIndex: number?)
	combat = combatModule
	local self = setmetatable({}, Bot)
	local name = NAMES[math.random(#NAMES)]
	self.Name = "Bot_" .. name
	self.DisplayName = "Bot " .. name
	self.UserId = nextUserId
	nextUserId -= 1
	self.Parent = Workspace -- « présent sur le serveur » (comme player.Parent)
	self.Character = nil :: Model?
	self.attrs = { Team = team }
	self.skill = SKILLS[math.clamp(skillIndex or 2, 1, #SKILLS)]
	self.rng = Random.new()
	self.ctrl = nil
	-- Fonctions fournies par le mode : adversaire et objectif de déplacement.
	self.targetOf = function(_bot): any
		return nil
	end
	self.goalOf = function(_bot): (Vector3?, boolean)
		return nil, false
	end
	self:_resetBrain()
	table.insert(list, self)
	table.insert(combat.bots, self)
	return self
end

function Bot:_resetBrain()
	self.yaw, self.pitch = 0, 0
	self.visible = false
	self.visibleTime = 0
	self.lastSeen = nil :: Vector3?
	self.lastSeenAge = 99
	self.aggroPos = nil :: Vector3?
	self.aggroT = 0
	self.perceiveT = 0
	self.noise, self.noiseTarget, self.noiseT = Vector2.zero, Vector2.zero, 0
	self.strafeDir, self.strafeT = 1, 0
	self.holdT = 0
	self.wantPress = false
	self.prevHeld = false
	self.stuckT = 0
	self.sprintCd = 1
	self.fireCd = 0
	self.path = nil :: { PathWaypoint }?
	self.pathI = 1
	self.pathGoal = nil :: Vector3?
	self.repathT = 0
	self.pathBusy = false
end

function Bot:GetAttribute(k: string): any
	return self.attrs[k]
end

function Bot:SetAttribute(k: string, v: any)
	self.attrs[k] = v
end

function Bot:LoadCharacter()
	if self.Character then
		self.Character:Destroy()
		self.Character = nil
	end
	if self.ctrl then
		self.ctrl:destroy()
		self.ctrl = nil
	end
	self:_resetBrain()
	local team = self.attrs.Team or 1
	local desc = Instance.new("HumanoidDescription")
	local c = Config.Teams[team] and Config.Teams[team].color or Color3.new(0.6, 0.6, 0.6)
	desc.TorsoColor = c
	desc.LeftArmColor, desc.RightArmColor = c, c
	desc.LeftLegColor, desc.RightLegColor = c:Lerp(Color3.new(0, 0, 0), 0.4), c:Lerp(Color3.new(0, 0, 0), 0.4)
	desc.HeadColor = Color3.fromRGB(255, 220, 180)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = self.DisplayName
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = self.DisplayName
	end
	model.Parent = Workspace
	self.Character = model
	task.spawn(function()
		if spawner then
			spawner(self, model)
		end
		if self.Character ~= model or not model.Parent then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root:SetNetworkOwner(nil)
		end
		self.ctrl = Movement.new(model)
		self.yaw = self.ctrl.yaw
	end)
end

function Bot:destroy()
	for i, b in list do
		if b == self then
			table.remove(list, i)
			break
		end
	end
	if combat then
		for i, b in combat.bots do
			if b == self then
				table.remove(combat.bots, i)
				break
			end
		end
		combat.forget(self)
	end
	if self.ctrl then
		self.ctrl:destroy()
		self.ctrl = nil
	end
	if self.Character then
		self.Character:Destroy()
		self.Character = nil
	end
	self.Parent = nil
end

-- Messages du combat (ce qu'un client recevrait).
function Bot:onCombatEvent(kind: string, ...)
	if kind == "push" then
		local impulse = ...
		if self.ctrl then
			self.ctrl:addImpulse(impulse)
		end
	elseif kind == "damaged" then
		local from = ...
		if typeof(from) == "Vector3" then
			self.aggroPos = from
			self.aggroT = 3
		end
	end
end

-- Perception -------------------------------------------------------------------------

local function world(): RaycastParams
	return Rocket.worldParams() -- suit le changement de map
end

local function blocked(a: Vector3, b: Vector3): boolean
	return Workspace:Raycast(a * S, (b - a) * S, world()) ~= nil
end

local function velocityOf(character: Model?): Vector3
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.AssemblyLinearVelocity / S else Vector3.zero
end

function Bot:_forward(): Vector3
	return Vector3.new(-math.sin(self.yaw), 0, -math.cos(self.yaw))
end

function Bot:_aimDir(): Vector3
	return (CFrame.Angles(0, self.yaw, 0) * CFrame.Angles(self.pitch, 0, 0)).LookVector
end

function Bot:_perceive(feet: Vector3, target: any)
	self.visible = false
	local tFeet = target and Rocket.feetOf(target.Character)
	if not tFeet then
		return
	end
	local eye = feet + Vector3.new(0, EYE, 0)
	local chest = tFeet + Vector3.new(0, 1.2, 0)
	local to = chest - eye
	local d = to.Magnitude
	local flatTo = Vector3.new(to.X, 0, to.Z)
	local ang = if flatTo.Magnitude > 0.01 then math.deg(math.acos(math.clamp(self:_forward():Dot(flatTo.Unit), -1, 1))) else 0
	local inView = ang <= self.skill.fov * 0.5 or d < 7 or self.aggroT > 0
	if inView and not blocked(eye, chest) then
		self.visible = true
		self.lastSeen = tFeet
		self.lastSeenAge = 0
	end
end

function Bot:_updateNoise(dt: number)
	self.noiseT -= dt
	if self.noiseT <= 0 then
		self.noiseT = self.rng:NextNumber(0.25, 0.6)
		self.noiseTarget = Vector2.new(self.rng:NextNumber(-1, 1), self.rng:NextNumber(-1, 1))
	end
	self.noise = self.noise:Lerp(self.noiseTarget, math.min(1, dt * 5))
end

-- Point visé (m) : anticipation pour la roquette, visée au sol si la cible y est (dégâts de zone).
function Bot:_aimPoint(eye: Vector3, target: any): Vector3?
	local tFeet = Rocket.feetOf(target.Character)
	if not tFeet then
		return nil
	end
	local tv = velocityOf(target.Character)
	if self.ctrl and self.ctrl.surface == "rail" then
		return tFeet + Vector3.new(0, 1.1, 0) + tv * 0.04
	end
	local tt = (tFeet - eye).Magnitude / R.SPEED
	local pred = tFeet + tv * tt * self.skill.lead
	local onFloor = math.abs(tv.Y) < 0.5
	if onFloor then
		return Vector3.new(pred.X, tFeet.Y + 0.25, pred.Z)
	end
	return Vector3.new(pred.X, tFeet.Y + 0.9 + tv.Y * tt * 0.3, pred.Z)
end

function Bot:_aim(dt: number, eye: Vector3, target: any)
	local desired: Vector3? = nil
	local noisy = false
	if self.visible and target then
		local p = self:_aimPoint(eye, target)
		if p then
			desired = (p - eye).Unit
			noisy = true
		end
	end
	if not desired and self.lastSeen and self.lastSeenAge < 2.5 then
		desired = (self.lastSeen + Vector3.new(0, 1.2, 0) - eye).Unit
	end
	if not desired and self.aggroPos and self.aggroT > 0 then
		desired = (self.aggroPos - eye).Unit
	end
	if not desired then
		local v = self.ctrl and Vector3.new(self.ctrl.vel.X, 0, self.ctrl.vel.Z) or Vector3.zero
		desired = if v.Magnitude > 2 then v.Unit else self:_forward()
	end
	local dyaw = math.atan2(-desired.X, -desired.Z)
	local dpitch = math.asin(math.clamp(desired.Y, -1, 1))
	if noisy then
		dyaw += math.rad(self.noise.X * self.skill.aim_err)
		dpitch += math.rad(self.noise.Y * self.skill.aim_err * 0.6)
	end
	local maxTurn = math.rad(self.skill.turn) * dt
	self.yaw = wrapAngle(self.yaw + math.clamp(wrapAngle(dyaw - self.yaw), -maxTurn, maxTurn))
	self.pitch = math.clamp(self.pitch + math.clamp(dpitch - self.pitch, -maxTurn, maxTurn), -1.4, 1.4)
end

function Bot:_shoot(dt: number, eye: Vector3, feet: Vector3, target: any)
	self.fireCd -= dt
	if not self.visible or not target or self.fireCd > 0 then
		return
	end
	if self.Character and self.Character:GetAttribute("CanFire") == false then
		return
	end
	local rail = self.ctrl and self.ctrl.surface == "rail"
	local reaction = self.skill.reaction * (if rail then 1.6 else 1)
	if self.visibleTime < reaction then
		return
	end
	local tFeet = Rocket.feetOf(target.Character)
	if not tFeet then
		return
	end
	local d = (tFeet - feet).Magnitude
	if not rail and d > 60 then
		return
	end
	local p = self:_aimPoint(eye, target)
	if not p then
		return
	end
	local ideal = (p - eye).Unit
	local dir = self:_aimDir()
	local err = math.deg(math.acos(math.clamp(dir:Dot(ideal), -1, 1)))
	local tol = self.skill.fire_tol
	if rail then
		tol *= 0.5
	elseif d < 10 then
		tol *= 1.6
	end
	if err > tol then
		return
	end
	if rail then
		combat.fireRail(self, eye, dir, self.yaw, nil, nil)
		self.fireCd = Config.Rail.COOLDOWN + 0.05
	else
		combat.fireRocket(self, 0, eye, dir, self.yaw)
		self.fireCd = R.MIN_INTERVAL + 0.04
	end
end

-- Déplacement -------------------------------------------------------------------------

function Bot:_press(hold: number)
	self.wantPress = true
	self.holdT = hold
end

local function dropAhead(feet: Vector3, mv: Vector3): boolean
	if mv.Magnitude < 0.1 then
		return false
	end
	local probe = feet + mv.Unit * 1.3 + Vector3.new(0, 0.4, 0)
	return not blocked(probe, probe + Vector3.new(0, -2.6, 0))
end

function Bot:_requestPath(feet: Vector3, goal: Vector3)
	if self.pathBusy then
		return
	end
	self.pathBusy = true
	self.pathGoal = goal
	self.repathT = self.rng:NextNumber(1.0, 1.6)
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = Config.Body.RADIUS * S + 0.3,
			AgentHeight = Config.Body.HEIGHT * S,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		})
		local ok = pcall(function()
			path:ComputeAsync(feet * S, goal * S)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			self.path = path:GetWaypoints()
			self.pathI = 2
		else
			self.path = nil
		end
		self.pathBusy = false
	end)
end

function Bot:_follow(dt: number, feet: Vector3, goal: Vector3): Vector3
	self.repathT -= dt
	if self.path == nil or self.repathT <= 0 or (self.pathGoal and (self.pathGoal - goal).Magnitude > 2.5) then
		self:_requestPath(feet, goal)
	end
	local path = self.path
	if not path then
		local direct = Vector3.new(goal.X - feet.X, 0, goal.Z - feet.Z)
		return if direct.Magnitude > 1.5 then direct.Unit else Vector3.zero
	end
	while self.pathI <= #path do
		local wp = path[self.pathI].Position / S
		local flatD = Vector2.new(wp.X - feet.X, wp.Z - feet.Z).Magnitude
		local dy = wp.Y - feet.Y
		if flatD < 0.95 and dy < 0.7 and dy > -3 then
			self.pathI += 1
		else
			break
		end
	end
	if self.pathI > #path then
		local last = Vector3.new(goal.X - feet.X, 0, goal.Z - feet.Z)
		return if last.Magnitude > 1.2 then last.Unit * 0.6 else Vector3.zero
	end
	local wpt = path[self.pathI]
	local wp = wpt.Position / S
	local to = Vector3.new(wp.X - feet.X, 0, wp.Z - feet.Z)
	local onFloor = self.ctrl and self.ctrl.onFloor
	if onFloor and self.holdT <= 0 and to.Magnitude < 2.8 and (wpt.Action == Enum.PathWaypointAction.Jump or wp.Y - feet.Y > 0.45) then
		self:_press(0.25)
	end
	return if to.Magnitude > 0.01 then to.Unit else Vector3.zero
end

function Bot:_combatMove(dt: number, feet: Vector3, target: any): Vector3
	local onFloor = self.ctrl and self.ctrl.onFloor
	self.strafeT -= dt
	if self.strafeT <= 0 then
		self.strafeT = self.rng:NextNumber(0.35, 1.1)
		if self.rng:NextNumber() < 0.7 then
			self.strafeDir = -self.strafeDir
		end
		if self.rng:NextNumber() < self.skill.dodge and onFloor then
			self:_press(self.rng:NextNumber(0, 0.35))
		end
	end
	local tFeet = Rocket.feetOf(target.Character) or feet
	local to = Vector3.new(tFeet.X - feet.X, 0, tFeet.Z - feet.Z)
	local d = to.Magnitude
	local dir = to / math.max(d, 0.01)
	local perp = Vector3.new(-dir.Z, 0, dir.X) * self.strafeDir
	local pref = if self.ctrl and self.ctrl.surface == "rail" then 24 else 14
	local radial = math.clamp((d - pref) / 8, -1, 1)
	local mv = perp + dir * radial * 0.9
	if onFloor and dropAhead(feet, mv) then
		self.strafeDir = -self.strafeDir
		mv = -mv * 0.5
	end
	return mv
end

function Bot:think(dt: number)
	local ctrl = self.ctrl
	if not ctrl or not ctrl.root.Parent then
		return
	end
	local feet = ctrl:feetPosition()
	local eye = feet + Vector3.new(0, EYE, 0)
	local target = self.targetOf(self)
	if target and not target.Character then
		target = nil
	end

	self.perceiveT -= dt
	if self.perceiveT <= 0 then
		self.perceiveT = 0.1
		self:_perceive(feet, target)
	end
	self.lastSeenAge += dt
	self.aggroT -= dt
	self.visibleTime = if self.visible then self.visibleTime + dt else 0
	self:_updateNoise(dt)
	self:_aim(dt, eye, target)
	self:_shoot(dt, eye, feet, target)

	-- Objectif : celui du mode (gaz) d'abord, sinon l'adversaire.
	local goal, force = self.goalOf(self)
	local move = Vector3.zero
	if self.visible and target and not force then
		move = self:_combatMove(dt, feet, target)
	elseif goal then
		move = self:_follow(dt, feet, goal)
		if force and self.visible and target and move.Magnitude < 0.1 then
			move = self:_combatMove(dt, feet, target) * 0.5
		end
	elseif self.lastSeen and self.lastSeenAge < 6 then
		move = self:_follow(dt, feet, self.lastSeen)
	end
	if move.Magnitude > 1 then
		move = move.Unit
	end

	-- Sprint en se déplaçant loin sans adversaire en vue.
	self.sprintCd -= dt
	if not self.visible and move.Magnitude > 0.5 and ctrl.onFloor and ctrl.stamina > 0.85 and self.sprintCd <= 0 and goal and (goal - feet).Magnitude > 16 then
		self:_press(1.5)
		self.sprintCd = self.rng:NextNumber(2.5, 4.5)
	end

	-- Coincé : on saute, puis on change de côté et on recalcule.
	local hs = Vector2.new(ctrl.vel.X, ctrl.vel.Z).Magnitude
	if move.Magnitude > 0.5 and hs < 1.5 then
		self.stuckT += dt
	else
		self.stuckT = math.max(0, self.stuckT - dt * 2)
	end
	if self.stuckT > 0.45 and ctrl.onFloor and self.holdT <= 0 then
		self:_press(0.3)
	end
	if self.stuckT > 1.4 then
		self.stuckT = 0
		self.strafeDir = -self.strafeDir
		self.path = nil
	end

	-- Bouton de mobilité.
	local pressed = self.wantPress
	self.wantPress = false
	local held = false
	if self.holdT > 0 then
		self.holdT -= dt
		held = true
	end
	if pressed then
		held = true -- un appui dure au moins une image
	end

	-- Inclinaison de la visée, vue par les joueurs (comme l'attribut posé pour eux).
	self.aimT = (self.aimT or 0) - dt
	if self.aimT <= 0 and self.Character then
		self.aimT = 0.07
		self.Character:SetAttribute("AimPitch", math.floor(self.pitch * 50 + 0.5) / 50)
	end

	local right = Vector3.new(math.cos(self.yaw), 0, -math.sin(self.yaw))
	ctrl.yaw = self.yaw
	ctrl:step(dt, {
		move = Vector2.new(move:Dot(right), move:Dot(self:_forward())),
		held = held,
		pressed = pressed,
		walk = false,
	})
end

RunService.PreSimulation:Connect(function(dt)
	for _, b in list do
		b:think(dt)
	end
end)

return Bots
