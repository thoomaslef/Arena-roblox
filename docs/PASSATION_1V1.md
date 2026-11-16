# Cavale sur Roblox — passation : mode 1v1 « Règlement de comptes »

Ce document sert à démarrer une **nouvelle session Claude Code** sur le dépôt Roblox. Il résume le
jeu d'origine (Godot, dépôt `thoomaslef/Arena`) et donne tout ce qu'il faut pour recréer le mode
**1v1 « Règlement de comptes »** sur Roblox, avec les **valeurs exactes** du jeu Godot.

Si le dépôt `Arena` est aussi attaché à la session, le code de référence est là
(chemins indiqués à chaque section). Sinon, ce document suffit.

---

## 1. Le projet en bref

- **Cavale** : FPS d'arène rapide, inspiré de **ShootMania** (déplacements très mobiles, roquettes
  lentes et lisibles, le skill avant tout). Style cartoon / BD, low-poly, **pas de sang**.
- Univers : **Flics** (camp 0, bleu `#3B7AFF`) contre **Bandits** (camp 1, orange `#FF8A29`).
- Le créateur (francophone, **réponds en français**, ton simple et direct) veut :
  - du **skill** au cœur du gameplay (mêmes armes et mêmes règles de base des deux côtés) ;
  - monétisation libre : cosmétiques (skins de flic / bandit, effets d'élimination, emotes,
    passe de saison, serveurs privés) **et** avantages payants acceptés par le créateur
    (mise à jour du 16/11/2026 : « il peut être pay-to-win sur des fonctions payantes ») ;
  - avancer par étapes testables, avec des commits clairs (en français).
- Le jeu Godot a 6 modes (Règlement de comptes 1v1, Binômes 2v2, Évasion 3v3, Le Casse 5v5,
  Descente 5v5, Académie). **Sur Roblox, on commence par le 1v1 seul**, pour tester le public.

## 2. Objectif de cette session : une version test du 1v1

