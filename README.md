# Cavale — version Roblox (mode 1v1 « Règlement de comptes »)

FPS d'arène inspiré de ShootMania : déplacements très mobiles, roquettes lentes, skill.
Portage du jeu Godot (`thoomaslef/Arena`). Le cahier des charges complet est dans
[`docs/PASSATION_1V1.md`](docs/PASSATION_1V1.md).

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Projet Rojo, structure du dépôt | ✅ |
| 2 | Contrôleur de déplacement + caméra FPS + endurance | ✅ à tester |
| 3 | Roquette, explosion, poussée, rocket jump | ✅ à tester |
| 4 | Import des maps Godot (Cratère par défaut) | ✅ à tester |
| 5 | Règles du 1v1 : vies, manches, score, gaz, HUD | ✅ à tester |
| 6 | Plateformes Rail + Rail (et destruction des roquettes en vol) | ✅ à tester |
| 7 | Serveurs de 2 joueurs, bot de remplacement, publication | ✅ à tester |

## Organisation

```
default.project.json      → dit à Rojo où va chaque dossier dans Studio
src/shared/  → ReplicatedStorage.Shared   (code commun client + serveur)
  Config.lua                 toutes les constantes (en mètres / secondes)
  MapBuilder.lua             construit une map JSON Godot en Parts
  CharacterRig.lua           prépare l'avatar (cylindre de collision, groupes)
  Movement.lua               contrôleur de déplacement maison (portage de fighter.gd),
                             utilisé par les joueurs (client) ET par le bot (serveur)
  Rocket.lua                 calculs de la roquette (départ, explosion, poussée)
  Rail.lua                   calculs du Rail (canon, roquette sur la trajectoire)
  JoustRules.lua             règles du 1v1 partagées (rayon du gaz, victoire, fil des éliminations)
  Maps/*.json                les 5 maps 1v1 du jeu Godot
src/server/  → ServerScriptService.Server
  Main.server.lua            construit la map, fait apparaître les joueurs
  Combat.lua                 roquettes côté serveur (validation, explosion, dégâts)
  Joust.lua                  mode 1v1 : manches, score, gaz, éliminations, arrivée du bot
  Bot.lua                    bot de remplacement (portage de bot_brain.gd)
src/client/  → StarterPlayer.StarterPlayerScripts.Client
  Main.client.lua            boucle client
  FpsCamera.lua              caméra FPS
  Input.lua                  clavier / souris / manette / tactile
  Hud.lua                    réticule, endurance, roquettes, vies, touches
  Weapons.lua                tir de roquette (prédiction côté client)
  Fx.lua                     explosions, sons, roquettes visibles
  MatchHud.lua               score, manche, chrono, messages, fil des éliminations
  Gas.lua                    mur de gaz lacrymo, bip près du bord
  CharacterAnimator.lua      animations des autres personnages (joueur adverse, bot)
  Viewmodel.lua              bras et arme en main à la première personne
  WeaponModels.lua           modèles low-poly du lance-roquettes et du Rail (vue FPS et 3e personne)
```

Échelle : **1 m = 3 studs** (un joueur de 1,8 m ≈ un avatar Roblox).

## Installation (une seule fois)

