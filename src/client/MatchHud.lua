-- HUD du match 1v1 : score (Flics à gauche, Bandits à droite), manche, chrono du gaz,
-- messages centraux (3 · 2 · 1 · GO, MANCHE GAGNÉE / PERDUE, ÉGALITÉ), fil des éliminations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Fx = require(script.Parent.Fx)
local Lang = require(Shared:WaitForChild("Lang"))
local Sfx = require(script.Parent.Sfx)

local TEAMS = Config.Teams
local TOXIC = Config.Joust.GAS_COLOR

local player = Players.LocalPlayer
local match = ReplicatedStorage:WaitForChild("Match")
local matchRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Match") :: RemoteEvent

local MatchHud = {}

local gui = Instance.new("ScreenGui")
gui.Name = "CavaleMatch"
gui.AutoLocalize = false -- nos textes sont déjà traduits (Lang) : pas de traduction auto de Roblox
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2

local function label(props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

-- Bandeau du score -------------------------------------------------------------------
local top = Instance.new("Frame")
top.Name = "Score"
top.BackgroundTransparency = 1
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 10)
top.Size = UDim2.fromOffset(520, 64)
top.Parent = gui

local function scoreBox(side: number): (Frame, TextLabel, TextLabel)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = TEAMS[side].color
	f.BackgroundTransparency = 0.15
	f.Size = UDim2.fromOffset(170, 50)
	f.AnchorPoint = Vector2.new(if side == 0 then 0 else 1, 0)
	f.Position = UDim2.fromScale(if side == 0 then 0 else 1, 0)
	f.Parent = top
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	local name = label({
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(if side == 0 then 10 else 50, 0),
		TextSize = 15,
		TextXAlignment = if side == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = Lang.teamName(side),
		Parent = f,
	})
	local num = label({
		Size = UDim2.new(0, 50, 1, 0),
		Position = UDim2.new(if side == 0 then 1 else 0, if side == 0 then -50 else 0, 0, 0),
		TextSize = 32,
		Font = Enum.Font.GothamBlack,
		Text = "0",
		Parent = f,
	})
	return f, name, num
end
local _, name1, num1 = scoreBox(0)
local _, name2, num2 = scoreBox(1)

local mid = label({ Size = UDim2.fromOffset(170, 22), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), TextSize = 16, Text = "", Parent = top })
local timer = label({ Size = UDim2.fromOffset(170, 26), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), TextSize = 22, Font = Enum.Font.GothamBlack, Text = "", Parent = top })
local status = label({ Size = UDim2.fromOffset(600, 24), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), TextSize = 18, Text = "", Parent = gui })

