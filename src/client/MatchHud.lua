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
rewardsRemote.OnClientEvent:Connect(function(r)
	if type(r) ~= "table" then
		return
	end
	local lines = { Lang.t("rw.xp", r.xp or 0) }
	if r.levelUp then
		table.insert(lines, Lang.t("rw.levelup", r.level or 1))
	end
	if r.vsBot then
		table.insert(lines, Lang.t("rw.vs_bot"))
	elseif type(r.ratingDelta) == "number" then
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

-- Mise à jour à chaque image.
function MatchHud.update(gasStage: number, warn: boolean)
	-- Rien du match à l'écran dans le menu ou le tutoriel.
	gui.Enabled = player:GetAttribute("Mode") == "play"
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