1. **Roblox Studio** : https://create.roblox.com → « Start Creating » → installe Studio.
2. **Rojo, l'outil** (synchronise les fichiers du dépôt vers Studio). Le plus simple :
   - installe **VS Code** (https://code.visualstudio.com) ;
   - dans VS Code, onglet Extensions, installe **« Rojo »** (éditeur : evaera) ;
   - ouvre le dossier du dépôt dans VS Code. L'extension propose d'installer Rojo : accepte.
   *(Autre méthode : installer [Rokit](https://github.com/rojo-rbx/rokit), puis `rokit install`
   dans le dossier du dépôt — la version est fixée dans `rokit.toml`.)*
3. **Rojo, le plugin Studio** : dans VS Code, palette de commandes (Ctrl+Maj+P) →
   « Rojo: Install Roblox Studio plugin ». Redémarre Studio : un onglet / bouton **Rojo**
   apparaît dans la barre **Plugins**.

## Lancer le jeu dans Studio

1. Récupère le dépôt sur ton PC (GitHub Desktop ou `git clone`), branche
   `claude/awesome-newton-5419v3`.
2. Dans VS Code, palette → **« Rojo: Open menu »** → clique sur `default.project.json`
   (▶ Start). Rojo écoute sur le port 34872.
3. Dans Studio : **New → Baseplate** (une place vide).
4. Onglet **Plugins → Rojo → Connect**. Les dossiers `Shared`, `Server` et `Client`
   apparaissent dans ReplicatedStorage, ServerScriptService et StarterPlayerScripts.
5. Bouton **Play** (F5). La map Cratère se construit, tu apparais sur un spawn.
6. Pour tester à deux : onglet **Test → Clients and Servers → 2 Players → Start**.

Chaque fois que tu modifies un fichier (ou que tu récupères un nouveau commit), Rojo met
Studio à jour tout seul tant qu'il est connecté. Sauvegarde ta place (`Fichier → Enregistrer`)
où tu veux sur ton PC : elle n'est pas dans le dépôt, c'est normal.

## Contrôles

| Action | PC | Manette | Tactile |
| --- | --- | --- | --- |
| Se déplacer | ZQSD / WASD | stick gauche | joystick |
| Viser | souris | stick droit | glisser à droite de l'écran |
| Mobilité (saut, plané, sprint, wall-jump) | Espace ou clic droit | A | bouton « SAUT » |
| Tirer (roquette) | clic gauche | RT | bouton « TIR » |
| Marcher | Maj | L3 | — |
| Réglages (touches, sensibilité) | P | — | bouton ⚙ |

Bouton de mobilité :
- appui bref au sol → **micro-saut** ; tenu → **saut complet** (~2,6 m) ;
- tenu en montée → saut allongé ; tenu en descente → **plané** ;
- atterrir en tenant le bouton avec une direction → **sprint** ;
- appui en l'air contre un mur → **wall-jump**.
- Blocs jaunes : sprint direct · pads bleus : propulsion vers le haut · bandes jaunes : accélérateurs.

En haut à gauche, un petit texte affiche la vitesse (m/s) et l'état, pour comparer avec Godot.

## Roquette (étape 3)

- 5 charges, une recharge toutes les 2 s, 0,26 s mini entre deux tirs (barre orange en 5 segments).
- Vitesse 36 m/s en ligne droite ; explosion de 1,4 m de rayon = **1 vie** en moins pour l'adversaire.
- La poussée (3,4 m de rayon) touche tout le monde, **toi compris** : tire à tes pieds en sautant
  pour un **rocket jump** (aucun dégât sur toi).
- Le serveur fait foi pour les dégâts ; ta roquette s'affiche et te pousse tout de suite chez toi.
- Les sons sont ceux intégrés à Roblox, à remplacer dans `Config.Sounds`.

## Rail (étape 6)

- Sur une plateforme **Rail** (blocs néon cyan), l'arme devient le **Rail** : tir instantané,
  220 m, **1 vie** retirée, 1 charge rechargée en 2,5 s. On le garde en l'air jusqu'à reposer
  le pied ailleurs.
- Sur la plateforme, le bouton de mobilité **zoome** (champ de vision × 0,45) au lieu de sauter.
- Un tir de Rail qui passe à moins de 0,55 m d'une roquette en vol la **fait exploser**
  (« Roquette détruite en vol ! ») ; les dégâts de cette explosion reviennent au tireur du Rail.
- Roquettes et Rail se rechargent en même temps, même l'arme qu'on n'a pas en main.
- Le serveur accepte la touche vue par le tireur si elle est crédible (cible à moins de ~2 m de sa
  position serveur, rien de solide entre les deux) : pas besoin d'anticiper le ping.

## Bot et serveurs de 2 joueurs (étape 7)

- Chaque serveur accueille **2 joueurs** (réglage à faire une fois, voir « Publier » plus bas) :
  Roblox remplit les serveurs tout seul, c'est notre file d'attente.
- Seul sur un serveur pendant **15 s** (`Config.Match.BOT_WAIT`) : un **bot** arrive et le match
  commence. Dès qu'un vrai joueur rejoint, le bot laisse sa place et un nouveau match démarre.
- Le bot reprend le cerveau du bot Godot (niveau moyen par défaut, `Config.Match.BOT_SKILL`) :
  temps de réaction, visée avec anticipation et petite erreur, tirs aux pieds, strafe et sauts
  d'esquive, sprint, il reste dans le gaz et utilise le Rail sur les plateformes. Il se déplace
  avec **le même contrôleur** que les joueurs (mêmes vitesses, sauts, endurance).
- Navigation : PathfindingService de Roblox (le jeu Godot avait sa propre grille).

## Maps

Les 5 maps 1v1 du jeu Godot sont dans `src/shared/Maps` : **Cratère**, **Piliers**,
**Terrasses**, **Fosse**, **Passerelles**. Une map est tirée **au hasard à chaque nouveau
match** (jamais deux fois la même d'affilée) ; son nom s'affiche au compte à rebours.
Réglages dans `Config.Match` : `MAPS` (la liste) et `RANDOM_MAP` (false = toujours la première).

## Règles du 1v1 (étape 5)

- **Seul sur le serveur** : entraînement libre (« En attente d'un adversaire… »), pas de gaz.
- **À deux** : le match démarre. Le 1er joueur est Flic (bleu), le 2e Bandit (orange).
- Chaque manche : **3 vies**, compte à rebours **3 · 2 · 1 · GO** (on vise, on ne bouge pas),
  les spawns **alternent**. Celui qui perd ses 3 vies donne **+1 point** à l'autre.
- Deux morts presque en même temps (moins de 0,15 s) : **ÉGALITÉ**, la manche est rejouée.
- **Gaz lacrymo** : 5 s d'attente, puis 3 resserrements (66 s), jusqu'à 4 m de rayon.
  Hors du gaz = mort. Bip et message quand on est à moins de 4 m du bord.
- Premier à **11 points avec 2 d'écart** → écran de victoire, puis nouveau match.
- Un joueur qui part : victoire par forfait, retour à l'attente.
- Sirène / sifflet de début de manche et sons de victoire : à renseigner dans `Config.Sounds`.

## Animations des personnages

- Chaque joueur anime **les autres** personnages d'après leurs vrais mouvements : repos,
  marche, course, sprint (course accélérée), saut, chute, plané (chute ralentie).
- Le **bassin** se tourne vers la direction du déplacement (pas latéraux, marche arrière
  jouée à l'envers) ; le **buste et la tête** suivent la visée haut / bas de l'adversaire ;
  petit **recul** du buste à chaque tir.
- Les autres personnages tiennent leur **arme en main** (lance-roquettes, ou Rail quand ils
  sont sur une plateforme Rail), bras en position de tir, canon aligné sur leur visée :
  on voit de loin quelle arme ils ont et où ils visent.
- Ce sont les animations de l'avatar (packs d'animations équipés compris), sinon celles de
  Roblox par défaut.
- **Vue à la première personne** : tu vois tes **bras** et l'**arme en main** (lance-roquettes
  ou Rail, mêmes modèles que dans Godot). Tenue selon le camp : Flics manches SWAT bleues et
  gants, Bandits avant-bras nus et bracelets orange. L'arme balance avec la souris, suit la
  course, recule à chaque tir, descend / remonte quand on change d'arme, et disparaît
  pendant le zoom du Rail.
- Le reste de ton corps reste invisible (vue FPS) : pour voir les animations complètes,
  teste à deux (Test → Clients and Servers → 2 Players) ou contre le bot.

## Écran d'accueil et tutoriel

- À l'arrivée : écran titre **CAVALE** avec **JOUER**, **TUTORIEL**, **RÉGLAGES** (la caméra
  tourne autour de l'arène). Seuls les joueurs qui ont cliqué sur JOUER sont comptés pour
  les matchs et pour l'arrivée du bot.
- **Tutoriel** : 9 étapes validées automatiquement (déplacement, micro-saut, grand saut,
  plané, sprint, wall-jump, roquette, rocket jump, Rail) sur un terrain construit à l'écart
  de l'arène (`src/shared/TutorialMap.lua`) : il ne gêne pas un match en cours.
- Retour au menu : Réglages (P / ⚙) → **Menu principal** (pendant un match = forfait).

## Mobile

- Boutons **TIR** et **SAUT** dimensionnés selon la hauteur de l'écran (le bouton SAUT devient
  **ZOOM** sur une plateforme Rail) ; joystick qui apparaît sous le pouce gauche.
- Interfaces mises à l'échelle automatiquement (téléphone, tablette, PC).
- **Aide à la visée** au tactile et à la manette (pas à la souris) : si l'adversaire est
  presque sous le réticule (< 6°) et visible, le tir est légèrement ramené vers lui.
- Le tutoriel parle des boutons à l'écran au lieu des touches.

## Anti-triche

Le serveur vérifie les déplacements (`src/server/MoveGuard.lua`) : vitesse au-delà du possible
(beaucoup plus de marge juste après une explosion), montée trop rapide, vol, passage à travers
un mur. Le joueur est remis à sa dernière position valide ; expulsé après trop d'infractions.
Les tirs étaient déjà vérifiés (charges, cadence, position, touches crédibles).

## Niveaux, XP et classement

- **XP** à chaque match (`Config.Progress`) : match joué, match gagné, manche gagnée, touche,
  élimination, roquette détruite au Rail. **Contre le bot, l'XP est divisée par deux.**
- **Niveaux** : il faut 100 XP pour le niveau 2, puis 50 de plus à chaque niveau.
- **Classé (saison)** : chaque match **contre un joueur** fait gagner ou perdre des points
  (système Elo, départ à 1000). Après **3 matchs de placement**, on reçoit un rang :
  Bronze, Argent (900), Or (1100), Platine (1300), Diamant (1500), Champion (1700).
  Un forfait compte comme une défaite.
- **Nouvelle saison** : changer `Config.Ranked.SEASON` ; chacun garde la moitié de son écart
  à 1000 et refait ses matchs de placement.
- **Écran d'accueil** : carte du joueur (niveau, XP, rang, statistiques) et **classement
  mondial** (top 10). **Fin de match** : XP gagnée, montée de niveau, points classés.
- Sauvegarde : DataStore (comme les réglages : dans Studio, il faut l'accès aux services
  d'API, voir « Réglages »).

## Statistiques et défis du jour

- **Accueil → onglet STATS** : matchs, victoires, taux de victoire, manches gagnées,
  précision, touches, éliminations, touches en l'air, roquettes détruites, meilleure série de
  victoires, meilleur classement de la saison. **Fin de match** : précision, touches et
  éliminations du match.
- **Accueil → onglet DÉFIS** : 3 défis par jour (nouveaux à minuit UTC), tirés dans
  `src/shared/Challenges.lua` (gagner des manches, toucher au Rail, toucher un adversaire en
  l'air, détruire une roquette, manche sans perdre de vie…). L'XP est donnée dès que le défi
  est réussi (bandeau « DÉFI RÉUSSI ! »).

## Amis et salons privés

- **INVITER UN AMI** : ouvre la fenêtre d'invitation de Roblox (jeu publié seulement).
- **SALON PRIVÉ** : « Créer un salon » donne un **code à 6 caractères** ; ton ami clique sur
  SALON PRIVÉ, entre le code et vous vous retrouvez seuls sur un serveur. Le code s'affiche en
  haut de l'accueil. En salon : **pas de bot, matchs non classés** (XP et défis comptent).
  Ne marche que dans le jeu publié (la téléportation est impossible dans Studio).
- **Serveurs privés payants de Roblox** (optionnel, source de revenus) : Creator Hub →
  ton expérience → **Serveurs privés** → activer et fixer un prix. Ils sont aussi non classés.

## Vote de map

À la fin d'un match, **3 maps** sont proposées (autres que celle qu'on vient de jouer) : chacun
vote en cliquant ou avec **1 / 2 / 3** pendant l'écran de fin (12 s). La plus votée est jouée
au match suivant (égalité ou aucun vote : au hasard parmi les proposées).
`Config.Match.MAP_VOTE = false` pour revenir à une map au hasard.

## Langues

Le jeu est en **français et en anglais** (`src/shared/Lang.lua`) : langue du compte Roblox
par défaut, modifiable dans **Réglages → JEU → Langue**. Tous les textes passent par ce
module : pour ajouter une langue, copier le bloc `STRINGS.en` et le traduire.

## Page du jeu (icône, miniatures, questionnaire)

Voir [`docs/PAGE_DU_JEU.md`](docs/PAGE_DU_JEU.md) : descriptions FR / EN, icône et miniatures
prêtes dans `assets/store/`, réponses au questionnaire de maturité, liste avant publication.

## Sons

Les bruitages sont **ceux du jeu Godot** (générés par code, comme dans `autoload/sfx.gd`),
regroupés dans **un seul fichier** : `assets/sfx/cavale_sfx.ogg` (30 sons, 18 s). Le jeu joue
chaque son en lisant le bon morceau du fichier. Pour les entendre, il faut mettre ce fichier
en ligne **une fois** :

1. Va sur https://create.roblox.com → **Créations** → **Éléments de développement**
   (Development Items) → **Audio** → **Importer un élément** (Upload Asset).
2. Choisis `assets/sfx/cavale_sfx.ogg` (dans le dossier du dépôt), nom : « Cavale SFX ».
3. Une fois validé, ouvre l'audio, copie son **ID** (le nombre dans l'adresse de la page).
4. Dans `src/shared/Config.lua`, mets-le dans `Config.Audio.SFX_ID` :
   `SFX_ID = "rbxassetid://123456789",` puis enregistre (Rojo met Studio à jour).

Tant que l'ID est vide, quelques sons intégrés à Roblox sont joués à la place.
Pour régénérer la planche après avoir modifié un son : `python3 tools/make_sfx.py`
(nécessite Python et numpy), puis remettre le fichier en ligne et changer l'ID.

## Réglages (touche P ou bouton ⚙)

Deux onglets : **COMMANDES** (touches, sensibilité souris) et **JEU** (volume des sons,
champ de vision, sensibilités tactile et manette, forme et couleur du réticule, langue).

- **Touches** : 2 touches par action (avancer, reculer, gauche, droite, mobilité, tir,
  marcher). Clique sur une case puis appuie sur la nouvelle touche (ou un bouton de
  souris) ; Échap annule, Retour arrière efface. Les flèches marchent toujours.
- **Sensibilité souris** : boutons − / +. La souris est lue **en brut**, sans la
  sensibilité de Roblox ni accélération.
- Les réglages sont gardés pour ton compte (DataStore). Dans Studio, il faut avoir publié
  la place et activé **Paramètres du jeu → Sécurité → Autoriser l'accès de Studio aux
  services d'API** ; sinon ils marchent pendant la partie mais ne sont pas gardés.
- Si la souris semble encore « accélérer » : sur Windows, Paramètres → Bluetooth et
  appareils → Souris → Paramètres supplémentaires → onglet Options du pointeur → décoche
  **« Améliorer la précision du pointeur »** (c'est l'accélération de Windows).

## Publier une version test

1. Dans Studio, connecté à Rojo, **Fichier → Publier sur Roblox** (File → Publish to Roblox) :
   crée une nouvelle expérience, nom « Cavale » par exemple.
2. **Accueil → Paramètres du jeu** (Game Settings) :
   - **Places / Lieux** → modifie la place → **Nombre max. de joueurs : 2**
     (ou sur create.roblox.com : Créations → ton expérience → Places → la place → Accès / serveur) ;
   - **Avatar** : type **R15** (le contrôleur est réglé pour R15 ; R6 marche aussi) ;
   - **Sécurité** : rien de spécial à activer.
3. Sur **create.roblox.com** → ton expérience :
   - remplis le **questionnaire de maturité** (obligatoire pour rendre le jeu public) : pas de
     sang, violence cartoon → catégorie Mild / Moderate ;
   - **Accès** : laisse en **Privé** pour tes tests, ou « Amis » pour inviter des testeurs ;
     passe en **Public** quand tu es prêt.
4. Pour tester à plusieurs avant de publier : Studio → **Test → Clients and Servers → 2 Players**.
5. À chaque nouvelle version : récupère les commits, Rojo met Studio à jour, puis
   **Fichier → Publier sur Roblox** à nouveau.

## Vérifier le code (optionnel)

[Selene](https://github.com/Kampfkarren/selene) repère les fautes de syntaxe et les variables
non définies avant même de lancer Studio : `selene src` à la racine du dépôt (configuration :
`selene.toml` et `roblox_min.yml`). Installation : `cargo install selene` ou via Rokit.

## Que tester et me renvoyer

- Le **ressenti** : vitesse de course, hauteur du saut, plané, sprint, wall-jump.
- Le **rocket jump** : hauteur gagnée, et la poussée quand l'adversaire tire près de toi
  (test à deux : Test → Clients and Servers → 2 Players).
- Le **Rail** : zoom sur la plateforme, touche, roquette détruite en vol.
- Les **animations** de l'adversaire : course, sauts, plané, il regarde bien où il vise ?
- Le **bot** : arrivée après 15 s seul, niveau (trop fort / trop faible ?), il se coince ?
- Une **partie complète à deux** : compte à rebours, changement de côté, gaz, score, fin de match.
- Les **rampes** montent dans le bon sens ? (sinon dis-le : c'est une ligne à inverser)
- Bugs éventuels : copie le texte rouge de la fenêtre **Output** (Affichage → Output).
