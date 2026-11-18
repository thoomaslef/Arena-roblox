-- Serveur : garde les réglages de chaque joueur (touches, sensibilité) dans un DataStore.
-- Dans Studio, il faut activer « Autoriser l'accès de Studio aux services d'API »
-- (Paramètres du jeu → Sécurité) sur une place publiée ; sinon les réglages marchent
-- pendant la partie mais ne sont pas gardés.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerSettings = {}

local remote = Instance.new("RemoteEvent")
remote.Name = "Settings"
remote.Parent = ReplicatedStorage:WaitForChild("Remotes")

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("CavaleSettings_v1")
end)

local lastSave: { [Player]: number } = {}

local function key(player: Player): string
	return "u" .. player.UserId
end

-- Garde seulement ce qui ressemble à des réglages (protection contre des données bizarres).
local function sanitize(data: any): any?
	if type(data) ~= "table" then
		return nil
	end
	local out = { bindings = {} }
	if type(data.sensitivity) == "number" and data.sensitivity == data.sensitivity then
		out.sensitivity = math.clamp(data.sensitivity, 0.05, 5)
	end
	if type(data.prefs) == "table" then
		local p = {}
		for k, v in data.prefs do
			if type(k) == "string" and #k <= 20 and (type(v) == "number" and v == v or type(v) == "string" and #v <= 20) then
				p[k] = v
			end
		end
		out.prefs = p
	end
	if type(data.bindings) == "table" then
		local n = 0
		for id, keys in data.bindings do
			n += 1
			if n > 20 then
				break
			end
			if type(id) == "string" and #id <= 20 and type(keys) == "table" then
				local a, b = keys[1], keys[2]
				out.bindings[id] = {
					if type(a) == "string" and #a <= 30 then a else "",
					if type(b) == "string" and #b <= 30 then b else "",
				}
			end
		end
	end
	return out
end

remote.OnServerEvent:Connect(function(player, kind, data)
	if kind == "load" then
		local saved = nil
		if store then
			local ok, res = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				saved = res
			else
				remote:FireClient(player, "info", "set.nosave") -- clé de texte (Lang)
			end
		end
		remote:FireClient(player, "load", saved)
	elseif kind == "save" then
		local now = os.clock()
		if now - (lastSave[player] or -math.huge) < 6 then
			-- Trop rapproché : on réessaie un peu plus tard avec la dernière version.
			task.delay(6, function()
				if player.Parent and os.clock() - (lastSave[player] or 0) >= 6 then
					lastSave[player] = os.clock()
					local clean = sanitize(data)
					if store and clean then
						pcall(function()
							(store :: DataStore):SetAsync(key(player), clean)
						end)
					end
				end
			end)
			return
		end
		lastSave[player] = now
		local clean = sanitize(data)
		if store and clean then
			pcall(function()
				(store :: DataStore):SetAsync(key(player), clean)
			end)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)

return PlayerSettings
