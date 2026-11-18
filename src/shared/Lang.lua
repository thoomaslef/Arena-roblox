-- Textes du jeu en français et en anglais.
--   Lang.t("menu.play")            → "JOUER" / "PLAY"
--   Lang.t("m.champ", nom, 11, 7)   → texte avec des %s / %d remplis
--   Lang.bind(label, "menu.play")  → le label suit les changements de langue
-- Langue : réglage du joueur ("auto" par défaut = celle de son compte Roblox ; français si
-- le compte est en français, anglais sinon). Le serveur l'utilise aussi (message d'expulsion).

local Lang = {}

local STRINGS = {}

STRINGS.fr = {
	-- Camps et maps
	["team.0"] = "Flics",
	["team.1"] = "Bandits",
	["map.cratere"] = "Cratère",
	["map.piliers"] = "Piliers",
	["map.terrasses"] = "Terrasses",
	["map.fosse"] = "Fosse",
	["map.passerelles"] = "Passerelles",
	["map.tutorial"] = "Entraînement",

	-- Écran d'accueil
	["menu.subtitle"] = "RÈGLEMENT DE COMPTES  ·  1 CONTRE 1",
	["menu.pitch"] = "Roquettes, rocket jumps et gaz lacrymo qui se resserre. 3 vies par manche, le dernier debout marque le point. Premier à 11 points (2 d'écart) !",
	["menu.cops"] = "Sirène au départ. On serre, on coffre, on menotte : la loi, c'est vous.",
	["menu.robbers"] = "Coup de sifflet au départ. On fume, on efface, on file : jamais pris.",
	["menu.play"] = "JOUER",
	["menu.tutorial"] = "TUTORIEL",
	["menu.settings"] = "RÉGLAGES",
	["menu.hint"] = "Nouveau ? Fais le tutoriel (2 minutes) : le saut, le plané et le sprint se font avec un seul bouton.",
	["menu.level"] = "NIVEAU %d",
	["menu.xp"] = "%d / %d XP",
	["menu.ranked"] = "CLASSÉ  ·  SAISON %d",
	["menu.rating"] = "%s  ·  %d points",
	["menu.unranked"] = "Non classé : joue encore %d match(s) contre un joueur",
	["menu.leaderboard"] = "CLASSEMENT MONDIAL",
	["menu.lb_empty"] = "Pas encore de classement cette saison.",
	["menu.stats"] = "Victoires %d  ·  Matchs %d  ·  Précision %d %%",

	-- Rangs
	["rank.bronze"] = "Bronze",
	["rank.silver"] = "Argent",
	["rank.gold"] = "Or",
	["rank.platinum"] = "Platine",
	["rank.diamond"] = "Diamant",
	["rank.champion"] = "Champion",

	-- Tutoriel
	["tuto.step"] = "ÉTAPE %d / %d",
	["tuto.done_step"] = "TUTORIEL TERMINÉ",
	["tuto.done_title"] = "TU ES PRÊT !",
	["tuto.play"] = "JOUER",
	["tuto.menu"] = "MENU",
	["tuto.skip"] = "Passer ›",
	["tuto.joystick"] = "le joystick",
	["tuto.btn_jump"] = "le bouton SAUT",
	["tuto.btn_fire"] = "le bouton TIR",
	["tuto.move.title"] = "SE DÉPLACER",
	["tuto.move.text"] = "Déplace-toi avec %s, %s, %s, %s. Vise avec la souris.",
	["tuto.move.touch"] = "Pose le pouce gauche à gauche de l'écran : le joystick apparaît. Glisse à droite pour viser.",
	["tuto.micro.title"] = "MICRO-SAUT",
	["tuto.micro.text"] = "Appuie BRIÈVEMENT sur %s : petit saut rapide, idéal pour esquiver.",
	["tuto.full.title"] = "GRAND SAUT",
	["tuto.full.text"] = "Garde %s APPUYÉ pour sauter haut (environ 2,6 m).",
	["tuto.glide.title"] = "PLANÉ",
	["tuto.glide.text"] = "Monte sur le pad bleu, puis garde %s appuyé en retombant : tu planes. La barre jaune, c'est ton endurance.",
	["tuto.sprint.title"] = "SPRINT",
	["tuto.sprint.text"] = "Saute et atterris en GARDANT %s appuyé avec une direction : tu sprintes. (La bande jaune au sol fait sprinter direct.)",
	["tuto.wall.title"] = "WALL-JUMP",
	["tuto.wall.text"] = "Saute vers un mur, et appuie sur %s quand tu es contre lui : tu rebondis.",
	["tuto.fire.title"] = "ROQUETTE",
	["tuto.fire.text"] = "Tire avec %s. 5 roquettes, une revient toutes les 2 s. Une touche = 1 vie en moins pour l'adversaire.",
	["tuto.rj.title"] = "ROCKET JUMP",
	["tuto.rj.text"] = "Saute et tire à tes pieds : l'explosion te propulse (sans te blesser). Essaie de monter le plus haut possible !",
	["tuto.rail.title"] = "RAIL",
	["tuto.rail.text"] = "Monte sur la plateforme cyan : ton arme devient le Rail (tir instantané). Garde %s pour zoomer.",

	-- Réglages
	["set.title"] = "RÉGLAGES",
	["set.tab_controls"] = "COMMANDES",
	["set.tab_game"] = "JEU",
	["set.hint"] = "Clique sur une case puis appuie sur une touche · Échap : annuler · Retour arrière : effacer",
	["set.press"] = "…appuie",
	["set.sens"] = "Sensibilité souris",
	["set.sens_touch"] = "Sensibilité tactile",
	["set.sens_pad"] = "Sensibilité manette",
	["set.volume"] = "Volume des sons",
	["set.fov"] = "Champ de vision",
	["set.crosshair"] = "Réticule",
	["set.crosshair_color"] = "Couleur du réticule",
	["set.language"] = "Langue",
	["set.reset"] = "Touches par défaut",
	["set.menu"] = "Menu principal",
	["set.close"] = "Fermer (P)",
	["set.nosave"] = "Réglages non sauvegardés (DataStore indisponible dans Studio : voir README)",
	["lang.auto"] = "Auto",
	["lang.fr"] = "Français",
	["lang.en"] = "English",
	["ch.cross"] = "Croix",
	["ch.dot"] = "Point",
	["ch.circle"] = "Cercle",
	["ch.crossdot"] = "Croix + point",
	["col.white"] = "Blanc",
	["col.green"] = "Vert",
	["col.yellow"] = "Jaune",
	["col.cyan"] = "Cyan",
	["col.pink"] = "Rose",
	["act.forward"] = "Avancer",
	["act.back"] = "Reculer",
	["act.left"] = "Gauche",
	["act.right"] = "Droite",
	["act.mobility"] = "Mobilité (saut, plané, sprint)",
	["act.fire"] = "Tirer",
	["act.walk"] = "Marcher",
	["key.MouseButton1"] = "Clic gauche",
	["key.MouseButton2"] = "Clic droit",
	["key.MouseButton3"] = "Clic molette",
	["key.Space"] = "Espace",
	["key.LeftShift"] = "Maj gauche",
	["key.RightShift"] = "Maj droite",
	["key.LeftControl"] = "Ctrl gauche",
	["key.RightControl"] = "Ctrl droite",
	["key.LeftAlt"] = "Alt gauche",
	["key.Up"] = "Flèche haut",
	["key.Down"] = "Flèche bas",
	["key.Left"] = "Flèche gauche",
	["key.Right"] = "Flèche droite",

	-- HUD et boutons tactiles
	["hud.rocket"] = "ROQUETTE",
	["hud.rail"] = "RAIL",
	["hud.eliminated"] = "ÉLIMINÉ !",
	["hud.lastlife"] = "DERNIÈRE VIE !",
	["touch.fire"] = "TIR",
	["touch.jump"] = "SAUT",
	["touch.zoom"] = "ZOOM",

	-- Match
	["m.tie"] = "ÉGALITÉ",
	["m.tie_sub"] = "La manche est rejouée",
	["m.round_team"] = "MANCHE : %s",
	["m.round_won"] = "MANCHE GAGNÉE",
	["m.round_lost"] = "MANCHE PERDUE",
	["m.duel_over"] = "FIN DU DUEL",
	["m.victory"] = "VICTOIRE",
	["m.defeat"] = "DÉFAITE",
	["m.champ"] = "%s remporte le duel  %d – %d",
	["m.training"] = "ENTRAÎNEMENT",
	["m.waiting"] = "En attente d'un adversaire…",
	["m.waiting_bot"] = "En attente d'un adversaire… un bot arrive dans %d s",
	["m.round_gas"] = "Manche %d  ·  Gaz %d/3",
	["m.gas_warn"] = "GAZ LACRYMO — revenez vers le centre !",
	["m.gas_shrink"] = "LE GAZ LACRYMO SE RESSERRE",
	["m.gas_shrink_sub"] = "La police boucle le quartier  ·  palier %d / 3",
	["m.countdown_sub"] = "Manche %d  ·  %d – %d  ·  %s",
	["m.go"] = "GO",
	["m.detonated"] = "Roquette détruite en vol !",
	["info.opponent_left"] = "ADVERSAIRE PARTI",
	["info.opponent_left_sub"] = "Victoire par forfait · en attente d'un adversaire",
	["info.opponent_joining"] = "UN ADVERSAIRE ARRIVE",
	["info.opponent_joining_sub"] = "Le bot laisse sa place · nouveau match",

	-- Fil des éliminations
	["kill.format"] = "%s %s %s",
	["kill.gas"] = "%s — Gaz lacrymo",

	-- Récompenses de fin de match
	["rw.xp"] = "+%d XP",
	["rw.levelup"] = "NIVEAU %d !",
	["rw.rating"] = "%+d points classés  ·  %s",
	["rw.vs_bot"] = "Contre le bot : non classé, XP réduite",

	-- Défis du jour
	["dc.title"] = "DÉFIS DU JOUR",
	["dc.reset"] = "Nouveaux défis dans %dh%02d",
	["dc.win_rounds"] = "Gagne %d manches",
	["dc.hits"] = "Touche l'adversaire %d fois",
	["dc.rail_hits"] = "Touche %d fois au Rail",
	["dc.detonate"] = "Détruis %d roquette(s) en vol au Rail",
	["dc.airshot"] = "Touche %d fois un adversaire en l'air",
	["dc.win_match"] = "Gagne %d match(s)",
	["dc.play_matches"] = "Joue %d matchs",
	["dc.ranked"] = "Joue %d match(s) contre un joueur",
	["dc.flawless"] = "Gagne %d manche(s) sans perdre une vie",
	["dc.kills"] = "Élimine l'adversaire %d fois",
	["dc.done"] = "DÉFI RÉUSSI !",
	["dc.done_sub"] = "%s  ·  +%d XP",

	-- Statistiques
	["st.title"] = "STATISTIQUES",
	["st.matches"] = "Matchs joués",
	["st.wins"] = "Victoires",
	["st.winrate"] = "Taux de victoire",
	["st.rounds"] = "Manches gagnées",
	["st.accuracy"] = "Précision",
	["st.hits"] = "Touches",
	["st.kills"] = "Éliminations",
	["st.airshots"] = "Touches en l'air",
	["st.detonations"] = "Roquettes détruites",
	["st.streak"] = "Meilleure série de victoires",
	["st.peak"] = "Meilleur classement (saison)",
	["rw.stats"] = "Précision %d %%  ·  Touches %d  ·  Éliminations %d",

	-- Onglets de l'accueil, amis, salons privés
	["menu.tab_board"] = "CLASSEMENT",
	["menu.tab_daily"] = "DÉFIS",
	["menu.tab_stats"] = "STATS",
	["menu.invite"] = "INVITER UN AMI",
	["menu.room"] = "SALON PRIVÉ",
	["room.title"] = "SALON PRIVÉ",
	["room.text"] = "Crée un salon et donne le code à un ami, ou entre le code qu'il t'a donné. Les matchs en salon privé ne sont pas classés.",
	["room.create"] = "CRÉER UN SALON",
	["room.join"] = "REJOINDRE",
	["room.code_hint"] = "CODE",
	["room.close"] = "Fermer",
	["room.wait"] = "Téléportation…",
	["room.err_studio"] = "Les salons privés ne marchent que dans le jeu publié (pas dans Studio).",
	["room.err_code"] = "Code inconnu ou expiré.",
	["room.err_fail"] = "Impossible de créer le salon, réessaie dans un instant.",
	["room.banner"] = "SALON PRIVÉ  ·  CODE : %s  ·  non classé",
	["room.banner_vip"] = "SERVEUR PRIVÉ  ·  non classé",
	["invite.unavailable"] = "Invitation impossible ici (Studio ou salon privé : donne plutôt le code).",

	-- Vote de map
	["vote.title"] = "VOTE POUR LA PROCHAINE MAP",
	["vote.hint"] = "Clique ou appuie sur 1, 2, 3",
	["vote.count"] = "%d vote(s)",

	-- Serveur
	["kick.move"] = "Mouvement anormal détecté (anti-triche). Si c'est une erreur, relance le jeu.",
}