Livrable visé (dans l'ordre) :
1. Projet Roblox structuré avec **Rojo** (code Luau dans le dépôt GitHub, synchronisé dans Studio).
2. **Contrôleur de déplacement maison** (pas le Humanoid par défaut) : course, saut variable,
   micro-saut, plané, sprint, wall-jump, avec l'endurance — c'est **le cœur du ressenti**.
3. **Roquette** (projectile lent + explosion + poussée / rocket jump) et **Rail** sur les plateformes.
4. **Règles du mode** : 3 vies, manches, gaz qui se resserre, score 11 avec 2 d'écart.
5. Une **map** (voir §7), HUD minimal, sons simples.
6. Matchmaking simple : serveurs de 2 joueurs (file d'attente), puis bot si personne.

Le créateur a un PC pour **Roblox Studio** (Windows/Mac) : c'est lui qui lance Studio, teste et
publie. La session Claude écrit le code, la structure Rojo et les instructions pas à pas.

## 3. Règles du mode « Règlement de comptes » (1v1)

Référence Godot : `scripts/modes/joust.gd`.

| Règle | Valeur |
| --- | --- |
| Vies par manche | **3** (aucun soin, aucun bonus) |
| Victoire de la manche | l'adversaire perd ses 3 vies → **+1 point** |
| Victoire du match | **11 points** avec **2 points d'écart** |
| Égalité (les deux meurent en même temps) | la manche est **rejouée** (pas de point) |
| Début de manche | compte à rebours **3 s** : on peut viser, pas bouger ni tirer |
| Côtés | les deux spawns **alternent** à chaque manche |
| Remise à zéro à chaque manche | vies, roquettes, endurance, position, gaz |
| Fin de manche | pause **3 s** puis manche suivante |
| Compteur près du réticule | « **+1** » à chaque touche sur l'adversaire |

### Le gaz lacrymo (zone qui rétrécit)
- Cylindre centré sur l'objet `zone_center` de la map (sinon centre de la map).
- Rayon initial `r0` = demi-côté de la map − 1 m, et au moins (distance du spawn le plus loin + 4 m).
- Paliers (durée en s, rayon visé en fraction de `r0`) :
  `[5, 1.0], [15, 0.66], [8, 0.66], [15, 0.38], [8, 0.38], [15, 0.12]`
  → 5 s d'attente, puis resserrement / pause en alternance (66 s au total), minimum **4 m**.
- Interpolation **linéaire** pendant chaque palier.
- **Hors du gaz = mort immédiate** (cause affichée « Gaz lacrymo »).
- Bip d'alerte toutes les 0,5 s quand on est à moins de **4 m** du bord.
- Message à chaque resserrement : « LE GAZ LACRYMO SE RESSERRE » / « La police boucle le quartier · palier N / 3 ».
- Visuel : mur de gaz blanc-vert (`#B8FF2E` en teinte), sol hors zone teinté.

## 4. Déplacements (valeurs exactes)

Référence Godot : `scripts/player/fighter.gd` (`_physics_process`, `_jump`, `_try_walljump`).
Unités : mètres, secondes. Physique à **60 Hz**. Un seul bouton de **mobilité** (Espace / clic droit).

| Constante | Valeur | Rôle |
| --- | --- | --- |
| `RUN_SPEED` | 8,5 m/s | course normale |
| `SPRINT_SPEED` | 13,5 m/s | sprint |
| `WALK_SPEED` | 4,2 m/s | marche (Maj), pas silencieux |
| `GROUND_ACCEL` | 70 m/s² | accélération au sol |
| `GROUND_FRICTION` | 55 m/s² | freinage au sol sans input |
| `OVERSPEED_DECEL` | 11 m/s² | freinage doux au-delà de la vitesse max (on garde l'élan) |
| `AIR_ACCEL` | 15 m/s² | contrôle en l'air (vers max(RUN_SPEED, vitesse actuelle)) |
| `GRAVITY` | 22 m/s² | |
| `JUMP_MIN_VY` | 2,6 m/s | **micro-saut** (appui bref) |
| `JUMP_FULL_VY` | 7,6 m/s | **saut complet** (bouton tenu) : ~2,6 m de haut |
| `JUMP_BOOST_TIME` | 0,18 s | montée de 2,6 → 7,6 m/s (courbe k², gravité coupée pendant le boost) |
| `RISE_HOLD_GRAVITY` | ×0,72 | bouton tenu en montée : saut allongé |
| `GLIDE_GRAVITY` | ×0,5 | bouton tenu en chute : **plané** |
| `GLIDE_MAX_FALL` | 4,5 m/s | vitesse de chute max en plané |
| `WALLJUMP_PUSH` | 7,5 m/s | poussée hors du mur |
| `WALLJUMP_VY` | 7,0 m/s | |
| `PRESS_BUFFER` | 0,18 s | appui mémorisé avant l'atterrissage |
| `COYOTE` | 0,1 s | on peut encore sauter juste après avoir quitté le bord |
| Hauteur / rayon | 1,8 m / 0,4 m | capsule du joueur, yeux à **1,6 m** |
| Pente max | 50° | accroche au sol 0,35 m |

**Endurance** (barre 0 → 1) :
- saut −0,12 ; wall-jump −0,16 ; sprint −0,42/s ; plané −0,38/s ;
- régénération +0,33/s après **0,45 s** sans dépense.
- Sans endurance : pas de saut complet (micro-saut seulement), pas de sprint ni de plané.

**Logique du bouton de mobilité** :
- appui au sol → saut (micro si relâché tout de suite, complet si tenu) ;
- tenu en montée → saut allongé ; tenu en descente → plané ;
- **atterrir en tenant le bouton** avec une direction → **sprint** (tant qu'on tient et qu'il reste
  de l'endurance) ;
- appui en l'air contre un mur → **wall-jump** (délai 0,22 s ; on garde 75 % de la vitesse le long du mur).
- Hors des limites (y < −20) → mort.

Contrôles PC par défaut : ZQSD / WASD, souris, Espace ou clic droit = mobilité, clic gauche = tir,
Maj = marcher, Tab = scores. **Prévoir le tactile** (mobile majoritaire sur Roblox) : joystick,
bouton saut/mobilité, bouton tir, visée au glisser.

## 5. Armes du 1v1

Référence Godot : `scripts/weapons/weapons.gd`, `scripts/weapons/projectile.gd`, `scripts/match/arena.gd`.

L'arme dépend **du bloc sous les pieds** : partout la **Roquette** ; sur une plateforme **Rail**
(blocs « hauteur », néon cyan) on a le **Rail**.

### Roquette
| | Valeur |
| --- | --- |
| Charges | **5** (réglage du 1v1) |
| Recharge | **2,0 s par roquette** (une à la fois, en continu) |
| Cadence mini | 0,26 s entre deux tirs |
| Vitesse | **36 m/s**, ligne droite, sans gravité |
| Explosion | rayon **1,4 m**, **1 vie** retirée |
| Poussée (rocket jump) | rayon 3,4 m, force 11 m/s × (0,35 + 0,65 × proximité), dirigée du point d'explosion vers le joueur **+ 0,35 vers le haut** ; touche **tout le monde, tireur compris**, sans dégâts pour soi |
| Départ | 0,5 m devant les yeux, légèrement à droite et en bas ; vise le point sous le réticule |
| Collision | rayon entre deux positions successives (fiable à grande vitesse) |
| Durée de vie | 5 s |
| Dégâts | jamais sur soi ni sur un allié |

### Rail (plateformes Rail uniquement)
| | Valeur |
| --- | --- |
| Charges | 1, recharge **2,5 s** |
| Tir | instantané (hitscan), portée 220 m |
| Dégâts en 1v1 | **1 vie** |
| Spécial | **détruit une roquette en vol** si elle est sur la trajectoire (à moins de 0,55 m) |
| Sur la plateforme | le bouton de mobilité **zoome** (×0,45 du champ de vision) au lieu de sauter |

Nova et Katana sont désactivés en 1v1. Le **Canon Arc** (rayon continu à ramasser) existe dans le
jeu Godot mais **n'est pas nécessaire** pour la version test.

### Hitboxes
Tête, torse, jambes (capsules sur les os). En 1v1, toutes les zones retirent **1 vie** (les dégâts
par zone ne servent qu'aux armes à balles des modes 5v5).

## 6. HUD, sons et ressenti

- Vies : 3 pastilles. Charges de roquette : barre en 5 segments qui se remplit. Barre d'endurance.
- Score en haut (Flics à gauche, Bandits à droite), numéro de manche, chrono du gaz.
- Messages centraux : compte à rebours « 3 · 2 · 1 · GO », « MANCHE GAGNÉE / PERDUE », « ÉGALITÉ ».
- Marqueur de touche, son « hit », son « kill » plus fort.
- Fil des éliminations dans le vocabulaire du camp :
  Flics : « a serré », « a coffré », « a menotté », « a neutralisé », « a mis au trou », « a embarqué » ;
  Bandits : « a refroidi », « a planté », « a descendu », « a fumé », « a effacé », « a rayé de la carte » ;
  chute : « est tombé en service » (Flic), « s'est vautré » (Bandit).
- Début de manche : **sirène** (côté Flics) / **coup de sifflet** (côté Bandits).
- Tremblement de caméra léger sur les explosions proches.

## 7. Map de départ

Les maps 1v1 du jeu Godot sont des fichiers JSON dans `maps/` du dépôt `Arena` :
**Cratère** (21 × 21), **Piliers** (19 × 19), **Terrasses** (23 × 23), **Fosse** (21 × 21),
**Passerelles** (23 × 23). Pour commencer : **Cratère**.

Format (`scripts/core/map_data.gd`) :
- grille de cases de **2 m × 2 m**, paliers de **1 m** ;
- `"blocks"` : `{"type", "pos": [x, y, z], "rot": 0..3}` ; types utiles en 1v1 :
  `floor` (sol, 1 m), `wall` (mur 3 m), `wall_low` (muret 1 m), `ramp` / `stairs` (montent dans la
  direction `rot` : 0 = +z, 1 = +x, 2 = −z, 3 = −x), `height` (plateforme **Rail**, néon cyan),
  `jump_pad` (propulse à 17 m/s vers le haut), `accelerator` (24 m/s dans sa direction + 3,5 vers le
  haut), `glass` (vitre 3 m, bloque les tirs), `thin_wall` (cloison 30 cm) ;
- position monde d'une case : `x*2 + 1`, `y*1`, `z*2 + 1` (le **dessus** d'un bloc de sol posé en
  `y = 0` est à **1 m**) ;
- `"objects"` : `spawn_joust` (×2, `rot` = orientation de départ), `zone_center` (centre du gaz),
  `weapon_arc` (facultatif).

Plan conseillé : un **script d'import** (Luau dans Studio, ou outil côté dépôt) qui lit ce JSON et
construit les `Part` (un bloc = une Part ancrée), plutôt que de tout refaire à la main. Les modèles
importés (packs **Quaternius** et **Kenney**, CC0) sont dans `assets/` d'`Arena` en **GLB** :
Roblox importe le GLB (environ 20 000 triangles max par mesh, les packs low-poly passent).

## 8. Architecture conseillée sur Roblox

- **Rojo** : `src/server`, `src/client`, `src/shared` → `ServerScriptService`, `StarterPlayerScripts`,
  `ReplicatedStorage`. Constantes (tableaux §3 à §5) dans un module `shared/Config.lua` unique.
- **Déplacement côté client** (réactivité, aucun délai) avec un **contrôleur maison**
  (désactiver le contrôle par défaut, piloter la vitesse soi-même) ; le serveur vérifie la
  vraisemblance (vitesse max, téléportations) contre la triche.
- **Tirs** : le client montre le tir tout de suite ; le **serveur valide et applique** les dégâts
  (roquettes simulées sur le serveur, Rail vérifié par raycast serveur), via `RemoteEvent`.
- **Mode de jeu sur le serveur** : machine à états (attente → compte à rebours → en cours → fin de
  manche → fin de match), gaz calculé sur le serveur et répliqué (rayon + chrono).
- Serveurs de **2 joueurs** ; si un joueur est seul trop longtemps : un **bot** (IA simple : se
  rapprocher, esquiver par sauts, tirer avec anticipation).
- Monétisation **plus tard** (cosmétiques et éventuellement avantages payants, voir §1).

## 9. Étapes proposées (une à la fois, chacune testée par le créateur dans Studio)

1. Installation : Roblox Studio, Rojo (plugin Studio + outil), structure du dépôt, « hello world ».
2. Contrôleur de déplacement + caméra FPS + endurance (map de test plate avec murs et rampe).
3. Roquette : tir, explosion, poussée, rocket jump.
4. Import de la map Cratère depuis le JSON.
5. Règles du 1v1 : vies, manches, score, gaz, HUD.
6. Plateformes Rail + Rail (et destruction des roquettes en vol).
7. Matchmaking 2 joueurs, bot de remplacement, publication en test.

## 10. À savoir sur Roblox (recherche du 15/11/2026, à revérifier)

- Serveurs gratuits ; on gagne des Robux (achats en jeu, Creator Rewards, pubs vidéo récompensées)
  convertis via le **DevEx** (~0,0038 $ / Robux, minimum 30 000 Robux, 13 ans et plus, identité vérifiée).
- Catégories de contenu (Minimal, Mild, Moderate, Restricted) : viser **Mild / Moderate**
  (cartoon, pas de sang) pour rester accessible aux comptes jeunes.
- Concurrence forte chez les shooters (RIVALS en tête) : miser sur l'originalité du gameplay
  (mobilité ShootMania, roquettes, gaz) et la lisibilité.
