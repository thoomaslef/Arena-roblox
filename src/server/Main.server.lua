-- Serveur : prépare les personnages et lance le mode 1v1 (qui choisit et construit la map).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CharacterRig = require(Shared.CharacterRig)
local Combat = require(script.Parent.Combat)
local Joust = require(script.Parent.Joust)
require(script.Parent.PlayerSettings) -- réglages des joueurs (touches, sensibilité)
local MoveGuard = require(script.Parent.MoveGuard)
Combat.onPush = MoveGuard.notePush

-- Progression (XP, niveaux, classement, défis du jour) et salons privés.
local Profiles = require(script.Parent.Profiles)
local Rooms = require(script.Parent.Rooms)
Profiles.isPrivateServer = Rooms.isPrivate
Joust.allowBot = function(): boolean
	return not Rooms.isReservedRoom() -- salon entre amis : on attend l'ami, pas de bot
end
local PR = Config.Progress
local function isPlayer(p: any): boolean
	return typeof(p) == "Instance" and p:IsA("Player")
end
local function multAgainst(opponent: any): number
	return if isPlayer(opponent) then 1 else PR.VS_BOT_MULT
end
Combat.onShot = function(shooter)
	Profiles.stat(shooter, "shots")
end
Combat.onHitScored = function(attacker, victim, killed, weapon, airborne)
	Profiles.stat(attacker, "hits")
	Profiles.addXP(attacker, PR.XP_HIT + (if killed then PR.XP_KILL else 0), multAgainst(victim))
	Profiles.event(attacker, "hit")
	if weapon == "rail" then
		Profiles.stat(attacker, "railHits")
		Profiles.event(attacker, "railHit")
	end
	if airborne then
		Profiles.stat(attacker, "airshots")
		Profiles.event(attacker, "airshot")
	end
	if killed then
		Profiles.stat(attacker, "kills")
		Profiles.event(attacker, "kill")
	end
end
Combat.onDetonated = function(by)
	Profiles.stat(by, "detonations")
	Profiles.addXP(by, PR.XP_DETONATE)
	Profiles.event(by, "detonate")
end
Joust.onMatchStarted = function(fighters)
	Profiles.matchStarted(fighters)
end
Joust.onRoundWon = function(winner, loser)
	Profiles.stat(winner, "roundsWon")
	Profiles.stat(winner, "rounds")
	Profiles.stat(loser, "rounds")
	Profiles.addXP(winner, PR.XP_ROUND_WON, multAgainst(loser))
	Profiles.event(winner, "roundWon")
	-- Manche sans perdre une vie.
	if typeof(winner) == "Instance" and winner:GetAttribute("Lives") == Config.Joust.LIVES then
		Profiles.event(winner, "flawless")
	end
end
Joust.onMatchEnded = function(winner, loser, forfeit)
	Profiles.matchEnded(winner, loser, forfeit)
end
local Bots = require(script.Parent.Bot)

local S = Config.STUDS_PER_METER

-- Le gabarit « Baseplate » de Studio pose un sol et un point d'apparition : on les retire.
for _, name in { "Baseplate", "SpawnLocation" } do
	local inst = workspace:FindFirstChild(name)
	if inst then
		inst:Destroy()
	end
end

workspace.Gravity = Config.Move.GRAVITY * S
CharacterRig.setupCollisionGroups()

-- C'est le mode qui décide quand les joueurs apparaissent.
Players.CharacterAutoLoads = false

-- La map est construite par le mode (Joust.init, puis une nouvelle à chaque match).

-- Prépare un personnage (joueur ou bot) : posé au spawn, rig de collision, vies, armes.
local function onCharacter(player: any, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	-- La taille de l'avatar (HipHeight) n'est juste qu'une fois l'apparence chargée.
	if typeof(player) == "Instance" then
		local t0 = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - t0 < 3 do
			task.wait()
		end
	end
	if player.Character ~= character then
		return
	end
	-- On pose d'abord le personnage au spawn (orientation comprise), puis on prépare le rig :
	-- le client attend l'attribut FeetOffset, il trouvera donc déjà la bonne orientation.
	local feet = CharacterRig.feetOffset(humanoid, root)
	local spawnCf = Joust.spawnCFrame(player)
	character:SetAttribute("SpawnYaw", select(2, spawnCf:ToOrientation()))
	if typeof(player) == "Instance" then
		MoveGuard.reset(player) -- apparition voulue : l'anti-triche repart de zéro
	end
	character:PivotTo(spawnCf + Vector3.new(0, feet + 0.05 * S, 0))
	CharacterRig.prepare(character)

	player:SetAttribute("Lives", Config.Joust.LIVES)
	Combat.resetArms(player)
	Joust.onCharacterReady(player)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end)
for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

-- Inclinaison de la visée (haut / bas) : le client l'envoie ~15 fois par seconde, le serveur
-- la recopie en attribut du personnage pour que les autres voient où il vise.
local aimRemote = Instance.new("UnreliableRemoteEvent")
aimRemote.Name = "Aim"
aimRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")
local lastAim: { [Player]: number } = {}
aimRemote.OnServerEvent:Connect(function(player, pitch)
	if type(pitch) ~= "number" or pitch ~= pitch then
		return
	end
	local now = os.clock()
	if now - (lastAim[player] or 0) < 0.04 then
		return
	end
	lastAim[player] = now
	local character = player.Character
	if character then
		character:SetAttribute("AimPitch", math.floor(math.clamp(pitch, -1.5, 1.5) * 50 + 0.5) / 50)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	lastAim[player] = nil
end)

Bots.setSpawner(onCharacter)
Joust.init(Combat)

-- Hors des limites (y < -20 m) → éliminé (« est tombé en service » / « s'est vautré »).
local killY = Config.Move.KILL_Y * S
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in Combat.combatants() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < killY and not character:GetAttribute("Falling") then
				character:SetAttribute("Falling", true)
				Joust.kill(player, "fall")
			end
		end
	end
end)