STRINGS.en = {
	["team.0"] = "Cops",
	["team.1"] = "Robbers",
	["map.cratere"] = "Crater",
	["map.piliers"] = "Pillars",
	["map.terrasses"] = "Terraces",
	["map.fosse"] = "The Pit",
	["map.passerelles"] = "Catwalks",
	["map.tutorial"] = "Training",

	["menu.subtitle"] = "SHOWDOWN  ·  1 VS 1",
	["menu.pitch"] = "Rockets, rocket jumps and tear gas closing in. 3 lives per round, last one standing scores. First to 11 points (win by 2)!",
	["menu.cops"] = "Siren at the start. Cuff 'em, book 'em, lock 'em up: you are the law.",
	["menu.robbers"] = "Whistle at the start. Smoke 'em, wipe 'em, run: never caught.",
	["menu.play"] = "PLAY",
	["menu.tutorial"] = "TUTORIAL",
	["menu.settings"] = "SETTINGS",
	["menu.hint"] = "New here? Try the tutorial (2 minutes): jump, glide and sprint all use a single button.",
	["menu.level"] = "LEVEL %d",
	["menu.xp"] = "%d / %d XP",
	["menu.ranked"] = "RANKED  ·  SEASON %d",
	["menu.rating"] = "%s  ·  %d points",
	["menu.unranked"] = "Unranked: play %d more match(es) against a player",
	["menu.leaderboard"] = "WORLD LEADERBOARD",
	["menu.lb_empty"] = "No rankings yet this season.",
	["menu.stats"] = "Wins %d  ·  Matches %d  ·  Accuracy %d %%",

	["rank.bronze"] = "Bronze",
	["rank.silver"] = "Silver",
	["rank.gold"] = "Gold",
	["rank.platinum"] = "Platinum",
	["rank.diamond"] = "Diamond",
	["rank.champion"] = "Champion",

	["tuto.step"] = "STEP %d / %d",
	["tuto.done_step"] = "TUTORIAL COMPLETE",
	["tuto.done_title"] = "YOU'RE READY!",
	["tuto.play"] = "PLAY",
	["tuto.menu"] = "MENU",
	["tuto.skip"] = "Skip ›",
	["tuto.joystick"] = "the joystick",
	["tuto.btn_jump"] = "the JUMP button",
	["tuto.btn_fire"] = "the FIRE button",
	["tuto.move.title"] = "MOVING",
	["tuto.move.text"] = "Move with %s, %s, %s, %s. Aim with the mouse.",
	["tuto.move.touch"] = "Put your left thumb on the left of the screen: the joystick appears. Swipe on the right to aim.",
	["tuto.micro.title"] = "MICRO JUMP",
	["tuto.micro.text"] = "TAP %s: a quick little hop, great for dodging.",
	["tuto.full.title"] = "HIGH JUMP",
	["tuto.full.text"] = "HOLD %s to jump high (about 2.6 m).",
	["tuto.glide.title"] = "GLIDE",
	["tuto.glide.text"] = "Step on the blue pad, then keep holding %s while falling: you glide. The yellow bar is your stamina.",
	["tuto.sprint.title"] = "SPRINT",
	["tuto.sprint.text"] = "Jump and land while HOLDING %s and a direction: you sprint. (The yellow strip on the floor makes you sprint right away.)",
	["tuto.wall.title"] = "WALL JUMP",
	["tuto.wall.text"] = "Jump at a wall and press %s while touching it: you bounce off.",
	["tuto.fire.title"] = "ROCKET",
	["tuto.fire.text"] = "Shoot with %s. 5 rockets, one comes back every 2 s. One hit = one life lost for your opponent.",
	["tuto.rj.title"] = "ROCKET JUMP",
	["tuto.rj.text"] = "Jump and shoot at your feet: the blast launches you (no damage to yourself). Try to go as high as you can!",
	["tuto.rail.title"] = "RAIL",
	["tuto.rail.text"] = "Climb onto the cyan platform: your weapon becomes the Rail (instant shot). Hold %s to zoom.",

	["set.title"] = "SETTINGS",
	["set.tab_controls"] = "CONTROLS",
	["set.tab_game"] = "GAME",
	["set.hint"] = "Click a box then press a key · Esc: cancel · Backspace: clear",
	["set.press"] = "…press",
	["set.sens"] = "Mouse sensitivity",
	["set.sens_touch"] = "Touch sensitivity",
	["set.sens_pad"] = "Gamepad sensitivity",
	["set.volume"] = "Sound volume",
	["set.fov"] = "Field of view",
	["set.crosshair"] = "Crosshair",
	["set.crosshair_color"] = "Crosshair color",
	["set.language"] = "Language",
	["set.reset"] = "Default keys",
	["set.menu"] = "Main menu",
	["set.close"] = "Close (P)",
	["set.nosave"] = "Settings not saved (DataStore unavailable in Studio: see README)",
	["lang.auto"] = "Auto",
	["lang.fr"] = "Français",
	["lang.en"] = "English",
	["ch.cross"] = "Cross",
	["ch.dot"] = "Dot",
	["ch.circle"] = "Circle",
	["ch.crossdot"] = "Cross + dot",
	["col.white"] = "White",
	["col.green"] = "Green",
	["col.yellow"] = "Yellow",
	["col.cyan"] = "Cyan",
	["col.pink"] = "Pink",
	["act.forward"] = "Forward",
	["act.back"] = "Back",
	["act.left"] = "Left",
	["act.right"] = "Right",
	["act.mobility"] = "Mobility (jump, glide, sprint)",
	["act.fire"] = "Fire",
	["act.walk"] = "Walk",
	["key.MouseButton1"] = "Left click",
	["key.MouseButton2"] = "Right click",
	["key.MouseButton3"] = "Middle click",
	["key.Space"] = "Space",
	["key.LeftShift"] = "Left Shift",
	["key.RightShift"] = "Right Shift",
	["key.LeftControl"] = "Left Ctrl",
	["key.RightControl"] = "Right Ctrl",
	["key.LeftAlt"] = "Left Alt",
	["key.Up"] = "Up arrow",
	["key.Down"] = "Down arrow",
	["key.Left"] = "Left arrow",
	["key.Right"] = "Right arrow",

	["hud.rocket"] = "ROCKET",
	["hud.rail"] = "RAIL",
	["hud.eliminated"] = "ELIMINATED!",
	["hud.lastlife"] = "LAST LIFE!",
	["touch.fire"] = "FIRE",
	["touch.jump"] = "JUMP",
	["touch.zoom"] = "ZOOM",

	["m.tie"] = "DRAW",
	["m.tie_sub"] = "The round is replayed",
	["m.round_team"] = "ROUND: %s",
	["m.round_won"] = "ROUND WON",
	["m.round_lost"] = "ROUND LOST",
	["m.duel_over"] = "DUEL OVER",
	["m.victory"] = "VICTORY",
	["m.defeat"] = "DEFEAT",
	["m.champ"] = "%s wins the duel  %d – %d",
	["m.training"] = "PRACTICE",
	["m.waiting"] = "Waiting for an opponent…",
	["m.waiting_bot"] = "Waiting for an opponent… a bot joins in %d s",
	["m.round_gas"] = "Round %d  ·  Gas %d/3",
	["m.gas_warn"] = "TEAR GAS — get back to the center!",
	["m.gas_shrink"] = "THE TEAR GAS IS CLOSING IN",
	["m.gas_shrink_sub"] = "Police are sealing off the block  ·  stage %d / 3",
	["m.countdown_sub"] = "Round %d  ·  %d – %d  ·  %s",
	["m.go"] = "GO",
	["m.detonated"] = "Rocket destroyed mid-air!",
	["info.opponent_left"] = "OPPONENT LEFT",
	["info.opponent_left_sub"] = "Win by forfeit · waiting for an opponent",
	["info.opponent_joining"] = "AN OPPONENT IS JOINING",
	["info.opponent_joining_sub"] = "The bot steps aside · new match",

	["kill.format"] = "%s %s %s",
	["kill.gas"] = "%s — Tear gas",

	["rw.xp"] = "+%d XP",
	["rw.levelup"] = "LEVEL %d!",
	["rw.rating"] = "%+d ranked points  ·  %s",
	["rw.vs_bot"] = "Vs bot: unranked, reduced XP",

	["dc.title"] = "DAILY CHALLENGES",
	["dc.reset"] = "New challenges in %dh%02d",
	["dc.win_rounds"] = "Win %d rounds",
	["dc.hits"] = "Hit your opponent %d times",
	["dc.rail_hits"] = "Land %d Rail hits",
	["dc.detonate"] = "Destroy %d rocket(s) mid-air with the Rail",
	["dc.airshot"] = "Hit an airborne opponent %d times",
	["dc.win_match"] = "Win %d match(es)",
	["dc.play_matches"] = "Play %d matches",
	["dc.ranked"] = "Play %d match(es) against a player",
	["dc.flawless"] = "Win %d round(s) without losing a life",
	["dc.kills"] = "Eliminate your opponent %d times",
	["dc.done"] = "CHALLENGE COMPLETE!",
	["dc.done_sub"] = "%s  ·  +%d XP",

	["st.title"] = "STATISTICS",
	["st.matches"] = "Matches played",
	["st.wins"] = "Wins",
	["st.winrate"] = "Win rate",
	["st.rounds"] = "Rounds won",
	["st.accuracy"] = "Accuracy",
	["st.hits"] = "Hits",
	["st.kills"] = "Eliminations",
	["st.airshots"] = "Air shots",
	["st.detonations"] = "Rockets destroyed",
	["st.streak"] = "Best win streak",
	["st.peak"] = "Peak rating (season)",
	["rw.stats"] = "Accuracy %d %%  ·  Hits %d  ·  Eliminations %d",

	["menu.tab_board"] = "LEADERBOARD",
	["menu.tab_daily"] = "CHALLENGES",
	["menu.tab_stats"] = "STATS",
	["menu.invite"] = "INVITE A FRIEND",
	["menu.room"] = "PRIVATE ROOM",
	["room.title"] = "PRIVATE ROOM",
	["room.text"] = "Create a room and give the code to a friend, or enter the code they gave you. Private room matches are unranked.",
	["room.create"] = "CREATE A ROOM",
	["room.join"] = "JOIN",
	["room.code_hint"] = "CODE",
	["room.close"] = "Close",
	["room.wait"] = "Teleporting…",
	["room.err_studio"] = "Private rooms only work in the published game (not in Studio).",
	["room.err_code"] = "Unknown or expired code.",
	["room.err_fail"] = "Couldn't create the room, try again in a moment.",
	["room.banner"] = "PRIVATE ROOM  ·  CODE: %s  ·  unranked",
	["room.banner_vip"] = "PRIVATE SERVER  ·  unranked",
	["invite.unavailable"] = "Can't invite from here (Studio or private room: share the code instead).",

	["vote.title"] = "VOTE FOR THE NEXT MAP",
	["vote.hint"] = "Click or press 1, 2, 3",
	["vote.count"] = "%d vote(s)",

	["kick.move"] = "Abnormal movement detected (anti-cheat). If this is a mistake, rejoin the game.",
}

