# Page du jeu sur Roblox : textes, visuels, questionnaire

Tout se fait sur **https://create.roblox.com** → **Créations** → ton expérience.

## 1. Nom, description, genre

**Nom** : `Cavale` (ou `Cavale : duel 1v1 aux roquettes` pour être plus explicite dans la recherche).

**Description (français)** :

> 🚀 Duel 1 contre 1 aux roquettes : Flics contre Bandits !
>
> Saute, plane, sprinte et rebondis sur les murs avec un seul bouton. Tire à tes pieds pour un
> rocket jump, détruis les roquettes de ton adversaire au Rail, et reste dans la zone : le gaz
> lacrymo se resserre à chaque manche !
>
> • 3 vies par manche, premier à 11 points (2 d'écart)
> • 5 arènes, une au hasard à chaque match
> • Tutoriel de 2 minutes, bot d'entraînement si personne n'est en ligne
> • Niveaux, XP et classement de saison avec un classement mondial
> • PC, mobile et manette · touches et sensibilité réglables
>
> Pas de sang : style cartoon, que du skill.

**Description (anglais)** — à mettre dans **Localisation → Traductions** de la page du jeu :

> 🚀 1v1 rocket duel: Cops vs Robbers!
>
> Jump, glide, sprint and wall-jump with a single button. Shoot at your feet to rocket jump,
> destroy your opponent's rockets with the Rail, and stay inside the zone: the tear gas closes
> in every round!
>
> • 3 lives per round, first to 11 points (win by 2)
> • 5 arenas, a random one every match
> • 2-minute tutorial, practice bot when nobody is online
> • Levels, XP and seasonal ranked mode with a world leaderboard
> • PC, mobile and gamepad · custom keys and sensitivity
>
> No blood: cartoon style, pure skill.

**Genre** : *Combat* (ou *Shooter*). **Sous-genre** : *Arena / Duel*.
**Appareils** : ordinateur, téléphone, tablette, console (manette prise en charge).
**Nombre max. de joueurs** : **2** par serveur (voir README).

## 2. Icône et miniatures

Les fichiers sont dans `assets/store/` (régénérables avec `python3 tools/make_store_art.py`) :

| Fichier | Taille | Où |
| --- | --- | --- |
| `icon.png` | 512 × 512 | **Paramètres de base → Icône** |
| `thumb_fr_1.png` … `thumb_fr_3.png` | 1920 × 1080 | **Paramètres de base → Miniatures** |
| `thumb_en_1.png` … `thumb_en_3.png` | 1920 × 1080 | **Localisation → Images** (langue : anglais) |

Conseils :
- Roblox valide (modère) chaque image avant de l'afficher : compte quelques minutes.
- Ajoute **2 ou 3 vraies captures du jeu** : ce sont souvent elles qui donnent envie de cliquer.
  Dans Studio, lance une partie contre le bot, cache le HUD si besoin, puis capture l'écran
  (Windows : `Win + Maj + S`), recadre en 1920 × 1080.
- La 1re miniature est la plus vue : garde `thumb_fr_1` (titre + Flics vs Bandits) en premier.

## 3. Questionnaire de maturité (obligatoire pour être public)

**Paramètres → Questionnaire de maturité et conformité**. Réponses conseillées pour Cavale
(le jeu tel qu'il est aujourd'hui) :

| Question | Réponse |
| --- | --- |
| Violence | **Oui, violence légère** : combats avec des armes fantaisistes (roquettes, rayon), pas de sang, pas de démembrement, les personnages « disparaissent » dans une explosion cartoon |
| Sang | **Non** |
| Contenu effrayant | **Non** |
| Grossièretés | **Non** |
| Alcool, drogue, tabac | **Non** (le « gaz lacrymo » est une zone de jeu, pas une drogue) |
| Contenu romantique / sexuel | **Non** |
| Jeux d'argent / hasard payant | **Non** (pas de lootbox) |
| Communication libre (chat) | **Oui** : le chat Roblox standard est actif |
| Achats en jeu | **Non pour l'instant** (à mettre à jour quand la boutique arrivera) |
| Liens externes / partage d'infos | **Non** |

Résultat attendu : catégorie **Léger (Mild)**, accessible à un large public.
Si tu ajoutes plus tard des achats (skins, passe de saison), **reviens mettre à jour** le
questionnaire.

## 4. Langues

- Les textes du jeu sont traduits par le jeu lui-même (`src/shared/Lang.lua`, français et
  anglais), selon la langue du compte Roblox du joueur ; le joueur peut la changer dans
  **Réglages → JEU → Langue**.
- Dans **Localisation**, mets la **langue source : français**, ajoute **l'anglais**, et
  **désactive la « capture automatique des textes »** et la **traduction automatique** :
  le jeu gère déjà ses traductions (les interfaces ont `AutoLocalize = false`).
- Traduis aussi le **nom** et la **description** de la page (section 1).

## 5. Avant d'ouvrir au public

- [ ] Partie complète testée à 2 joueurs sur 2 PC (en privé ou avec des amis).
- [ ] Partie testée sur un téléphone (application Roblox, jeu en privé partagé avec toi).
- [ ] `Config.Audio.SFX_ID` renseigné (sons, voir README).
- [ ] **Paramètres → Sécurité → Autoriser l'accès de Studio aux services d'API** (pour tester
  les sauvegardes dans Studio) ; en ligne, les DataStores marchent sans rien faire.
- [ ] Icône, miniatures, description FR / EN, questionnaire de maturité.
- [ ] **Accès → Public**.
