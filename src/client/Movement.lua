-- Contrôleur de déplacement maison — portage de scripts/player/fighter.gd (_physics_process,
-- _jump, _try_walljump). Tout est calculé en MÈTRES puis converti en studs.
--
-- Fonctionnement côté Roblox :
--   * le client possède physiquement son personnage : on écrit directement
--     AssemblyLinearVelocity à chaque image (PreSimulation) ;
--   * une VectorForce annule la gravité de Roblox : c'est NOTRE gravité (22 m/s²) qui compte ;
--   * le cylindre « Collider » bloque contre les murs ; le sol est géré ici par un
--     Spherecast vers le bas (accroche de 0,35 m, pentes jusqu'à 50°, petites marches).

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local S = Config.STUDS_PER_METER
local M = Config.Move
local ST = Config.Stamina
local B = Config.Body

local MIN_FLOOR_NY = math.cos(math.rad(B.MAX_SLOPE_DEG))
local PROBE_RADIUS = 0.38 -- m (presque le rayon du Collider : on « voit » les bords comme lui)
local LAND_SNAP = 0.06 -- m : marge pour « toucher » le sol en retombant
local GROUND_LOCK = 0.12 -- s : après un saut, on ignore le sol (sinon l'accroche le recollerait)

local function moveToward(a: Vector3, b: Vector3, delta: number): Vector3
	local d = b - a
	local l = d.Magnitude
	if l <= delta or l < 1e-6 then
		return b
	end
	return a + d / l * delta
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local Movement = {}
Movement.__index = Movement

export type Controller = typeof(setmetatable({} :: any, Movement))

function Movement.new(character: Model)
	local self = setmetatable({}, Movement)
	self.character = character
	self.humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self.root = character:WaitForChild("HumanoidRootPart") :: BasePart
	character:WaitForChild("Collider")
	while character:GetAttribute("FeetOffset") == nil do
		character:GetAttributeChangedSignal("FeetOffset"):Wait()
	end
	self.feetOffset = character:GetAttribute("FeetOffset") :: number -- studs

	-- État (mêmes noms que fighter.gd).
	self.vel = Vector3.zero
	self.stamina = ST.MAX
	self.sprinting = false
	self.gliding = false
	self.boosting = false
	self.boostT = 0
	self.heldSinceJump = false
	self.pressBuffer = 0
	self.coyote = 0
	self.regenWait = 0
	self.walljumpCd = 0
	self.padCd = 0
	self.accelCd = 0
	self.knockT = 0
	self.groundLock = 0
	self.wasOnFloor = true
	self.prevHeld = false
	self.onFloor = false
	self.surface = "rocket"
	self.surfacePart = nil :: BasePart?
	self.frozen = false
	self.zooming = false
	self.zoomLock = false
	self.yaw = 0

	-- Paramètres des requêtes : seulement ce contre quoi le Collider bute.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.CollisionGroup = Config.Groups.COLLIDER
	params.RespectCanCollide = true
	self.params = params

	self:_setupPhysics()
	return self
end

function Movement:_setupPhysics()
	local root = self.root
	-- Le Humanoid n'agit plus (pas de marche, pas de saut, pas de redressement).
	local humanoid = self.humanoid
	pcall(function()
		(humanoid :: any).EvaluateStateMachine = false
	end)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local att = root:FindFirstChild("CavaleAttachment") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "CavaleAttachment"
		att.Parent = root
	end

	local antiGravity = Instance.new("VectorForce")
	antiGravity.Name = "CavaleAntiGravity"
	antiGravity.Attachment0 = att
	antiGravity.RelativeTo = Enum.ActuatorRelativeTo.World
	antiGravity.ApplyAtCenterOfMass = true
	antiGravity.Parent = root
	self.antiGravity = antiGravity

	local align = Instance.new("AlignOrientation")
	align.Name = "CavaleAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.RigidityEnabled = true
	align.Parent = root
	self.align = align

	local spawnYaw = self.character:GetAttribute("SpawnYaw")
	self.yaw = if type(spawnYaw) == "number" then spawnYaw else select(2, root.CFrame:ToOrientation())
end

function Movement:feetPosition(): Vector3 -- mètres
	local p = self.root.Position
	return Vector3.new(p.X, p.Y - self.feetOffset, p.Z) / S
end

function Movement:eyePosition(): Vector3 -- studs
	local p = self.root.Position
	return Vector3.new(p.X, p.Y - self.feetOffset + B.EYE_HEIGHT * S, p.Z)
end

-- Sol sous les pieds : (au sol ?, hauteur du sol en m, normale, Part touchée).
function Movement:_probeFloor(feetY: number)
	local rootPos = self.root.Position
	local originY = rootPos.Y / S
	local castLen = (originY - feetY) - PROBE_RADIUS + B.STEP_HEIGHT + 0.1
	local result = Workspace:Spherecast(rootPos, PROBE_RADIUS * S, Vector3.new(0, -castLen * S, 0), self.params)
	if not result then
		return false, 0, Vector3.yAxis, nil
	end
	local groundY = result.Position.Y / S
	local n = result.Normal
	-- Sur l'arête d'un bloc, la normale d'un Spherecast penche : comme une capsule Godot,
	-- on tient debout sur le bord tant que le dessus du bloc est sous nous.
	local inst = result.Instance
	if inst:IsA("Part") and inst.Shape == Enum.PartType.Block then
		local top = inst.Position.Y + inst.Size.Y / 2
		if math.abs(result.Position.Y - top) < 0.05 then
			n = Vector3.yAxis
		end
	end
	if n.Y < MIN_FLOOR_NY then
		return false, groundY, n, result.Instance
	end
	local gap = feetY - groundY
	local snap
	if self.wasOnFloor and self.groundLock <= 0 then
		snap = B.STEP_HEIGHT -- on suit le sol (descente de rampe, petites marches)
	elseif self.vel.Y <= 0.5 and self.groundLock <= 0 then
		snap = LAND_SNAP -- on retombe : contact
	else
		return false, groundY, n, result.Instance
	end
	if gap <= snap then
		return true, groundY, n, result.Instance
	end
	return false, groundY, n, result.Instance
end

function Movement:_drain(amount: number)
	self.stamina = math.max(0, self.stamina - amount)
	self.regenWait = ST.REGEN_DELAY
end

function Movement:_jump(held: boolean)
	local full = self.stamina >= ST.COST_JUMP
	self:_drain(ST.COST_JUMP)
	local v = self.vel
	self.vel = Vector3.new(v.X, math.max(v.Y, 0) + M.JUMP_MIN_VY, v.Z)
	self.boosting = full and held
	self.boostT = 0
	self.heldSinceJump = held
	self.sprinting = false
	self.coyote = 0
	self.pressBuffer = 0
	self.groundLock = GROUND_LOCK
	self.onJump = true
end

function Movement:_wallNormal(): Vector3
	local origin = self.root.Position - Vector3.new(0, self.feetOffset, 0) + Vector3.new(0, 0.9 * S, 0)
	local len = (B.RADIUS + 0.45) * S
	for i = 0, 7 do
		local a = i * math.pi * 2 / 8
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local hit = Workspace:Raycast(origin, d * len, self.params)
		if hit and math.abs(hit.Normal.Y) < 0.3 then
			return flat(hit.Normal).Unit
		end
	end
	return Vector3.zero
end

function Movement:_tryWalljump(): boolean
	if self.walljumpCd > 0 or self.stamina < ST.COST_WALLJUMP * 0.5 then
		return false
	end
	local n = self:_wallNormal()
	if n == Vector3.zero then
		return false
	end
	local h = flat(self.vel)
	local into = h:Dot(n)
	if into < 0 then
		h -= n * into
	end
	h = h * M.WALLJUMP_KEEP + n * M.WALLJUMP_PUSH
	self.vel = Vector3.new(h.X, M.WALLJUMP_VY, h.Z)
	self:_drain(ST.COST_WALLJUMP)
	self.walljumpCd = M.WALLJUMP_DELAY
	self.pressBuffer = 0
	self.heldSinceJump = true
	self.boosting = false
	self.sprinting = false
	self.groundLock = GROUND_LOCK
	self.onWalljump = true
	return true
end

-- Poussée extérieure (explosion de roquette) en m/s — knockback() de fighter.gd.
-- Appliquée au prochain pas (la vitesse est relue depuis la physique à chaque pas).
function Movement:addImpulse(impulse: Vector3)
	if self.frozen then
		return
	end
	self.pendingImpulse = (self.pendingImpulse or Vector3.zero) + impulse
end

function Movement:resetState()
	self.vel = Vector3.zero
	self.stamina = ST.MAX
	self.sprinting, self.gliding, self.boosting = false, false, false
	self.pressBuffer, self.coyote, self.regenWait = 0, 0, 0
	self.walljumpCd, self.padCd, self.accelCd, self.knockT = 0, 0, 0, 0
end

-- input : { move: Vector2, held: boolean, pressed: boolean, walk: boolean }
function Movement:step(dt: number, input)
	local root = self.root
	if not root.Parent then
		return
	end
	dt = math.min(dt, 1 / 20)
	-- Compte à rebours : on peut viser, pas bouger ni tirer (attribut posé par le serveur).
	self.frozen = self.character:GetAttribute("Frozen") == true
	self.onJump, self.onWalljump, self.onLand, self.onPad, self.onAccel = false, false, false, false, false

	-- Vitesse réelle après la physique de l'image précédente (murs, plafonds).
	self.vel = root.AssemblyLinearVelocity / S

	local impulse = self.pendingImpulse
	local knocked = false
	if impulse then
		self.pendingImpulse = nil
		self.vel += impulse
		self.knockT = Config.Rocket.KNOCK_TIME
		self.boosting = false
		knocked = impulse.Magnitude > 2.0
	end

	-- Minuteurs.
	self.pressBuffer = math.max(0, self.pressBuffer - dt)
	self.walljumpCd = math.max(0, self.walljumpCd - dt)
	self.padCd = math.max(0, self.padCd - dt)
	self.accelCd = math.max(0, self.accelCd - dt)
	self.groundLock = math.max(0, self.groundLock - dt)

	local feet = self:feetPosition()
	local floorNow, groundY, groundN, groundPart = self:_probeFloor(feet.Y)
	local onFloor = floorNow
	if knocked and floorNow then
		-- Au sol, une poussée décolle (sinon l'accroche au sol l'écraserait).
		self.vel = Vector3.new(self.vel.X, math.max(self.vel.Y, Config.Rocket.KNOCK_MIN_VY), self.vel.Z)
		self.groundLock = GROUND_LOCK
		floorNow, onFloor = false, false
	end
	if floorNow then
		self.surfacePart = groundPart
		self.surface = groundPart and groundPart:GetAttribute("Surface") or "rocket"
	end

	-- Plateforme Rail : le bouton de mobilité zoome au lieu de sauter. Tant qu'il reste
	-- tenu depuis le zoom, il est ignoré (on ne saute pas en quittant la plateforme).
	local rawHeld = input.held
	if floorNow and self.surface == "rail" and not self.frozen then
		self.zooming = rawHeld
		self.zoomLock = rawHeld
		self.sprinting = false
	else
		self.zooming = false
		if not rawHeld then
			self.zoomLock = false
		end
	end

	-- Bouton de mobilité.
	local held = rawHeld and not self.zoomLock
	local pressed = input.pressed and not self.zoomLock
	local released = self.prevHeld and not held
	self.prevHeld = held
	if self.frozen then
		pressed = false
	end
	if pressed then
		self.pressBuffer = M.PRESS_BUFFER
	end
	if released then
		self.heldSinceJump = false
		self.boosting = false
	end
	if not held then
		self.gliding = false
	end

	local wish = Vector3.zero
	if not self.frozen then
		local mv = input.move
		if mv.Magnitude > 1 then
			mv = mv.Unit
		end
		local yaw = self.yaw
		local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
		local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		wish = right * mv.X + forward * mv.Y
	end
	local drained = false

	if onFloor then
		self.coyote = M.COYOTE
		if not self.wasOnFloor then
			self.onLand = true
			if held and (self.heldSinceJump or self.pressBuffer > 0) and wish.Magnitude > 0.1 and self.stamina > 0.05 then
				-- Atterrir bouton tenu avec une direction → sprint.
				self.sprinting = true
				self.pressBuffer = 0
				pressed = false
			elseif self.pressBuffer > 0 and not held then
				pressed = true
			end
		end
	else
		self.coyote -= dt
	end

	-- Saut / wall-jump.
	if pressed and (onFloor or self.coyote > 0) then
		self:_jump(held)
		onFloor = false
	elseif pressed and not onFloor then
		self:_tryWalljump()
	end

	-- Pads et accélérateurs.
	if onFloor and not self.frozen then
		if self.surface == "pad" and self.padCd <= 0 then
			self.vel = Vector3.new(self.vel.X, M.PAD_VY, self.vel.Z)
			self.padCd = 0.35
			self.boosting, self.sprinting = false, false
			self.groundLock = GROUND_LOCK
			onFloor = false
			self.onPad = true
		elseif self.surface == "accel" and self.accelCd <= 0 and self.surfacePart then
			local rot = (self.surfacePart:GetAttribute("Rot") or 0) :: number
			local dirs = { [0] = Vector3.zAxis, [1] = Vector3.xAxis, [2] = -Vector3.zAxis, [3] = -Vector3.xAxis }
			local d = dirs[rot % 4]
			self.vel = Vector3.new(d.X * M.ACCEL_SPEED, M.ACCEL_VY, d.Z * M.ACCEL_SPEED)
			self.accelCd = 0.25
			self.sprinting = false
			self.groundLock = GROUND_LOCK
			onFloor = false
			self.onAccel = true
		end
	end

	-- Gravité, montée prolongée, plané.
	local vy = self.vel.Y
	if not onFloor then
		local g = M.GRAVITY
		if self.boosting then
			self.boostT += dt
			local k = math.clamp(self.boostT / M.JUMP_BOOST_TIME, 0, 1)
			vy = math.max(vy, M.JUMP_MIN_VY + (M.JUMP_FULL_VY - M.JUMP_MIN_VY) * k * k)
			g = 0
			if self.boostT >= M.JUMP_BOOST_TIME or not held then
				self.boosting = false
			end
		elseif held and self.stamina > 0 and not self.frozen then
			if vy > 0 and self.heldSinceJump then
				g *= M.RISE_HOLD_GRAVITY
			elseif vy <= 0 then
				self.gliding = true
				g *= M.GLIDE_GRAVITY
				self:_drain(ST.DRAIN_GLIDE * dt)
				drained = true
			end
		else
			self.gliding = false
		end
		vy -= g * dt
		if self.gliding then
			vy = math.max(vy, -M.GLIDE_MAX_FALL)
		end
	else
		self.gliding = false
	end

	-- Déplacement horizontal.
	local h = flat(self.vel)
	self.knockT = math.max(0, self.knockT - dt)
	if onFloor and self.knockT <= 0 then
		local speed = M.RUN_SPEED
		if self.surface == "sprint" then
			speed = M.SPRINT_SPEED
		end
		if input.walk and self.surface ~= "sprint" then
			speed = math.min(speed, M.WALK_SPEED)
			self.sprinting = false
		end
		if self.sprinting then
			if held and self.stamina > 0 and wish.Magnitude > 0.1 then
				speed = M.SPRINT_SPEED
				self:_drain(ST.DRAIN_SPRINT * dt)
				drained = true
			else
				self.sprinting = false
			end
		end
		local target = wish * speed
		if h.Magnitude > speed + 0.2 and (wish == Vector3.zero or h:Dot(wish) > 0) then
			h = moveToward(h, target, M.OVERSPEED_DECEL * dt)
		else
			h = moveToward(h, target, (if wish ~= Vector3.zero then M.GROUND_ACCEL else M.GROUND_FRICTION) * dt)
		end
	elseif not onFloor then
		if wish ~= Vector3.zero then
			local cap = math.max(M.RUN_SPEED, h.Magnitude)
			h = moveToward(h, wish * cap, M.AIR_ACCEL * dt)
		end
	end

	-- Au sol : on suit le plan du sol et on recolle doucement les pieds dessus.
	if onFloor then
		local ny = math.max(groundN.Y, 0.2)
		local planeVy = -(groundN.X * h.X + groundN.Z * h.Z) / ny
		local err = groundY - feet.Y
		vy = planeVy + err / dt * 0.5
	end

	self.vel = Vector3.new(h.X, vy, h.Z)
	self.wasOnFloor = floorNow and onFloor
	self.onFloor = onFloor

	-- Endurance.
	if not drained then
		if self.regenWait > 0 then
			self.regenWait -= dt
		else
			self.stamina = math.min(ST.MAX, self.stamina + ST.REGEN * dt)
		end
	end

	-- Application à Roblox.
	self.antiGravity.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity, 0)
	self.align.CFrame = CFrame.Angles(0, self.yaw, 0)
	root.AssemblyLinearVelocity = self.vel * S
	root.AssemblyAngularVelocity = Vector3.zero
end

function Movement:destroy()
	if self.antiGravity then
		self.antiGravity:Destroy()
	end
	if self.align then
		self.align:Destroy()
	end
end

return Movement
