-- Serveur : salons privés entre amis.
--   * « Créer un salon » : le serveur réserve un serveur Roblox (TeleportService:ReserveServer),
--     invente un code de 6 caractères, le garde 3 h dans MemoryStore, et y téléporte le joueur.
--   * « Rejoindre » avec le code : on retrouve le serveur réservé et on y téléporte le joueur.
--   * Dans un salon (ou un serveur privé payant de Roblox) : pas de bot, matchs non classés.
--     Le code s'affiche à l'accueil (attribut Match.RoomCode).
-- Ne marche pas dans Studio (la téléportation n'y est pas possible) : un message le dit.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Rooms = {}

local CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" -- sans 0/O ni 1/I/L (confusions)
local CODE_TTL = 3 * 3600

local remote = Instance.new("RemoteEvent")
remote.Name = "Rooms"
remote.Parent = ReplicatedStorage:WaitForChild("Remotes")

local codes = nil
pcall(function()
	codes = MemoryStoreService:GetSortedMap("CavaleRooms")
end)

-- Ce serveur est-il privé ? (salon réservé par le jeu, ou serveur privé payant Roblox)
function Rooms.isPrivate(): boolean
	return game.PrivateServerId ~= ""
end

-- Salon réservé par le jeu (et non serveur privé payant) ?
function Rooms.isReservedRoom(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function newCode(): string
	local rng = Random.new()
	local out = {}
	for i = 1, 6 do
		local k = rng:NextInteger(1, #CODE_CHARS)
		out[i] = CODE_CHARS:sub(k, k)
	end
	return table.concat(out)
end

local function teleport(player: Player, accessCode: string, code: string): boolean
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData({ roomCode = code })
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[Cavale] Téléportation vers le salon impossible :", err)
	end
	return ok
end

local busy: { [Player]: boolean } = {}

remote.OnServerEvent:Connect(function(player, action, code)
	if busy[player] then
		return
	end
	if RunService:IsStudio() then
		remote:FireClient(player, "error", "room.err_studio")
		return
	end
	busy[player] = true
	if action == "create" then
		local ok, accessCode = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		local roomCode = newCode()
		local stored = ok and codes and pcall(function()
			codes:SetAsync(roomCode, accessCode, CODE_TTL)
		end)
		if ok and stored then
			remote:FireClient(player, "teleporting", roomCode)
			if not teleport(player, accessCode, roomCode) then
				remote:FireClient(player, "error", "room.err_fail")
			end
		else
			remote:FireClient(player, "error", "room.err_fail")
		end
	elseif action == "join" and type(code) == "string" then
		local clean = code:upper():gsub("[^A-Z0-9]", ""):sub(1, 6)
		local accessCode = nil
		if codes and #clean == 6 then
			pcall(function()
				accessCode = codes:GetAsync(clean)
			end)
		end
		if accessCode then
			remote:FireClient(player, "teleporting", clean)
			if not teleport(player, accessCode, clean) then
				remote:FireClient(player, "error", "room.err_fail")
			end
		else
			remote:FireClient(player, "error", "room.err_code")
		end
	end
	task.delay(3, function()
		busy[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

-- Dans un salon : on affiche son code (venu des données de téléportation du premier joueur).
local function publishCode(player: Player)
	if not Rooms.isPrivate() then
		return
	end
	local match = ReplicatedStorage:FindFirstChild("Match")
	if not match then
		return
	end
	match:SetAttribute("Private", true)
	if Rooms.isReservedRoom() and not match:GetAttribute("RoomCode") then
		local data = player:GetJoinData()
		local td = data and data.TeleportData
		if type(td) == "table" and type(td.roomCode) == "string" then
			match:SetAttribute("RoomCode", td.roomCode)
		end
	end
end
Players.PlayerAdded:Connect(publishCode)
for _, p in Players:GetPlayers() do
	publishCode(p)
end

return Rooms