-- Message central -------------------------------------------------------------------
local centerTitle = label({ Size = UDim2.fromOffset(900, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), TextSize = 54, Font = Enum.Font.GothamBlack, Text = "", TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
local rewardsLabel = label({ Size = UDim2.fromOffset(900, 80), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.32, 70), TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 220, 110), Text = "", TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
local centerSub = label({ Size = UDim2.fromOffset(900, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.32, 46), TextSize = 20, Text = "", TextTransparency = 1, TextStrokeTransparency = 1, Parent = gui })
local messageToken = 0

function MatchHud.centerMessage(title: string, duration: number, color: Color3?, sub: string?)
	messageToken += 1
	local token = messageToken
	centerTitle.Text = title
	centerTitle.TextColor3 = color or Color3.new(1, 1, 1)
	centerSub.Text = sub or ""
	for _, l in { centerTitle, centerSub } do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.4
	end
	task.delay(duration, function()
		if token ~= messageToken then
			return
		end
		for _, l in { centerTitle, centerSub } do
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Fil des éliminations --------------------------------------------------------------------
local feed = Instance.new("Frame")
feed.BackgroundTransparency = 1
feed.AnchorPoint = Vector2.new(1, 0)
feed.Position = UDim2.new(1, -12, 0, 90)
feed.Size = UDim2.fromOffset(380, 200)
feed.Parent = gui
local feedLayout = Instance.new("UIListLayout")
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Padding = UDim.new(0, 4)
feedLayout.Parent = feed
local feedOrder = 0

function MatchHud.killfeed(text: string, color: Color3?)
	feedOrder += 1
	local l = label({ Size = UDim2.fromOffset(380, 22), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Text = text, TextColor3 = color or Color3.new(1, 1, 1), LayoutOrder = feedOrder, Parent = feed })
	task.delay(5, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.6)
		l:Destroy()
	end)
end

gui.Parent = player:WaitForChild("PlayerGui")

-- Aides -------------------------------------------------------------------------------------
local function myIndex(): number?
	if match:GetAttribute("UserId1") == player.UserId then
		return 1
	elseif match:GetAttribute("UserId2") == player.UserId then
		return 2
	end
	return nil
end
MatchHud.myIndex = myIndex

local function lighten(c: Color3): Color3
	return c:Lerp(Color3.new(1, 1, 1), 0.2)
end

local function scoreLine(): string
	return ("%s  %d – %d  %s"):format(
		match:GetAttribute("Name1") or "?",
		match:GetAttribute("Score1") or 0,
		match:GetAttribute("Score2") or 0,
		match:GetAttribute("Name2") or "?"
	)
end

-- Temps de manche (s depuis le GO) selon l'état répliqué.
function MatchHud.roundTime(): number
	if match:GetAttribute("State") ~= "live" and match:GetAttribute("State") ~= "post" then
		return 0
	end
	local start = match:GetAttribute("LiveStart")
	if type(start) ~= "number" then
		return 0
	end
	return math.max(0, Workspace:GetServerTimeNow() - start)
end

-- Compte à rebours « 3 · 2 · 1 · GO ».
local function runCountdown(round: number)
	local endTime = match:GetAttribute("CountdownEnd")
	if type(endTime) ~= "number" then
		return
	end
	local sub = Lang.t("m.countdown_sub", round, match:GetAttribute("Score1") or 0, match:GetAttribute("Score2") or 0, Lang.mapName(match:GetAttribute("MapName")))
	local shown = -1
	while true do
		local left = endTime - Workspace:GetServerTimeNow()
		if left <= 0 then
			break
		end
		local n = math.ceil(left)
		if n ~= shown then
			shown = n
			MatchHud.centerMessage(tostring(n), 1.2, Color3.new(1, 1, 1), sub)
			Sfx.play("beep")
		end
		task.wait()
	end
	MatchHud.centerMessage(Lang.t("m.go"), 0.7, Color3.fromRGB(255, 230, 120), sub)
	-- Sirène pour les Flics, coup de sifflet pour les Bandits (chacun entend celui de son camp).
	Sfx.play(if myIndex() == 2 then "whistle" else "siren", -2)
end

matchRemote.OnClientEvent:Connect(function(kind: string, ...)
	if kind == "countdown" then
		local round = ...
		task.spawn(runCountdown, round)
	elseif kind == "result" then
		local winner = ...
		if winner == 0 then
			MatchHud.centerMessage(Lang.t("m.tie"), 2.4, Color3.new(1, 1, 1), Lang.t("m.tie_sub"))
			return
		end
		local i = myIndex()
		local col = lighten(TEAMS[winner - 1].color)
		local title = if i == nil then Lang.t("m.round_team", Lang.teamName(winner - 1)) elseif i == winner then Lang.t("m.round_won") else Lang.t("m.round_lost")
		MatchHud.centerMessage(title, 2.6, col, scoreLine())
		-- Jingle de manche, sauf la dernière (celui de fin de match suffit).
		local s1, s2 = match:GetAttribute("Score1") or 0, match:GetAttribute("Score2") or 0
		if i ~= nil and not (math.max(s1, s2) >= Config.Joust.WIN_SCORE and math.abs(s1 - s2) >= Config.Joust.WIN_GAP) then
			Sfx.play(if i == winner then "win" else "lose")
		end
	elseif kind == "matchEnd" then
		local winner, s1, s2 = ...
		local champ = match:GetAttribute("Name" .. winner) or "?"
		local i = myIndex()
		local title = if i == nil then Lang.t("m.duel_over") elseif i == winner then Lang.t("m.victory") else Lang.t("m.defeat")
		MatchHud.centerMessage(title, 7, lighten(TEAMS[winner - 1].color), Lang.t("m.champ", champ, s1, s2))
		if i ~= nil then
			Sfx.play(if i == winner then "win" else "lose")
		end
	elseif kind == "death" then
		local pos, cause, killerName, victimName, killerTeam, verbIndex, victimTeam = ...
		if typeof(pos) == "Vector3" then
			Fx.explosion(pos)
			Sfx.playAt("death", pos)
		end
		local text = Lang.killText(cause, killerName, victimName or "?", killerTeam, verbIndex, victimTeam)
		local colorTeam = if killerTeam ~= nil then killerTeam else 1 - (victimTeam or 0)
		MatchHud.killfeed(text, lighten(TEAMS[colorTeam].color))
	elseif kind == "info" then
		local titleKey, subKey = ...
		MatchHud.centerMessage(Lang.t(titleKey), 3, Color3.new(1, 1, 1), Lang.t(subKey))
	end
end)

-- Nom d'un combattant dans le bandeau, avec son niveau s'il en a un (pas les bots).
local function fighterName(index: number, team: number): string
	local name = match:GetAttribute("Name" .. index)
	if type(name) ~= "string" or name == "" then
		return Lang.teamName(team)
	end
	local userId = match:GetAttribute("UserId" .. index)
	local p = if type(userId) == "number" and userId > 0 then Players:GetPlayerByUserId(userId) else nil
	local level = p and p:GetAttribute("Level")
	if level then
		return ("%s  ·  %d"):format(name, level)
	end
	return name
end

-- Récompenses de fin de match (XP, niveau, classement) : sous VICTOIRE / DÉFAITE.
local rewardsRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rewards") :: RemoteEvent
-- Défi du jour réussi : bandeau en haut de l'écran.
-- Interface à part : visible aussi dans le menu et le tutoriel.
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "CavaleToast"
toastGui.AutoLocalize = false
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.DisplayOrder = 40
toastGui.Parent = player:WaitForChild("PlayerGui")
local toast = label({ Size = UDim2.fromOffset(700, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(120, 255, 150), Text = "", TextTransparency = 1, TextStrokeTransparency = 1, Parent = toastGui })
local toastToken = 0
local function showChallenge(c)
	toastToken += 1
	local token = toastToken
	toast.Text = Lang.t("dc.done") .. "\n" .. Lang.t("dc.done_sub", Lang.t("dc." .. tostring(c.id), c.target or 1), c.xp or 0)
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	Sfx.play("win", -4, 1.2)
	task.delay(4, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

rewardsRemote.OnClientEvent:Connect(function(kind, r)
	if type(r) ~= "table" then
		return
	end
	if kind == "challenge" then
		showChallenge(r)
		return
	end
	local lines = { Lang.t("rw.xp", r.xp or 0) }
	if type(r.stats) == "table" then
		table.insert(lines, Lang.t("rw.stats", r.stats.accuracy or 0, r.stats.hits or 0, r.stats.kills or 0))
	end
	if r.levelUp then
		table.insert(lines, Lang.t("rw.levelup", r.level or 1))
	end
	if r.vsBot then
		table.insert(lines, Lang.t("rw.vs_bot"))
	elseif r.ranked ~= false and type(r.ratingDelta) == "number" then
		-- (Serveur privé : ranked = false, pas de points classés.)
		local rankName = if r.rankKey and r.rankKey ~= "unranked" then Lang.t("rank." .. r.rankKey) else Lang.t("menu.unranked", math.max(1, Config.Ranked.PLACEMENT_GAMES - ((player:GetAttribute("RankedGames") or 0))))
		table.insert(lines, Lang.t("rw.rating", r.ratingDelta, rankName))
	end
	rewardsLabel.Text = table.concat(lines, "\n")
	rewardsLabel.TextTransparency = 0
	rewardsLabel.TextStrokeTransparency = 0.4
	if r.levelUp then
		Sfx.play("win", -2, 1.3)
	end
	task.delay(7, function()
		TweenService:Create(rewardsLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end)

-- Vote de map (fin de match) : 3 cartes cliquables, touches 1 / 2 / 3.
local lobbyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby") :: RemoteEvent
local votePanel = Instance.new("Frame")
votePanel.Name = "Vote"
votePanel.BackgroundTransparency = 1
votePanel.AnchorPoint = Vector2.new(0.5, 1)
votePanel.Position = UDim2.new(0.5, 0, 1, -40)
votePanel.Size = UDim2.fromOffset(780, 190)
votePanel.Visible = false
votePanel.Parent = gui
local voteTitle = label({ Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 200, 80), Parent = votePanel })
local voteHint = label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(200, 205, 215), Parent = votePanel })
local voteBar = Instance.new("Frame")
voteBar.BorderSizePixel = 0
voteBar.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
voteBar.Position = UDim2.new(0, 0, 1, -4)
voteBar.Size = UDim2.new(1, 0, 0, 4)
voteBar.Parent = votePanel
local voteCards = {}
local myVote: string? = nil
for i = 1, 3 do
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
	b.BackgroundTransparency = 0.1
	b.Position = UDim2.new((i - 1) / 3, 6, 0, 58)
	b.Size = UDim2.new(1 / 3, -12, 0, 120)
	b.Text = ""
	b.Parent = votePanel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 200, 80)
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local num = Instance.new("TextLabel")
	num.BackgroundTransparency = 1
	num.Text = tostring(i)
	num.Font = Enum.Font.GothamBlack
	num.TextSize = 16
	num.TextColor3 = Color3.fromRGB(150, 156, 172)
	num.Position = UDim2.fromOffset(10, 6)
	num.Size = UDim2.fromOffset(20, 20)
	num.Parent = b
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 24
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Position = UDim2.new(0, 0, 0, 30)
	name.Size = UDim2.new(1, 0, 0, 34)
	name.Parent = b
	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextSize = 16
	count.TextColor3 = Color3.fromRGB(255, 200, 80)
	count.Position = UDim2.new(0, 0, 0, 72)
	count.Size = UDim2.new(1, 0, 0, 24)
	count.Parent = b
	voteCards[i] = { button = b, name = name, count = count, stroke = stroke, key = "" }
	b.MouseButton1Click:Connect(function()
		local key = voteCards[i].key
		if key ~= "" then
			myVote = key
			lobbyRemote:FireServer("vote", key)
		end
	end)
end

local function voteChoices(): { string }
	local raw = match:GetAttribute("VoteMaps")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	return string.split(raw, ",")
end

function MatchHud.isVoting(): boolean
	return votePanel.Visible
end

-- Vote au clavier (1, 2, 3).
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or not votePanel.Visible then
		return
	end
	local n = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3 })[input.KeyCode]
	local card = n and voteCards[n]
	if card and card.key ~= "" then
		myVote = card.key
		lobbyRemote:FireServer("vote", card.key)
	end
