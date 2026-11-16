-- Serveur : construit la map, prépare les personnages et lance le mode 1v1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MapBuilder = require(Shared.MapBuilder)
local CharacterRig = require(Shared.CharacterRig)
local Combat = require(script.Parent.Combat)
local Joust = require(script.Parent.Joust)

local S = Config.STUDS_PER_METER
local MAP_NAME = "cratere"

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

local map = MapBuilder.build(require(Shared.Maps:WaitForChild(MAP_NAME)), workspace)
print(("[Cavale] Map « %s » construite, %d spawns"):format(map.name, #map.spawns))

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	-- La taille de l'avatar (HipHeight) n'est juste qu'une fois l'apparence chargée.
	local t0 = os.clock()
	while not player:HasAppearanceLoaded() and os.clock() - t0 < 3 do
		task.wait()
	end
	if player.Character ~= character then
		return
	end
	-- On pose d'abord le personnage au spawn (orientation comprise), puis on prépare le rig :
	-- le client attend l'attribut FeetOffset, il trouvera donc déjà la bonne orientation.
	local feet = CharacterRig.feetOffset(humanoid, root)
	local spawnCf = Joust.spawnCFrame(player)
	character:SetAttribute("SpawnYaw", select(2, spawnCf:ToOrientation()))
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

Joust.init(map, Combat)

-- Hors des limites (y < -20 m) → éliminé (« est tombé en service » / « s'est vautré »).
local killY = Config.Move.KILL_Y * S
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < killY and not character:GetAttribute("Falling") then
				character:SetAttribute("Falling", true)
				Joust.kill(player, "fall")
			end
		end
	end
end)
