-- Serveur — étape 2 : map Cratère + apparition des joueurs + chute hors limites.
-- Les règles du 1v1 (vies, manches, gaz) arriveront à l'étape 5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MapBuilder = require(Shared.MapBuilder)
local CharacterRig = require(Shared.CharacterRig)

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

local map = MapBuilder.build(require(Shared.Maps:WaitForChild(MAP_NAME)), workspace)
print(("[Cavale] Map « %s » construite, %d spawns"):format(map.name, #map.spawns))

Players.RespawnTime = 0.5

local nextSpawn = 1
local function pickSpawn(): CFrame
	local cf = map.spawns[nextSpawn] or CFrame.new(map.center * S + Vector3.new(0, 1 * S, 0))
	nextSpawn = nextSpawn % math.max(1, #map.spawns) + 1
	return cf
end

local function onCharacter(player: Player, character: Model)
	-- La taille de l'avatar (HipHeight) n'est juste qu'une fois l'apparence chargée.
	local t0 = os.clock()
	while not player:HasAppearanceLoaded() and os.clock() - t0 < 3 do
		task.wait()
	end
	if player.Character ~= character then
		return
	end
	CharacterRig.prepare(character)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local feet = character:GetAttribute("FeetOffset") :: number
	-- Le spawn donne la position des pieds : on place le centre du corps au-dessus.
	local spawnCf = pickSpawn()
	character:PivotTo(spawnCf + Vector3.new(0, feet + 0.05 * S, 0))
	humanoid.Died:Connect(function()
		task.wait(Players.RespawnTime)
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end)
end

-- Hors des limites (y < -20 m) → réapparition.
local killY = Config.Move.KILL_Y * S
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and root.Position.Y < killY and not character:GetAttribute("Falling") then
				-- On recharge directement le personnage : le Humanoid étant en état Physics,
				-- on ne compte pas sur son événement Died.
				character:SetAttribute("Falling", true)
				task.delay(Players.RespawnTime, function()
					if player.Parent and player.Character == character then
						player:LoadCharacter()
					end
				end)
			end
		end
	end
end)