-- Fil des éliminations, dans le vocabulaire du camp du tireur.
local KILL_VERBS = {
	fr = {
		[0] = { "a serré", "a coffré", "a menotté", "a neutralisé", "a mis au trou", "a embarqué" },
		[1] = { "a refroidi", "a planté", "a descendu", "a fumé", "a effacé", "a rayé de la carte" },
	},
	en = {
		[0] = { "cuffed", "busted", "booked", "took down", "locked up", "hauled in" },
		[1] = { "iced", "dropped", "smoked", "took out", "wiped out", "erased" },
	},
}
local FALL_TEXT = {
	fr = { [0] = "%s est tombé en service", [1] = "%s s'est vautré" },
	en = { [0] = "%s fell in the line of duty", [1] = "%s ate dirt" },
}
Lang.VERB_COUNT = 6

Lang.LANGUAGES = { "auto", "fr", "en" }
Lang.current = "fr"
Lang.preference = "auto"

local changed = Instance.new("BindableEvent")
Lang.changed = changed.Event

-- Langue d'un code de compte Roblox ("fr-fr", "en-us"…).
function Lang.fromLocale(localeId: string?): string
	if type(localeId) == "string" and localeId:sub(1, 2):lower() == "fr" then
		return "fr"
	end
	return "en"