end)

local function updateVote()
	local choices = voteChoices()
	local show = match:GetAttribute("State") == "matchEnd" and #choices > 0 and player:GetAttribute("Mode") == "play"
	votePanel.Visible = show
	if not show then
		myVote = nil
		return
	end
	voteTitle.Text = Lang.t("vote.title")
	voteHint.Text = Lang.t("vote.hint")
	local counts = string.split(tostring(match:GetAttribute("VoteCounts") or ""), ",")
	for i, card in voteCards do
		local key = choices[i]
		card.button.Visible = key ~= nil
		card.key = key or ""
		if key then
			card.name.Text = Lang.mapName(key)
			card.count.Text = Lang.t("vote.count", tonumber(counts[i]) or 0)
			card.stroke.Transparency = if myVote == key then 0 else 1
		end
	end
	local endTime = match:GetAttribute("VoteEnd")
	if type(endTime) == "number" then
		local left = math.clamp((endTime - Workspace:GetServerTimeNow()) / Config.Joust.MATCH_END_PAUSE, 0, 1)
		voteBar.Size = UDim2.new(left, 0, 0, 4)
	end
end

-- Mise à jour à chaque image.
function MatchHud.update(gasStage: number, warn: boolean)
	-- Rien du match à l'écran dans le menu ou le tutoriel.
	gui.Enabled = player:GetAttribute("Mode") == "play"
	updateVote()
	local state = match:GetAttribute("State")
	name1.Text = fighterName(1, 0)
	name2.Text = fighterName(2, 1)
	num1.Text = tostring(match:GetAttribute("Score1") or 0)
	num2.Text = tostring(match:GetAttribute("Score2") or 0)
	if state == "waiting" then
		mid.Text = Lang.t("m.training")
		timer.Text = ""
		local botAt = match:GetAttribute("BotAt")
		if type(botAt) == "number" then
			local left = math.max(0, math.ceil(botAt - Workspace:GetServerTimeNow()))
			status.Text = Lang.t("m.waiting_bot", left)
		else
			status.Text = Lang.t("m.waiting")
		end
		status.TextColor3 = Color3.new(1, 1, 1)
		return
	end
	mid.Text = Lang.t("m.round_gas", match:GetAttribute("Round") or 0, gasStage)
	local t = MatchHud.roundTime()
	local secs = math.floor(t)
	timer.Text = if state == "live" then ("%d:%02d"):format(secs // 60, secs % 60) else ""
	if warn then
		status.Text = Lang.t("m.gas_warn")
		status.TextColor3 = TOXIC
	else
		status.Text = ""
	end
end

-- Messages de resserrement du gaz (appelé par Gas).
function MatchHud.gasShrink(stage: number)
	MatchHud.centerMessage(Lang.t("m.gas_shrink"), 1.6, TOXIC, Lang.t("m.gas_shrink_sub", stage))
	Sfx.play("zone", -2)
end


return MatchHud
