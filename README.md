# Cavale — version Roblox (mode 1v1 « Règlement de comptes »)

FPS d'arène inspiré de ShootMania : déplacements très mobiles, roquettes lentes, skill.
Portage du jeu Godot (`thoomaslef/Arena`). Le cahier des charges complet est dans
[`docs/PASSATION_1V1.md`](docs/PASSATION_1V1.md).

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Projet Rojo, structure du dépôt | ✅ |
| 2 | Contrôleur de déplacement + caméra FPS + endurance | ✅ à tester |
| 4 | Import des maps Godot (Cratère par défaut) | ✅ à tester |
| 3 | Roquette, explosion, rocket jump | à faire |
| 5 | Règles du 1v1 : vies, manches, score, gaz, HUD | à faire |
| 6 | Plateformes Rail + Rail | à faire |
| 7 | Matchmaking 2 joueurs, bot, publication | à faire |

## Organisation

```
default.project.json      → dit à Rojo où va chaque dossier dans Studio
src/shared/  → ReplicatedStorage.Shared   (code commun client + serveur)
  Config.lua                 toutes les constantes (en mètres / secondes)
  MapBuilder.lua             construit une map JSON Godot en Parts
  CharacterRig.lua           prépare l'avatar (cylindre de collision, groupes)
  Maps/*.json                les 5 maps 1v1 du jeu Godot
src/server/  → ServerScriptService.Server
  Main.server.lua            construit la map, fait apparaître les joueurs
src/client/  → StarterPlayer.StarterPlayerScripts.Client
  Main.client.lua            boucle client
  Movement.lua               contrôleur de déplacement maison (portage de fighter.gd)
  FpsCamera.lua              caméra FPS
  Input.lua                  clavier / souris / manette / tactile
  Hud.lua                    réticule, endurance, infos de réglage
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

## Contrôles (étape 2)

| Action | PC | Manette | Tactile |
| --- | --- | --- | --- |
| Se déplacer | ZQSD / WASD | stick gauche | joystick |
| Viser | souris | stick droit | glisser à droite de l'écran |
| Mobilité (saut, plané, sprint, wall-jump) | Espace ou clic droit | A | bouton « SAUT » |
| Marcher | Maj | L3 | — |

Bouton de mobilité :
- appui bref au sol → **micro-saut** ; tenu → **saut complet** (~2,6 m) ;
- tenu en montée → saut allongé ; tenu en descente → **plané** ;
- atterrir en tenant le bouton avec une direction → **sprint** ;
- appui en l'air contre un mur → **wall-jump**.
- Blocs jaunes : sprint direct · pads bleus : propulsion vers le haut · bandes jaunes : accélérateurs.

En haut à gauche, un petit texte affiche la vitesse (m/s) et l'état, pour comparer avec Godot.

## Que tester et me renvoyer

- Le **ressenti** : vitesse de course, hauteur du saut, plané, sprint, wall-jump.
- Les **rampes** montent dans le bon sens ? (sinon dis-le : c'est une ligne à inverser)
- Bugs éventuels : copie le texte rouge de la fenêtre **Output** (Affichage → Output).