end

local function detect(): string
	local ok, players = pcall(function()
		return game:GetService("Players")
	end)
	local lp = ok and players.LocalPlayer
	if lp then
		return Lang.fromLocale(lp.LocaleId)
	end
	return "fr"
end

-- pref : "auto", "fr" ou "en".
function Lang.set(pref: string)
	if pref ~= "fr" and pref ~= "en" then
		pref = "auto"
	end
	Lang.preference = pref
	local lang = if pref == "auto" then detect() else pref
	if lang ~= Lang.current then
		Lang.current = lang
		changed:Fire(lang)
	end
end

-- Texte d'une clé dans la langue actuelle (ou `lang`), avec des valeurs à insérer.
function Lang.tl(lang: string, key: string, ...): string
	local s = (STRINGS[lang] and STRINGS[lang][key]) or STRINGS.fr[key] or key
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return if ok then out else s
	end
	return s
end

function Lang.has(key: string): boolean
	return STRINGS[Lang.current][key] ~= nil or STRINGS.fr[key] ~= nil
end

function Lang.t(key: string, ...): string
	return Lang.tl(Lang.current, key, ...)
end

-- Texte d'élimination : killer et victim sont des noms ; cause "rocket" / "fall" / "gas".
function Lang.killText(cause: string, killerName: string?, victimName: string, killerTeam: number?, verbIndex: number?, victimTeam: number?): string
	local lang = Lang.current
	if cause == "fall" then
		return FALL_TEXT[lang][victimTeam or 0]:format(victimName)
	elseif cause == "gas" or not killerName then
		return Lang.t("kill.gas", victimName)
	end
	local verbs = KILL_VERBS[lang][killerTeam or 0]
	local verb = verbs[math.clamp(verbIndex or 1, 1, #verbs)]
	return Lang.t("kill.format", killerName, verb, victimName)
end

function Lang.teamName(team: number?): string
	return Lang.t("team." .. tostring(team or 0))
end

function Lang.mapName(key: string?): string
	if not key or key == "" then
		return ""
	end
	return Lang.t("map." .. key)
end

-- Garde un TextLabel / TextButton à jour quand la langue change.
local bound = setmetatable({}, { __mode = "k" })
function Lang.bind(obj: Instance, key: string, ...)
	local args = table.pack(...)
	bound[obj] = { key = key, args = args }
	;(obj :: any).Text = Lang.t(key, table.unpack(args, 1, args.n))
end

changed.Event:Connect(function()
	for obj, b in bound do
		if obj.Parent then
			;(obj :: any).Text = Lang.t(b.key, table.unpack(b.args, 1, b.args.n))
		end
	end
end)

Lang.set("auto")

return Lang
