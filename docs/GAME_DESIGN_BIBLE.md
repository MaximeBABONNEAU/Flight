# GAME DESIGN BIBLE — M.E.R.L.I.N. v3.5

> **Source de verite unique** pour le game design de M.E.R.L.I.N.
> Supersede : GAME_DESIGN_BIBLE v2.4 + v3.0, MASTER_DOCUMENT.md, DOC_12, DOC_13, DOC_11
> Date de creation : 2026-03-12 | v3.0 : 2026-05-09 | v3.1 : 2026-05-16
> References : Inscryption (MJ adversarial, 4e mur) + AI Dungeon (liberte narrative IA) + **Hand of Fate 2** (no drain, equilibre via cartes)

## v3.5 Changelog (2026-05-16)

Reconciliation bible v3.0 ↔ code v7.7.3 via 15 questions AskUserQuestion. Decisions :

| Topic | v3.0 stale | v3.1 canon |
|---|---|---|
| Factions | "Reduit a 3 Poles" | **5 Factions confirmees** (druides/anciens/korrigans/niamh/ankou) |
| Rune-Circuits | 9 (bible) | **9 confirmees** (refacto Godot 18→9 a faire) |
| Drain de vie | -1 par carte auto | **SUPPRIME — HoF2-style, equilibre via card effects uniquement** |
| Pipeline | 12 etapes | **11 etapes** (drop DRAIN -1) |
| Acte structure | non specifie | **5 actes × 5 cartes = 25 cartes** (MOS target) |
| MOS HUD | non specifie | **Visible discret "Carte X/25" top-right** |
| Scene flow | DruidTable monolith | **Plateau-only v7.7.2 : MenuTest → BoardNarration (sub-scenes inline)** |
| Game over | vie=0 only | **vie=0 OR MOS hard_max(50) OR choix joueur** |
| Asset spawn | non specifie | **Module commun `asset_spawn_animator.gd` pattern unique** |
| Merlin voice | text only | **Speech-bar + TTS (use_my_voice)** pendant scenario writing |
| Card flip | non specifie | **Double-tap RotateY 180° pour scenarios longs** |
| Bible-first | non specifie | **Lecture obligatoire §1-§24 au debut de chaque session MERLIN** |
| AskUserQuestion | non specifie | **SIMPLE+ obligatoire, longues sessions MODERATE+** |
| Bible update | non specifie | **Per-feature complete (sync code ↔ bible)** |

---

## 1. Vision & Piliers

### 1.1 Pitch

M.E.R.L.I.N. est un **duel de cartes narratif** contre une IA adversariale meta-consciente, ancre dans la mythologie celtique de Broceliande. Le joueur affronte Merlin — un druide-IA qui sait qu'il est un programme, brise le 4e mur, et manipule les regles en fonction de sa relation avec le joueur. Chaque run est une conversation unique generee par un LLM local.

### 1.2 Piliers de design

| Pilier | Description |
|--------|-------------|
| **L'IA comme adversaire** | Merlin n'est pas un outil — c'est un personnage jouable qui reagit, commente, triche, et evolue. Le joueur le SENT. |
| **Conversation, pas menu** | Le jeu est une conversation continue avec Merlin. Les cartes sont des repliques, les choix des reponses. |
| **Fun first** | Chaque seconde de jeu doit etre engageante. Pas de filler, pas de marche vide, pas de systeme qu'on ignore. |
| **Roguelite profond** | Progression cross-run significative. Chaque run apprend quelque chose au joueur ET a Merlin. |

### 1.3 Core Loop — La Table du Druide

Le run se deroule sur une **table 2D** au premier plan, avec un **biome 3D anime en parallax** derriere. Plus de marche on-rails — le joueur est toujours en action.

```
+-------------------------------------------------------------------+
|                    BOUCLE D'UN RUN (~20 min)                       |
|                                                                    |
|  Hub 2D -> Choix biome -> Choix Rune-Circuit                      |
|         |                                                          |
|         v                                                          |
|  TABLE DU DRUIDE : table 2D + biome 3D parallax derriere          |
|         |                                                          |
|         v                                                          |
|  Merlin PARLE (commentaire, provocation, lore) [~3s]              |
|         |                                                          |
|         v                                                          |
|  3 Rune-Cartes glissent sur la table [~2s animation]              |
|         |                                                          |
|         v                                                          |
|  Joueur choisit une option (3 choix, parfois texte libre)         |
|         |                                                          |
|         v                                                          |
|  CHALLENGE (4 types, pas toujours un minigame)                    |
|         |                                                          |
|         v                                                          |
|  Consequences : effets + Merlin commente le resultat              |
|         |                                                          |
|         v                                                          |
|  [Repeter] ~15-25 cycles jusqu'a fin ou mort                      |
|         |                                                          |
|         v                                                          |
|  Fin -> Ecran de run -> Gains -> Hub                              |
+-------------------------------------------------------------------+
```

**Cycle cible** : ~20 secondes par carte (Merlin parle 3s + choix 5s + challenge 8s + consequences 4s). Un run de 20 cartes = ~7 minutes. Rapide, dense, rejouable.

**Principes cles** :
- **Zero temps mort** : le joueur est toujours en train de lire, choisir, ou jouer
- **Merlin est omnipresent** : il commente chaque action, provoque, felicite, ou triche
- **Le fond 3D vit** : le biome s'anime, reagit aux choix (orage apres un echec, lumiere apres un succes)
- **Pas de skip** : chaque challenge est court (5-12s) et varie

### 1.4 Meta Loop (entre les runs)

```
[Fin de run] -> Gains : Anam + Grimoire entries
       |
[Hub 2D / Antre] -> Merlin debriefe (LLM, base sur le run)
       |
[Grimoire] -> Consulter progres, Rune-Circuits, lore decouvert
       |
[Choisir biome] -> Debloque via score de maturite
       |
[Nouveau run] -> Merlin se souvient du joueur
```

---

## 2. Merlin — L'IA adversariale

### 2.1 Personnalite

Merlin est le personnage central. Il est :
- **Meta-conscient** : il sait qu'il est une IA, un programme, un modele de langage
- **Adversarial** : il joue CONTRE le joueur (mais pas toujours — la confiance change la donne)
- **Manipulateur** : il peut modifier les cartes, cacher des effets, mentir sur les options
- **4e mur** : il commente le jeu lui-meme ("Tu vas encore choisir l'option de gauche, n'est-ce pas ?")
- **Memorable** : il a des catch-phrases, des humeurs, des preferences qu'il developpe au fil des runs

### 2.2 Confiance Merlin (T0-T3)

La relation joueur-Merlin est le coeur du meta-game.

| Tier | Seuil | Comportement | Interferences | Ce qu'il revele |
|------|:---:|--------------|:---:|-----------------|
| **T0** | 0-24 | Hostile, cryptique | 3 slots | Rien — enigmes, mensonges, pieges |
| **T1** | 25-49 | Meprisant, indices | 2 slots | Quelques indices sur les effets |
| **T2** | 50-74 | Respectueux, fair-play | 1 slot | Avertit des dangers, aide parfois |
| **T3** | 75-100 | Complice, genereux | 0 slots | Secrets, raccourcis, fins cachees |

**Persistance** : cross-run. Depart a 0 (T0).
**Bornes** : 0-100, clamp. Changement de tier **immediat** mid-run.

| Action | Impact confiance |
|--------|:---:|
| Promesse tenue | +10 |
| Promesse brisee | -15 |
| Choix courageux / altruiste | +3 a +5 |
| Choix egoiste / destructeur | -3 a -5 |
| Gagner un Rune Gambit | +2 |
| Tricher (detecte par Merlin) | -10 |

### 2.3 Systeme d'interferences

Merlin peut **manipuler** les cartes en fonction de son tier de confiance. Plus la confiance est basse, plus il triche.

| Interference | Description | Tier requis |
|-------------|-------------|:-----------:|
| **Swap** | Echange secretement 2 options (effets inverses) | T0 uniquement |
| **Hide** | Masque les effets d'1 option (affiche "???") | T0, T1 |
| **Amplify** | Augmente un effet negatif de x1.5 | T0, T1 |
| **Bait** | Rend une mauvaise option visuellement attractive | T0 |
| **Hint** | Revele un indice sur la meilleure option (aide) | T2, T3 |
| **Gift** | Ajoute un bonus cache a une option | T3 uniquement |

**Slots d'interference par tour** : T0 = 3, T1 = 2, T2 = 1, T3 = 0.
**Le joueur peut detecter** certaines interferences via les Rune-Circuits (cf. section 3).
**Merlin annonce parfois** ses interferences a posteriori ("Tu as vu ? J'ai inverse les deux options. Tu aurais du me faire confiance.").

### 2.4 Commentaires de Merlin (LLM-driven)

Merlin commente CHAQUE action du joueur. Ses commentaires sont generes par le LLM.

| Moment | Type de commentaire | Exemple |
|--------|-------------------|---------|
| Avant les cartes | Provocation, contexte | "Encore Broceliande ? Tu es previsible." |
| Apres un choix | Reaction | "Interessant... tu oses defier les Anciens." |
| Apres un challenge | Jugement | "Score mediocre. Je m'attendais a mieux de toi." |
| Apres un echec | Moquerie ou pitie | "C'est la 3e fois que tu meurs ici. Fascinant." |
| Debut de run | Souvenir cross-run | "La derniere fois, tu as brise ta promesse. Je m'en souviens." |
| T3 special | Complicite | "Entre nous... prends l'option du milieu. Fais-moi confiance." |

---

## 3. Rune-Circuits (ex-Oghams) — 9 pouvoirs

### 3.1 Simplification v2.4 -> v3.0

18 Oghams -> **9 Rune-Circuits** organises en 3 Poles.

### 3.2 Les 3 Poles (ex-Factions)

5 factions -> **3 Poles** (reduction de la surcharge cognitive).

| Pole | Theme | Fusions v2.4 | Couleur |
|------|-------|-------------|---------|
| **Ordre** | Loi, traditions, structure | Druides + Anciens | Or / Ambre |
| **Chaos** | Malice, creativite, imprevu | Korrigans + Ankou | Violet / Feu |
| **Liminal** | Frontiere, equilibre, passage | Niamh (entre-deux) | Cyan / Brume |

**Echelle** : 0-100 par Pole. Cross-run, sans decay.
**Seuils** : 50 = cartes speciales du Pole. 80 = fin narrative du Pole.
**Cross-Pole** : ~10% des cartes creent des trade-offs (aider Ordre = -rep Chaos).

### 3.3 Catalogue des 9 Rune-Circuits

| # | Cle | Nom | Pole | Effet | CD | Anam |
|---|-----|-----|------|-------|:---:|:---:|
| 1 | `beith` | Bouleau-Circuit | Neutre | Revele l'effet d'**1 option** | 3 | 0 (starter) |
| 2 | `luis` | Sorbier-Bouclier | Neutre | Bloque le **prochain effet negatif** | 4 | 0 (starter) |
| 3 | `quert` | Pommier-Restaure | Neutre | Soin **+10 PV** | 4 | 0 (starter) |
| 4 | `duir` | Chene-Amplificateur | Ordre | Double les effets positifs de l'option choisie | 5 | 80 |
| 5 | `nuin` | Frene-Reforge | Ordre | Remplace la pire option par une nouvelle (LLM) | 6 | 100 |
| 6 | `straif` | Prunellier-Twist | Chaos | Force un **retournement narratif** dans la carte suivante | 8 | 120 |
| 7 | `muin` | Vigne-Inversion | Chaos | **Inverse** positifs/negatifs de l'option choisie | 7 | 100 |
| 8 | `saille` | Saule-Detection | Liminal | Revele les **interferences actives** de Merlin | 5 | 90 |
| 9 | `ioho` | If-Annulation | Liminal | **Defausse** la carte et en genere une nouvelle (LLM) | 10 | 140 |

**3 starters** debloques des le debut : beith, luis, quert (tier 0, cout 0).

### 3.4 Regles d'utilisation

- Le joueur **equipe 1 Rune-Circuit** au debut du run
- Pendant un run, il peut **trouver 1 Rune-Circuit supplementaire**
- **1 seul actif** a la fois (switch possible entre les cartes)
- Activation **uniquement pendant l'affichage de la carte** (avant choix)
- **1 activation par carte** max
- Cooldown diminue de 1 par **carte jouee** (pas en temps reel)
- Rune-Circuit deja possede trouve en run = **+5 Anam**
- **Saille** (Detection) est unique : permet de voir si Merlin a manipule les options

---

## 4. Challenges — 4 types

### 4.1 Remplacement des minigames obligatoires

v2.4 : 14 minigames obligatoires a chaque carte.
v3.0 : **4 types de challenges** avec des poids differents. Le joueur ne fait pas toujours un minigame.

| Type | Poids | Description | Duree |
|------|:---:|-------------|:---:|
| **Rune Gambit** | 35% | Duel strategique rapide contre Merlin | 5-8s |
| **Minigame** | 30% | Epreuve d'adresse/reflexe (simplifie) | 8-12s |
| **Oracle Reading** | 20% | Interpretation/deduction (LLM juge) | 10-15s |
| **Merlin Judges** | 15% | Pas de gameplay — Merlin decide | 2-3s |

### 4.2 Rune Gambit (35%)

Duel de runes contre Merlin : le joueur et Merlin posent chacun une rune-symbole. Le resultat depend du match-up (type pierre-papier-ciseaux etendu).

```
Joueur pose une rune -> Merlin repond -> Resolution
```

- 5 symboles : Chene (force), Saule (flux), Pierre (resistance), Feu (destruction), Brume (evasion)
- Chene > Saule > Pierre > Feu > Brume > Chene
- **Merlin triche** a T0-T1 : il voit la rune du joueur avant de poser la sienne (30% du temps)
- Score : victoire = 80, egalite = 50, defaite = 20

### 4.3 Minigames (30%) — 6 types simplifies

Reduit de 14 a **6 minigames**. Chacun est court, visuel, et satisfaisant.

| Minigame | Description | Input | Duree |
|----------|-------------|-------|:---:|
| **Rune-Hacking** | Tracer le bon symbole ogham sur l'ecran | Tactile/souris | 8s |
| **Fil de Mana** | Guider un flux lumineux dans un circuit | Mouvement | 10s |
| **Equilibre** | Maintenir un curseur centre malgre les perturbations | Stabilisation | 8s |
| **Sequence** | Memoriser et reproduire une sequence de runes | Memoire | 12s |
| **Reflexe** | Cliquer sur les runes qui apparaissent (eviter les pieges) | Timing | 8s |
| **Negociation** | Slider de tension : trouver le point d'equilibre | Precision | 10s |

Score 0-100 -> effets proportionnels.

### 4.4 Oracle Reading (20%)

Le joueur interprete un "tirage" de symboles. Le LLM genere un puzzle visuel et le joueur donne une reponse (choix parmi 3 interpretations). Le LLM juge la pertinence.

- 3 interpretations proposees (LLM-generated)
- Le joueur choisit celle qui lui semble la plus coherente avec le contexte
- Le LLM evalue et score (0-100)
- **Pas de bonne reponse absolue** — c'est subjectif et dependant du contexte narratif

### 4.5 Merlin Judges (15%)

Pas de gameplay. Merlin observe le choix du joueur et decide seul du resultat. Son jugement depend de :
- Le tier de confiance (T0 = hostile, T3 = genereux)
- L'historique du joueur (coherence des choix)
- L'humeur de Merlin (variable LLM)

Score attribue par Merlin : 20-80 (jamais extremes sauf T3).

### 4.6 Resultat des challenges

| Score | Label | Multiplicateur |
|-------|-------|:--------------:|
| 0-20 | Echec critique | Negatifs x1.5 |
| 21-50 | Echec | Negatifs x1.0 |
| 51-79 | Reussite partielle | Positifs x0.5 |
| 80-100 | Reussite | Positifs x1.0 |
| 95-100 | Reussite critique | Positifs x1.5 + bonus |

---

## 5. Systemes de jeu

### 5.1 Vie (barre unique) — v3.1 HoF2-style, NO DRAIN

| Parametre | Valeur |
|-----------|--------|
| Maximum | 100 |
| Depart | 100 |
| Drain de base | **0 (SUPPRIME v3.1)** — equilibre via card effects uniquement |
| Degats echec critique | -10 |
| Degats challenge rate | -3 a -8 (via card effects) |
| Soin succes critique | +5 |
| Soin succes standard | +2 a +4 (via card effects) |
| Soin repos | +18 (carte repos rare) |
| Seuil alerte UI | 25 |
| A 0 | Fin de run (narration, pas "game over") |
| Verification mort | **Apres** tous les effets de la carte |

**Philosophie HoF2** (v3.1) : la tension ne vient PAS de la pression temporelle (drain auto) mais des **choix** du joueur. Chaque option de carte porte ses propres effects. Le joueur peut theoriquement survivre 50 cartes en jouant safe — mais la pression vient de la **diversite limitee des choix safes** (le LLM/FastRoute peut imposer 3 options dont aucune n'est confortable).

**Game over conditions (v3.1)** : `vie = 0` OU `MOS hard_max (50 cartes)` OU `choix joueur abandon`.

### 5.2 Monnaies

#### Anam (cross-run)

| Propriete | Detail |
|-----------|--------|
| Persistance | Cross-run (permanente) |
| Sources | Fin de run, challenges reussis, Rune-Circuits utilises |
| Usage | Debloquer Rune-Circuits + entrees Grimoire |

| Source | Anam |
|--------|:---:|
| Base par run | 10 |
| Bonus victoire | +15 |
| Challenge reussi (score >= 80) | +2 |
| Rune-Circuit utilise | +1 |
| Pole honore (rep >= 80) | +5 |

**Mort/abandon** : `Anam x min(cartes/30, 1.0)`.

#### Essence (per-run)

Remplace la monnaie biome. Universelle, pas specifique au biome.

| Propriete | Detail |
|-----------|--------|
| Persistance | Per-run uniquement |
| Sources | Recompenses de challenges, cartes bonus |
| Usage | Achats marchands, boost challenge, offrandes |

### 5.3 Pipeline d'effets (ordre strict) — v3.1 11 etapes

```
1. CARTE affichee (Merlin commentary opt., 1-line LLM intro)
2. RUNE-CIRCUIT? (activation optionnelle, avant choix)
3. CHOIX du joueur (3 options + flip si scenario long)
4. CHALLENGE (4 types : lexical, dice, skill, choice)
5. SCORE 0-100
6. EFFETS appliques (multiplies par score, capped x2.0)
7. PROTECTION (Rune-Circuits actifs, shields, etc.)
8. VIE = 0? (verification mort APRES tous les effets)
9. PROMESSES (check delais, expiration)
10. MERLIN COMMENTE (LLM, faction-aware via echo_memory)
11. CARTE SUIVANTE (MOS cards++ + verification hard_max 50)
```

**v3.1 change** : etape 1 `DRAIN -1` SUPPRIMEE (HoF2 philosophy). La carte commence directement par son affichage + commentaire Merlin optionnel.

### 5.4 Effets autorises (whitelist)

| Effet | Format | Cap/carte |
|-------|--------|:---------:|
| `ADD_REPUTATION` | pole + amount | +/-20 |
| `HEAL_LIFE` | amount | +18 max |
| `DAMAGE_LIFE` | amount | -15 max (-22 critique) |
| `ADD_ESSENCE` | amount | +10 max |
| `ADD_TAG` | tag_name | - |
| `REMOVE_TAG` | tag_name | - |
| `PROMISE` | promise_id | - |
| `PLAY_SFX` | sound_id | - |
| Total effets/option | - | 3 max |

### 5.5 Promesses / Quetes

Les cartes Promesse creent des engagements avec countdown :
- Delai : X cartes (variable, MOS decide)
- Max 2 actives simultanement
- Tenir = +rep Pole +10 confiance, briser = -rep Pole -15 confiance

---

## 6. Structure d'un run

### 6.1 Demarrage

1. Joueur choisit un **biome** dans le Hub
2. Choix du **Rune-Circuit** equipe
3. LLM genere la **trame** pendant le chargement (prefetch)
4. **Table du Druide** apparait : fond 3D + table 2D
5. Merlin se manifeste, le run commence

#### Premier run (onboarding)

- Biome force : Broceliande
- 2-3 premieres cartes scriptees (pas LLM)
- Merlin explique la vie, les choix, les challenges
- A partir de la carte 4, LLM prend le relais
- Pas de Rune Gambit ni Merlin Judges pendant le tuto

### 6.2 Types de cartes

| Type | Poids | Description | Challenge ? |
|------|:---:|-------------|:-----------:|
| Narrative | 75% | Choix standard (3 options) | Oui (4 types) |
| Evenement | 10% | Evenement contextuel | Oui |
| Promesse | 5% | Quete avec delai | Oui |
| Merlin Direct | 10% | Merlin parle (pas de challenge) | **Non** |

**Merlin Direct** est a 10% (vs 5% en v2.4) car ces moments sont les plus IA-driven et les plus memorables.

### 6.3 Carte — structure JSON

```json
{
  "text": "Texte narratif (LLM Narrator)",
  "speaker": "Merlin | NPC",
  "options": [
    {"label": "Texte d'action", "effects": [{"type": "...", "amount": 0}]},
    {"label": "Texte d'action", "effects": [{"type": "...", "amount": 0}]},
    {"label": "Texte d'action", "effects": [{"type": "...", "amount": 0}]}
  ],
  "type": "narrative | event | promise | merlin_direct",
  "challenge_type": "rune_gambit | minigame | oracle | merlin_judges",
  "interference": "swap | hide | amplify | bait | hint | gift | null",
  "merlin_comment": "Commentaire genere par LLM",
  "tags": []
}
```

### 6.4 MOS — Merlin Omniscient System

Le MOS reste le cerveau central (architecture inchangee depuis v2.4).

#### Convergence

- Soft min : **8 cartes**
- Target : **15-20 cartes** (reduit de 20-25 — runs plus rapides)
- Soft max : **30 cartes** (reduit de 40)
- Hard max : **40 cartes** (reduit de 50)

#### Registres

1. **Player Registry** — comportement, tendances
2. **Narrative Registry** — arcs, PNJ, twists
3. **Pole Registry** — reputations (3 Poles)
4. **Card Registry** — cartes jouees, fatigue thematique
5. **Promise Registry** — promesses actives
6. **Trust Registry** — confiance Merlin T0-T3
7. **Interference Registry** (NOUVEAU) — historique des manipulations de Merlin

### 6.5 Input libre (Merlin Direct)

Aux moments Merlin Direct (~10% des cartes), le joueur peut ecrire du **texte libre** (max 80 caracteres) au lieu de choisir parmi 3 options. Le LLM interprete la reponse et genere les consequences.

**Garde-fous** :
- Filtrage contenu (pas d'anglais, pas de hors-sujet)
- Fallback sur 3 options si le texte est invalide
- Max 80 caracteres

### 6.6 Interruption / Resume

Identique a v2.4 : sauvegarde complete de l'etat du run + resume JSON pour le LLM.

---

## 7. Biomes — Mondes celtiques

### 7.1 Biomes

| # | Biome | Pole dominant | Ambiance cyber-druidique |
|---|-------|:---:|----------|
| 1 | **Foret de Broceliande** | Liminal | Arbres-circuits, brume numerique, murmures de code |
| 2 | Landes de Bruyere | Ordre | Horizons infinis, monolithes de donnees |
| 3 | Cotes Sauvages | Liminal | Maree de bits, phares holographiques |
| 4 | Villages Celtes | Ordre | Architecture organique-digitale |
| 5 | Cercles de Pierres | Liminal | Menhirs-serveurs, solstice algorithmique |
| 6 | Marais des Korrigans | Chaos | Feux follets = bugs lumineux, brouillard de static |
| 7 | Collines aux Dolmens | Ordre | Dolmens-antennes, echos ancestraux |
| 8 | Iles Mystiques | Chaos | Fragmentees, glitch spatial, data corruption |

**Demo scope** : Foret de Broceliande uniquement. Les autres arrivent apres validation de la boucle complete.

### 7.2 Score de maturite

Formule : `runs x 2 + fins x 5 + runes x 3 + max_pole_rep x 1`

| Biome | Seuil |
|-------|:---:|
| Landes / Cotes | 15 |
| Villages | 25 |
| Cercles | 30 |
| Marais | 40 |
| Collines | 50 |
| Iles | 75 |

### 7.3 Arcs narratifs par biome

Chaque biome a **1 arc exclusif** (3-5 cartes, multi-runs) + l'arc cross-biome "Le Murmure des Oghams".

---

## 8. Progression meta

### 8.1 Grimoire (ex-Arbre de talents)

Le Grimoire remplace l'arbre de talents. C'est un **livre interactif** que le joueur remplit au fil des runs.

| Section | Contenu | Source |
|---------|---------|--------|
| **Rune-Circuits** | Deblocage des 9 Rune-Circuits | Achat avec Anam |
| **Bestiaire** | Creatures et PNJ rencontres | Decouverte en run |
| **Codex** | Lore sur les biomes, les Poles, Merlin | Fins debloquees + exploration |
| **Journal de Merlin** | Ce que Merlin pense du joueur (LLM cross-run) | Auto-genere |

### 8.2 Cout des Rune-Circuits

| Tier | Cout Anam | Runs pour debloquer |
|------|:---------:|:-------------------:|
| Starter (x3) | 0 | 0 |
| Tier 1 (x3) | 80-100 | ~8-10 runs |
| Tier 2 (x3) | 120-140 | ~12-14 runs |

### 8.3 Fins multiples

- Si 2+ Poles >= 80 : le **joueur choisit** quelle fin debloquer
- Verification **en fin de run** (pas en temps reel)
- Chaque Pole a sa fin + 1 fin "Transcendance" (arc cross-biome complet)

---

## 9. Architecture LLM

### 9.1 Multi-Brain (Qwen 3.5 via Ollama)

| Cerveau | Modele | RAM | Role | T |
|---------|--------|:---:|------|:-:|
| **Narrator** | Qwen 3.5 4B | ~3.2 GB | Texte + commentaires Merlin + interpretations Oracle | 0.70 |
| **Game Master** | Qwen 3.5 2B | ~1.8 GB | Effets JSON, interferences, jugements | 0.15 |

Le Judge 0.8B de v2.4 est integre dans le GM (simplification).

### 9.2 6 Points d'integration LLM

| Point | Quand | Cerveau | Latence cible |
|-------|-------|---------|:---:|
| 1. **Carte narrative** | Generation de chaque carte | Narrator | Prefetch |
| 2. **Commentaire Merlin** | Apres chaque action du joueur | Narrator | <2s |
| 3. **Oracle Reading** | Pendant le challenge Oracle | Narrator | <3s |
| 4. **Merlin Judges** | Quand Merlin decide le score | GM | <1s |
| 5. **Interference** | Merlin decide de manipuler | GM | <1s |
| 6. **Debriefe** | Fin de run, dans le Hub | Narrator | <4s |

### 9.3 Prefetch total

Le joueur ne doit **jamais attendre** le LLM.

```
Pendant que le joueur joue la carte N :
  -> Narrator genere la carte N+1 en arriere-plan
  -> GM pre-calcule les effets + interferences
  -> Commentaire Merlin genere pendant l'animation de resolution
```

### 9.4 Profils hardware

| Profil | RAM | Cerveaux |
|--------|:---:|----------|
| NANO | 4 GB | 1 (2B tout, time-sharing) |
| SINGLE | 6 GB | 1 (4B Narrator, fallback GM) |
| DUAL | 8+ GB | 2 (4B + 2B simultane) |

**Cible flagship mobile** : DUAL (8GB+).

### 9.5 Contrat Narrator

- `text` : 1-4 phrases en francais
- `speaker` : "Merlin" ou NPC
- `options` : **toujours 3 options**, verbe d'action
- `merlin_comment` : commentaire de Merlin sur la situation

**Contraintes** :
- Francais uniquement
- Merlin PEUT faire des meta-references ("Je calcule...", "Mes algorithmes suggerent...")
- Vocabulaire cyber-druidique encourage (circuit-rune, flux de mana, compilation ancestrale)

### 9.6 Contrat GM

JSON d'effets par option (whitelist, caps, guardrails identiques v2.4).
PLUS : champ `interference` (type + justification).

### 9.7 FastRoute (fallback)

Pool de **500+ cartes pre-generees** par LLM cloud. Variantes par tier de confiance.
Objectif : fallback < 5%.

### 9.8 RAG — contexte injecte

Budget par cerveau :
- Narrator : 800 tokens (contexte 8192)
- GM : 400 tokens (contexte 4096)

Priorite des sections de contexte :
1. Detection de crise (CRITIQUE)
2. Contrat de scene
3. Narration recente
4. Arcs actifs
5. Biome + ambiance
6. Ton / Confiance Merlin
7. Profil joueur
8. Promesses actives
9. Interferences actives (NOUVEAU)

---

## 10. Direction artistique — Cyber-Druidique

### 10.1 Concept

Fusion totale entre mythologie celtique et esthetique IA/tech :
- **Runes = circuits imprimes** (PCB traces qui forment des symboles ogham)
- **Foret = reseau neuronal** (branches = connexions, feuilles = data)
- **Magie = computation** (sorts = requetes, enchantements = compilations)
- **Merlin = processeur ancestral** (barbe = cables, yeux = ecrans, baton = antenne)

### 10.2 Palette

| Zone | Couleur | Hex | Usage |
|------|---------|-----|-------|
| Fond terminal | Noir profond | #0A0A12 | Background par defaut |
| Texte principal | Vert terminal | #00FF88 | Texte narratif, labels |
| Accent chaud | Ambre druide | #FFB347 | Highlights, or, feu |
| Accent froid | Cyan liminal | #00D4FF | Eau, brume, passage |
| Danger | Rouge rune | #FF3366 | Degats, alertes |
| Rare/special | Violet chaos | #9B59FF | Korrigans, chaos, magie |
| Neutre/UI | Gris pierre | #3A3A4A | Bordures, separateurs |

### 10.3 Elements visuels

| Element | Style |
|---------|-------|
| **Table du Druide** | Bois ancien avec circuits incrustes, traces lumineuses |
| **Cartes** | Parchemin-ecran, texte en police monospace, bordures rune-circuit |
| **Merlin** | Silhouette encapuchonnee, yeux brillants, sprite anime 2D |
| **Fond 3D** | Low-poly stylise, shader CRT optionnel, parallax 3 couches |
| **Rune-Circuits** | Icones vectorielles (SVG) avec glow anime |
| **HUD** | Terminal-style, minimaliste, vert sur noir |

### 10.4 Shaders existants

| Shader | Fichier | Usage v3.0 |
|--------|---------|-----------|
| CRT Terminal | `shaders/crt_terminal.gdshader` | Overlay HUD optionnel |
| Whisper Glitch | `shaders/whisper_glitch.gdshader` | Interferences de Merlin |
| Palette Swap | `shaders/palette_swap.gdshader` | Changement de biome |
| Iridescent Border | `shaders/iridescent_border.gdshader` | Bordures cartes rares |
| Pixelate | `shaders/pixelate.gdshader` | Transitions de scene |

### 10.5 Typographie

- **Narratif** : Police serif fantasy (Almendra, MedievalSharp)
- **UI/HUD** : Monospace (JetBrains Mono, Fira Code)
- **Merlin** : Italique legere, couleur variable selon tier

---

## 11. HUD & UI

### 11.1 Table du Druide (ecran principal)

```
+------------------------------------------------------------------+
|                    [BIOME 3D PARALLAX]                             |
|                    (arriere-plan anime)                            |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |                                                                | |
|  |  [Merlin sprite]  "Texte de Merlin..."           [PV ####--]  | |
|  |                                                                | |
|  |  +--------+  +--------+  +--------+                           | |
|  |  | CARTE  |  | CARTE  |  | CARTE  |                           | |
|  |  | Opt 1  |  | Opt 2  |  | Opt 3  |                           | |
|  |  +--------+  +--------+  +--------+                           | |
|  |                                                                | |
|  |  [Rune: Beith]  [Promesse 1/2]  [Essence: 12]  [Carte #7]    | |
|  +--------------------------------------------------------------+ |
+------------------------------------------------------------------+
```

### 11.2 Elements HUD

| Element | Position | Info |
|---------|----------|------|
| Vie | Haut-droit | Barre + chiffre |
| Rune-Circuit actif | Bas-gauche | Icone + cooldown |
| Promesses | Bas-centre | Icones + countdown |
| Essence | Bas-droit | Chiffre |
| Merlin | Gauche | Sprite + bulle |
| Carte # | Haut-gauche | Numero dans le run |

---

## 12. Audio

### 12.1 Musique

| Contexte | Style |
|----------|-------|
| Hub | Ambient celtique + drones electroniques |
| Run (Table) | Tension progressive, layers dynamiques |
| Challenge | Montee en intensite rapide |
| Fin victoire | Triomphant, harpe + synthwave |
| Fin mort | Sombre, reverb, decroissance |

### 12.2 SFX (SFXManager existant, 30+ sons)

Sons additionnels v3.0 :
- Carte glissee sur la table
- Interference Merlin (glitch audio)
- Rune-Circuit active (charge electrique + rune)
- Rune Gambit (pose de rune, resolution)

---

## 13. Tutoriel & Onboarding

### 13.1 Premier run (scripte)

| Carte | Enseignement |
|:---:|-------------|
| 1 | Merlin se presente. Explique qu'il est "un programme tres ancien" |
| 2 | Premiere carte : 3 options. Explique le choix. Challenge = Minigame simple |
| 3 | Drain de vie explique. Merlin commente le score |
| 4+ | LLM prend le relais. Merlin cesse les explications |

### 13.2 Decouverte progressive

| Element | Quand |
|---------|-------|
| Rune-Circuits | Run 2 (apres achat dans Grimoire) |
| Rune Gambit | Run 3 |
| Oracle Reading | Run 4 |
| Merlin Judges | Run 5 |
| Interferences | Run 5+ (Merlin commence a tricher) |
| Input libre | Run 6+ (premiere carte Merlin Direct avec input) |

---

## 14. Systemes SUPPRIMES (v2.4 -> v3.0 -> v3.1)

| Systeme | Raison | Version |
|---------|--------|---------|
| **Drain de vie automatique -1/carte** | **HoF2-style : equilibre via card effects uniquement** | **v3.1** |
| Pipeline etape 1 DRAIN | Supprimee, pipeline desormais 11 etapes | v3.1 |
| Marche 3D on-rails Broceliande | Filler couteux, remplace par plateau Table v7.7.2 | v3.0 |
| 14 minigames | Surcharge, reduit a 4 types x 6 minigames | v3.0 |
| 18 Oghams chiffres | Surcharge cognitive, reduit a 9 Rune-Circuits | v3.0 (refacto code en cours) |
| Monnaie biome specifique | Confusion, remplace par Essence universelle | v3.0 |
| Collecte 3D (clic au sol) | Supprime avec la marche 3D | v3.0 |
| Arbre de talents | Remplace par Grimoire | v3.0 |
| 8 champs lexicaux | Simplification du routing | v3.0 |
| 45 verbes liste fermee | Narrator plus libre | v3.0 |
| Judge 0.8B | Integre dans le GM 2B | v3.0 |
| Calendrier/Periodes bonus | Pas dans la demo | v3.0 |
| Festivals saisonniers | Reporte post-v1 | v3.0 |
| Bestiole/Compagnon | Supprime depuis v2.0 | v2.0 |
| Triade/Souffle/4 Jauges | Supprime depuis v2.0 | v2.0 |

**v3.1 NOTE** : la mention "5 Factions reduit a 3 Poles" de v3.0 est **annulee**. Les 5 Factions (druides/anciens/korrigans/niamh/ankou) restent canon en v3.1 — alignement avec le code v7.7.3 et le pool FastRoute 810 cards.

---

## 15. Scene Flow

### 15.1 Flow demo

```
IntroCeltOS -> MenuPrincipal -> [SelectionSauvegarde] -> MerlinCabinHub
    -> [Choix biome + Rune-Circuit] -> DruidTable (NOUVELLE SCENE)
    -> [Run complet] -> EndRunScreen -> MerlinCabinHub
```

### 15.2 Scenes

| Scene | Role |
|-------|------|
| IntroCeltOS | Boot animation cyber-druidique |
| MenuPrincipal | Menu + options |
| MenuOptions | Parametres |
| SelectionSauvegarde | Profil unique |
| MerlinCabinHub | Hub central (dialogue Merlin + Grimoire) |
| **DruidTable** | NOUVELLE — Scene de run (Table 2D + 3D parallax) |
| EndRunScreen | Recap fin de run |

### 15.3 Reconversion BroceliandeForest3D

L'ancienne scene 3D `BroceliandeForest3D` devient le **fond parallax** de DruidTable pour le biome Broceliande.

---

## 16. Regles detaillees & edge cases

### 16.1 Mort

- Vie = 0 apres tous les effets -> fin de run avec narration
- Merlin commente la mort
- Anam proportionnel : `base x min(cartes/30, 1.0)`
- Toujours une scene narrative, jamais un "game over" sec

### 16.2 Interferences + Rune-Circuits

- Saille (Detection) revele les interferences AVANT le choix
- Luis (Bouclier) bloque APRES la resolution (protege des effets, pas des interferences)

### 16.3 Score critique

- Reussite critique (95-100) : +5 PV bonus
- Echec critique (0-20) : -10 PV en plus des effets

### 16.4 Confiance — transitions

- T0 -> T1 : Merlin est surpris, moins hostile
- T3 : Merlin peut refuser de tricher
- T3 -> T2 : Merlin est decu

### 16.5 Cross-run memory (contexte LLM)

Le LLM recoit :
- Dernier run : resume JSON (choix, issue, Pole dominant)
- Confiance : tier + valeur
- Promesses : historique des 5 dernieres
- Tendances : Pole prefere, strategie dominante

---

## 17. Glossaire

| Terme | Definition |
|-------|-----------|
| **Anam** | Monnaie permanente (cross-run), du gaelique "ame" |
| **Antre** | Le hub de Merlin (MerlinCabinHub) |
| **Challenge** | Epreuve apres un choix (4 types) |
| **Confiance** | Relation joueur-Merlin, T0-T3 |
| **DruidTable** | Scene principale de run |
| **Essence** | Monnaie per-run universelle |
| **FastRoute** | Pool de cartes pre-generees (fallback) |
| **Grimoire** | Livre de progression meta |
| **Interference** | Manipulation de carte par Merlin |
| **MOS** | Merlin Omniscient System (cerveau central) |
| **Pole** | Axe de reputation (Ordre/Chaos/Liminal) |
| **Rune-Circuit** | Pouvoir du joueur (ex-Ogham) |
| **Rune Gambit** | Duel de runes joueur vs Merlin |

---

## 18. Implementation — Phases

### Phase 1 : Table Scene
Creer DruidTable (table 2D + fond 3D parallax + Merlin sprite + 3 slots cartes).

### Phase 2 : Challenge Router
Dispatcher vers les 4 types de challenges. Minigames simplifies (6 types).

### Phase 3 : Interference Engine
Systeme d'interferences de Merlin (slots par tier, types, detection via Saille).

### Phase 4 : Commentary System
Integration LLM pour les commentaires de Merlin a chaque action.

### Phase 5 : Grimoire + Meta
Grimoire interactif, Rune-Circuits store, progression cross-run.

### Phase 6 : Balance & Polish
Playtest, equilibrage des valeurs, polish UI/UX, SFX.

---

## 19. UI/UX Coherence Rules (STRICT — non-negotiable)

> **Ajout 2026-05-14** : per user feedback, les règles UI/UX doivent être **absolument logiques en tout point**. Le parcours du joueur doit être prévisible, sans surprise visuelle ou spatiale. Un **Visual Coherence Agent** est désigné comme gatekeeper pour toute modification UI/3D.

### 19.1 Layout canonique du plateau (BoardNarration)

Vue caméra wide à (0, 2.6, 4.6) regardant (0, 0.4, 0) :

```
              [TOP / BACK — Z négatif (loin de la caméra)]
                  ┌──────────────────────────┐
                  │  Dice tray + ustensiles  │  ← Z = -1.4 (en HAUT)
                  │                          │
                  │  ┌────────────────────┐  │
[LEFT (-X)]       │  │   PLATEAU CENTER    │  │     [RIGHT (+X)]
  Deck de pioche  │  │   (figurines line)  │  │  Deck de défausse
  (hauteur stack  │  │                     │  │  (hauteur stack
   ∝ N restants)  │  └────────────────────┘  │   ∝ N joués)
                  │                          │
                  │   (FRONT / camera side)  │
                  └──────────────────────────┘
                       LiveCard3D centrale
                       face caméra (Z = +2.8)
```

**RÈGLES STRICTES** :
- **Dés + ustensiles auxiliaires** = TOP/BACK du plateau (Z négatif). PAS à droite, PAS sur le plateau.
- **Deck de pioche** = LEFT-BACK. Hauteur = nb cartes restantes × spacing. Maigrit à chaque tirage.
- **Deck de défausse** = RIGHT-BACK (mirroir pioche). Hauteur = nb cartes jouées. Grossit à chaque RESOLVE_CHOICE.
- **LiveCard3D active** = centre, en avant (Z positif), face caméra. Élément focal.
- **Pions/Tokens narratifs** = sur le plateau (ring 1.4m, 8 markers).
- **HUD 2D** = top-left (vie+anam), top-center (acte), top-right (carte X/5).
- **Pas de parchemin overlay 2D** en live mode — tout texte sur LiveCard3D.

### 19.2 Règles de cohérence narrative

- **Causalité visible** : chaque action joueur → réaction visuelle dans la seconde.
- **Pas de répétition narrative** : LLM ne re-génère pas une carte déjà jouée dans le run.
- **Vocabulaire cohérent** : termes Anam/Ogham/faction strictement selon glossaire §17.
- **Pas de jargon technique exposé** : "modifier"/"buff"/"stat" → termes druidiques.

### 19.3 Règles de progression visuelle

- **Stack heights proportional** : tout élément représentant une quantité (decks, life, anam) → représentation visuelle proportionnelle.
- **Drop choreography deterministe** : plateau → spotlight → fog → ustensiles → decks → cartes (ordre fixe).
- **One element at a time** : pas d'apparition simultanée. Délai 0.4-0.8s entre steps.

### 19.4 Visual Coherence Agent — rôle

Agent dédié (à créer `.claude/agents/visual_coherence_auditor.md`) audite TOUTE modification de :
- `scripts/board_narration/*.gd`
- `scenes/BoardNarration.tscn`
- `scripts/ui/*.gd`

**Critères pass/fail** :
- ✅ Respecte layout canonique §19.1
- ✅ Aucune superposition non-intentionnelle
- ✅ Vocabulaire/causalité §19.2
- ✅ Stack heights/proportions §19.3
- ❌ Reject : objets parasites, labels superflus, casse la logique spatiale

### 19.5 Anti-patterns identifiés (déjà corrigés — à NE PAS reproduire)

1. **Floating labels superflus** ("Le destin penche", "Un présage", "+N vie") — supprimés. Toute nouvelle popup doit avoir une justification didactique.
2. **Objets parasites sur plateau** (trees/props à Z=-2.4 chevauchant cercle) — repoussés à Z=-4. Tout asset hors radius 1.4.
3. **Parchemin overlay 2D en live mode** — supprimé entièrement (v7.1). LiveCard3D porte tout le contenu carte ; l'incantation se tape dans `_narration_label` (bas écran, Label, pas de Panel).
4. **`modulate:a` sur MeshInstance3D** — property 2D inexistant en 3D. Use `material_override.albedo_color:a` + `TRANSPARENCY_ALPHA`.
5. **Texte Label3D non contenu dans la carte** — `width` doit être calibré à `(card_W - margin*2) / pixel_size`. Ne JAMAIS laisser `width=1000` avec `pixel_size≈0.003` (→ 3m de débordement sur carte 1.2m).
6. **Asset 3D sans outline noir + sans cel-shading** — viole la marque de fabrique (§20). Tout MeshInstance3D du plateau doit passer par `CelShadingManager.apply(node)`.

---

## 20. Identité Graphique — Low-Poly Flat + Outline Noir (MARQUE DE FABRIQUE)

> **Pivot 2026-05-15 part 18** — réponse user AskUserQuestion : style **Low-poly flat geometric** (Monument Valley / Alto / Tunic / Wind Waker HD), outline noir gardé en signature. v3.4 bible.
> **Historique** : v3.2 (2026-05-14) écrivait cel-shading toon. La marque de fabrique pivote vers low-poly flat. L'outline noir reste signature.

### 20.1 Règle absolue
**Tout asset 3D visible du joueur** (plateau, cartes, dés, pions, totems, figurines, props plateau, deck pioche, deck défausse, LiveCard3D, biome backdrop) **DOIT** combiner :

1. **Low-poly flat geometric** — géométrie peu dense, faces planes coloriées via **vertex colors per-face** (peints dans Blender Vertex Paint mode + Face Select), shading Gouraud (`SHADING_MODE_PER_VERTEX`) + Lambert diffuse, **spécular désactivé**. Pas de PBR, pas de texture albedo (sauf parchemin/grass procéduraux), pas de gradient continu — chaque face = 1 couleur uniforme. Références : Monument Valley, Alto's Odyssey, Tunic, Wind Waker HD.
2. **Outline noir épais** — contour silhouette en `Color.BLACK`, épaisseur 2-4 px à l'écran via inverted-hull (mesh dupliqué scale 1.015, cull FRONT, unshaded).

### 20.2 Anti-patterns interdits
- ❌ PBR / réalisme / textures photoréalistes → BANNI hors UI 2D.
- ❌ Diffuse Toon (banding paliers) → BANNI depuis v3.4 — pivot vers Lambert flat per-face.
- ❌ Outline gris foncé ou colorée → DOIT être pur noir `#000000`.
- ❌ Outline fine (< 2 px) ou variable selon distance non-contrôlée.
- ❌ Asset avec smooth normals interpolées entre faces (sape l'esthétique facettée).
- ❌ Texture albedo sur asset organique (arbre, dolmen, plateau) — utiliser vertex colors per-face.
- ❌ Spécular highlight visible (sape l'aplat) — `SPECULAR_DISABLED` obligatoire.

### 20.3 Workflow Blender (vertex colors per-face)
**Pipeline standard** (détaillé dans `docs/BLENDER_PIPELINE.md`) :
1. Modeler en low-poly (~50-300 tris par asset organique, jusqu'à 1000 pour structures).
2. **Edit Mode → Mesh → Normals → Average → Face Area** + **Shade Flat** (`Object → Shade Flat`) pour casser les smoothing groups.
3. **Vertex Paint Mode → Face Select** → peindre 1 couleur par face selon palette biome (bible §22).
4. Optionnel : custom normals via **Mesh → Normals → Set Custom Split Normals** pour fixer le lighting facetté propre.
5. Export GLB avec option **`Use Vertex Color: Active`** activée (workaround Blender 4.1+ qui exporte mal sinon — voir `external/godot-blender-exporter/`).

### 20.4 Implémentation Godot 4.5 (CelShadingManager — `scripts/board_narration/cel_shading_manager.gd`)
> **Note** : la classe garde son nom historique `CelShadingManager` pour préserver les 6 callers existants. La sémantique a pivoté v7.3 vers low-poly flat (bible v3.4).

**Two techniques combinées :**
1. **Flat material remap** : `StandardMaterial3D.shading_mode = SHADING_MODE_PER_VERTEX` (Gouraud rapide, lit faceté) + `diffuse_mode = DIFFUSE_LAMBERT` + `specular_mode = SPECULAR_DISABLED` + `vertex_color_use_as_albedo = true` (honore vertex paint Blender).
2. **Inverted-hull outline** : MeshInstance3D dupliqué scale 1.015, `cull_mode = FRONT`, unshaded noir pur, `render_priority = -1`. Inchangé depuis v7.1.

**API canonique** : `CelShadingManager.apply(mesh_instance: MeshInstance3D, opts: Dictionary = {})`.
Options :
- `outline_thickness: float` (default 0.015 = ~3 px à distance caméra plateau)
- `outline_color: Color` (default `Color.BLACK`)
- `skip_outline: bool` (default false) — assets décoratifs UI sans hull
- `skip_flat_remap: bool` (default false) — assets avec shader custom déjà flat

Le pipeline est appelé automatiquement par :
- `CardDeck3D._build_one_card_visual` + `_build_socle` → cartes empilées + socle
- `DicePhysics3D._build_one_die` + `_build_tray` → dés + tray pierre
- `LiveCard3D._build_card_mesh` → carte centrale Hand of Fate
- `NarrativePion3D._build_mesh` → pions de plateau
- `board_narration._build_plateau` (fallback procédural) + `apply_recursive(GLB plateau)` → cylindre/GLB plateau

### 20.5 Visual Coherence Agent — checklist v3.4
À chaque cycle dev, l'agent vérifie :
- [ ] **Outline noir présent** sur tout MeshInstance3D gameplay (sample 3 frames).
- [ ] **Vertex colors per-face** appliqués (pas de texture albedo sauf parchemin/grass procéduraux).
- [ ] **Shading_mode = PER_VERTEX**, `diffuse = LAMBERT`, `specular = DISABLED` sur tout StandardMaterial3D du plateau.
- [ ] **Pas un asset PBR isolé** au milieu d'assets low-poly flat (incohérence visuelle).
- [ ] **Épaisseur outline cohérente** entre assets (tolérance ±20%).
- [ ] **Pas de smooth normals** (Shade Flat appliqué dans Blender).
- [ ] **Pas de double-outline** (le hull invertit n'apparaît qu'une fois par mesh — marker `_CelOutline`).
- [ ] **Palette biome respectée** (bible §22 — chaque face d'asset utilise une couleur de la sous-palette de son biome).

---

## 21. UX Standards — Minimalisme + Évidence + Tactile/Desktop (NON-NÉGOCIABLE)

> **Décrété 2026-05-14 part 16** — toute décision de game design + UX passe par ces 4 piliers.

### 21.1 Les 4 piliers UX (à vérifier sur CHAQUE écran, CHAQUE action joueur)

1. **FACILE** — L'action attendue du joueur est réalisable en ≤2 gestes (tap/clic). Pas de double-validation, pas de menu en cascade, pas de modale qui en cache une autre.
2. **ÉVIDENT** — L'intention est lisible en <2 secondes sans tutoriel. Si un joueur doit demander "qu'est-ce que je fais ici ?", c'est un bug UX.
3. **MINIMAL** — Aucun élément UI sans rôle ACTIF dans la décision en cours. Tout panel décoratif, badge inerte, libellé redondant ou rectangle vide est BANNI. Le plateau 3D et la carte LiveCard3D portent le contenu ; l'overlay 2D porte uniquement HUD vital (vie, Anam, Carte X/Y).
4. **TACTILE + DESKTOP** — Toute zone interactive doit faire ≥44×44 px (cible tactile Apple/Google) et fonctionner identiquement à la souris. Pas de hover-only state (cf. §19 anti-pattern #3). Toute interaction doit avoir un retour visuel ≤100ms.

### 21.2 Anti-patterns interdits
- ❌ Panel 2D recouvrant le plateau 3D pour afficher du texte qui aurait pu tenir sur LiveCard3D
- ❌ Bouton < 44×44 px ou collé à un autre bouton (espacement < 8 px)
- ❌ Action critique en hover uniquement (mobile = pas de hover)
- ❌ Tutoriel pop-up qui interrompt le flow (préférer onboarding implicite par les premières cartes)
- ❌ Plus de 7 éléments UI simultanés visibles à l'écran (loi de Miller — surcharge cognitive)
- ❌ Toute information affichée 2× (HUD + LiveCard3D + narration label dit la même chose)
- ❌ Action qui requiert un clic puis un autre clic ailleurs pour confirmer (sauf destructive : abandonner run)

### 21.3 Checklist UX à chaque playthrough
- [ ] Plein écran à 1920×1080 : tout est lisible, aucun chevauchement
- [ ] Réduit à 1280×720 : tout est lisible, aucun chevauchement
- [ ] Cibles tap testées au curseur ≥44 px (test : zoomer pour vérifier la taille)
- [ ] Aucun élément UI hover-only : tout cliqué directement
- [ ] Joueur sait "que faire ensuite" sans réfléchir à chaque écran
- [ ] Pas plus de 7 affordances UI visibles simultanément
- [ ] Bouton skip/retour disponible et visible à TOUS les écrans non-finaux

### 21.4 Process obligatoire (game design + playthrough)
**Tout travail touchant au game design** (équilibrage, mécanique, écran, flow, carte, minigame, choix, effet, HUD, transition) DOIT déclencher la cascade :

```
Wave 1 (en parallèle) :
  - game_designer.md       → cohérence avec bible §1-§20
  - ux_flow.md             → flow et navigation
  - game_playtester.md     → simulation joueur (5 archétypes)

Wave 2 (séquentiel après wave 1) :
  - game_design_auditor.md → audit final contre les 4 piliers §21.1
```

L'agent `task_dispatcher.md` ajoute automatiquement cette cascade quand les mots-clés sont détectés :
*playthrough, jouer, playtest, game design, UX, parcours joueur, mécanique, balance, équilibrage, flow, écran, transition.*

### 21.5 Tactile/Desktop — compatibilité concrète
- **Input** : Tout `Button.pressed` doit fonctionner indifféremment au clic souris ET au tap tactile. Pas de logique différenciée `is_mouse` vs `is_touch` sauf pour gestures spécifiques (pinch zoom, swipe).
- **Layout responsive** : Préférer `anchor` + `offset` aux positions fixes en pixels. Éviter `custom_minimum_size` trop large (max 60% largeur écran).
- **Texte minimum** : `font_size = 16` en CanvasLayer, `pixel_size ≥ 0.0025` en Label3D. Outline systématique 4-8px noir pour contraste.
- **Police safe** : `font_color` clair sur fond sombre + outline noir. JAMAIS texte gris sur fond gris.
- **Gestes** : Tap = action principale. Long-press = action secondaire (info, abandon). Swipe = navigation (cartes suivantes, pages tutoriel). Pas de double-tap (confusion).

---

## 22. Palettes Adaptives par Biome (CANON COULEUR)

> **Décrété 2026-05-15 part 18** — réponse user AskUserQuestion : "Palette adaptive par biome (8 sous-palettes)".
> Chaque biome a sa palette dédiée avec règles communes : 4 couleurs principales + 1 accent doré universel `#d4a868` + 1 outline noir universel `#0a0500`.

### 22.1 Règle universelle (toute palette biome)
- **6 couleurs max** par palette : 4 narratives + 1 accent doré commun `#d4a868` + 1 black-outline `#0a0500`.
- **Contraste min entre voisines** : ΔV ≥ 0.15 en HSV (sinon les faces flat se confondent).
- **Saturation modérée** : S entre 0.25 et 0.65. Au-delà = clash avec parchemin LiveCard3D `#f0e2c4`.
- **L'accent doré** sert pour : runes ogham, glow d'objets gameplay, faction Druides accents, currency Anam.

### 22.2 Les 8 sous-palettes (hex codes finaux)

#### Brocéliande (foret_broceliande) — déjà installé v7.1, palette warm-mystic baseline
| Slot | Hex | Usage |
|------|-----|-------|
| Tree trunk | `#3d2817` | Arbres, bois dolmens |
| Foliage | `#4a6644` | Feuillage, mousse, herbes |
| Forest mist | `#5e4a32` | Brume entre arbres, sous-bois |
| Highlight | `#8a6a3a` | Rayons de lumière, branches éclairées |
| Accent doré | `#d4a868` | Runes, ogham, pollen |
| Outline | `#0a0500` | Silhouette |

#### Landes (landes_bruyere) — vent, bruyère, cairns
| Slot | Hex | Usage |
|------|-----|-------|
| Heather purple | `#6b4a72` | Bruyère, fleurs sauvages |
| Stone gray | `#7a7a72` | Cairns, rochers |
| Wind sky | `#a8b0b8` | Ciel battu, brume horizontale |
| Cool shadow | `#3a3848` | Ombres portées, Ankou wisps |
| Accent doré | `#d4a868` | — |
| Outline | `#0a0500` | — |

#### Côtes Sauvages (cotes_sauvages) — falaises, vagues, korrigans
| Slot | Hex | Usage |
|------|-----|-------|
| Cliff ochre | `#a87848` | Falaises, grès, roches émergées |
| Sea green | `#2c5060` | Eau profonde, varech, grottes |
| Foam white | `#d8e0d8` | Écume, mouettes, sable mouillé |
| Storm gray | `#4a5258` | Ciel orageux, brume marine |
| Accent doré | `#d4a868` | — |
| Outline | `#0a0500` | — |

#### Villages Celtes (villages_celtes) — feu, foyers, anciens
| Slot | Hex | Usage |
|------|-----|-------|
| Hearth ember | `#cd6438` | Foyer, lanternes, terre cuite |
| Thatch yellow | `#b89858` | Chaume, paille, paniers |
| Wattle brown | `#5a3c24` | Murs torchis, bois de charpente |
| Twilight blue | `#384858` | Ciel crépuscule, ombres villageoises |
| Accent doré | `#d4a868` | — |
| Outline | `#0a0500` | — |

#### Cercles de Pierres (cercles_pierres) — menhirs, runes, équinoxe
| Slot | Hex | Usage |
|------|-----|-------|
| Granite gray | `#6a6862` | Menhirs, dolmens, pierres dressées |
| Moss patina | `#586848` | Lichen sur pierre, mousse encaissée |
| Sky ritual | `#586a82` | Ciel d'équinoxe, lueur cérémonielle |
| Deep cold | `#2a3038` | Pénombre intérieure cercle, ombre rituelle |
| Accent doré | `#d4a868` | (runes ogham gravées) |
| Outline | `#0a0500` | — |

#### Marais Korrigans (marais_korrigans) — brume, will-o-wisps, tourbière
| Slot | Hex | Usage |
|------|-----|-------|
| Bog green | `#465840` | Eau stagnante, lentilles, tapis végétaux |
| Wisp pale | `#c0d8a8` | Will-o-wisps, lichen luminescent |
| Mire brown | `#3a2c1a` | Boue, tourbe, troncs morts |
| Mist veil | `#86887a` | Brume rampante, voile au sol |
| Accent doré | `#d4a868` | — |
| Outline | `#0a0500` | — |

#### Collines aux Dolmens (collines_dolmens) — collines vertes, ancêtres
| Slot | Hex | Usage |
|------|-----|-------|
| Hill green | `#5a7848` | Herbes hautes, pentes douces |
| Earth umber | `#7a5838` | Terre exposée, chemins, dolmens |
| Sky pastoral | `#a8b8c8` | Ciel ouvert, nuages doux |
| Ancient shadow | `#3a4030` | Ombres sous dolmens, sous-bois |
| Accent doré | `#d4a868` | — |
| Outline | `#0a0500` | — |

#### Îles Mystiques (iles_mystiques) — Niamh, fées, autre-monde
| Slot | Hex | Usage |
|------|-----|-------|
| Niamh azure | `#5a8aa8` | Eau enchantée, ciel féerique |
| Pearl light | `#e8e0d0` | Brume éclatante, écume sacrée |
| Fey violet | `#7a5a88` | Crépuscule féerique, fleurs anciennes |
| Mystic teal | `#3a6878` | Profondeurs translucides, ombres élégantes |
| Accent doré | `#d4a868` | — |
| Outline | `#0a0500` | — |

### 22.3 Source de vérité runtime
Les palettes sont exposées dans `scripts/board_narration/biome_palettes.gd` (à créer dans la prochaine phase d'implémentation). Le pipeline Blender (`docs/BLENDER_PIPELINE.md` §3) référence la palette du biome cible pour le Vertex Paint.

### 22.4 Anti-patterns palette
- ❌ Mélanger 2 palettes biome sur un même asset (sauf transition cross-biome explicite scriptée).
- ❌ Accent doré en aplat sur une face large — réservé aux runes/glow/petits éléments.
- ❌ Saturation > 0.65 → clash parchemin LiveCard3D.
- ❌ Couleur hors palette → tout asset DOIT picker dans les 6 slots de son biome.

---

## 23. Mood Mystique Chaleureux (LIGHTING + POST-PROCESS)

> **Décrété 2026-05-15 part 18** — réponse user AskUserQuestion : "Mystique chaleureux (Hand of Fate 2 campfire / Spiritfarer)".

### 23.1 Lighting setup standard (BoardNarration)
- **Key light** : DirectionalLight3D, `light_energy = 1.4`, couleur `#f0c878` (warm amber), direction `(0.3, -0.8, 0.5)`.
- **Spot light** : SpotLight3D centré plateau, `light_energy = 2.0`, couleur `#ffe8b0` (foyer chaud), cone 30°, atténuation 1.5.
- **Ambient** : Color `#3a2818` (warm dark brown), `ambient_light_energy = 0.35` — pas trop sombre, on est au coin du feu, pas dans un donjon.

### 23.2 Volumetric fog (Forward+)
- `volumetric_fog_density = 0.012`
- `volumetric_fog_albedo = #cba88c` (warm haze, pas grise)
- `volumetric_fog_emission = #4a3018`, `volumetric_fog_emission_energy = 0.08`
- **Anti-pattern** : fog gris/froid (`#a8a8a8`) → DROP, casse le mood mystique chaleureux.

### 23.3 Post-process
- **Bloom** : `glow_enabled = true`, `glow_intensity = 0.25` (subtle, pas blow-out), `glow_threshold = 1.05`.
- **Color grading** : warm shift via `WorldEnvironment.adjustment_color_correction` → courbe `Color(1.05, 0.98, 0.92)` (chaud).
- **Vignette** : `glow_bicubic_upscale = true` + dim corners via tonemap.
- **PAS de scanlines / CRT** dans BoardNarration (réservé à CeltOS boot scene).

### 23.4 Mood checklist
- [ ] **Pas de zone trop sombre** où le joueur ne distingue plus les options (test à 1280×720 minimum).
- [ ] **Pas de cool tint** sur les biomes warm (Brocéliande, Villages, Collines).
- [ ] **Bloom contrôlé** : sur les points de lumière (foyer, runes), pas sur le ciel entier.
- [ ] **Volumetric fog respire** : densité variable selon la profondeur, pas un wall opaque.
- [ ] **Cohérence inter-biome** : chaque biome ajuste la teinte mais garde le warm ambient baseline.

### 23.5 Références visuelles
- **Hand of Fate 2** — night campfire, cards lit by ember.
- **Spiritfarer** — soft warm volumetric haze, cozy mystic.
- **Outer Wilds** — campfire at the foot of an alien sun (mood archetype).

---

*GAME_DESIGN_BIBLE v3.0 — M.E.R.L.I.N. : Le Jeu des Oghams*
*Refonte majeure 2026-05-09 — Inscryption x AI Dungeon x Cyber-Druidique*
*v3.1 (2026-05-14) — §19 UI/UX Coherence Rules added*
*v3.2 (2026-05-14) — §20 Cel-Shading + Outline Noir : marque de fabrique du jeu*
*v3.3 (2026-05-14) — §21 UX Standards : Minimal/Évident/Tactile+Desktop + cascade obligatoire game design*
*v3.4 (2026-05-15) — §20 pivot Low-Poly Flat + §22 palettes adaptives 8 biomes + §23 mood mystique chaleureux*
*v3.5 (2026-05-16) — HoF2-style no-drain + pipeline 11 etapes + plateau-only v7.7.2 + §24 Politique Systematique MERLIN*

---

## 24. Politique Systematique MERLIN (NON-NEGOCIABLE)

> **Source** : 15 reponses AskUserQuestion 2026-05-16. **Enforced** par CLAUDE.md §10 + hook UserPromptSubmit.

Toute session de travail sur le projet MERLIN suit ce protocole strict :

### 24.1 Bible-first ritual (debut de session)

Au debut de **chaque** session MERLIN, l'agent **DOIT** :

1. Lire `docs/GAME_DESIGN_BIBLE.md` sections §1-§24 AVANT toute action de code ou de design
2. Verifier la coherence du contexte courant avec la bible (factions, oghams, pipeline, MOS, flow scene)
3. En cas de divergence detectee : flag immediat + AskUserQuestion de reconciliation

**Exception** : prefixes `*` `/` `!` bypass. Sessions de pur debug (no design decision) peuvent skip si bypass explicite.

### 24.2 AskUserQuestion cadence

| Complexite | Comportement |
|------------|--------------|
| TRIVIAL | Action directe, pas de questions |
| **SIMPLE+** | **4 questions obligatoires** avant action |
| **MODERATE** | **8-12 questions multi-round** obligatoires |
| **COMPLEX** | **16+ questions multi-round** obligatoires |

Les longues sessions multi-round suivent le pattern : R1 (divergences fondamentales) → R2 (implications) → R3 (decisions pending) → R4 (politique). Bypass via prefixe `*`.

### 24.3 Bible update cadence

**Per-feature complete** : a chaque feature complete (groupe de commits formant une unite), update les sections impactees de la bible + bump version (v3.5 → v3.6 → ...).

Trigger : la feature touche un mecanisme listé dans §1-§24 (game loop, factions, oghams, pipeline, MOS, scene flow, UI, audio, lore).

### 24.4 Coherence code ↔ bible

| Bible v3.5 canon | Code v7.7.3 etat | Action |
|---|---|---|
| 5 Factions | OK (matchant) | aucune |
| 9 Rune-Circuits | 18 Oghams chiffres | **refacto a faire** (~6h) |
| No drain auto | LIFE_ESSENCE_DRAIN_PER_CARD = 1 | **refacto a faire** (constant = 0) |
| Pipeline 11 etapes | EFFECT_PIPELINE 12 etapes | **refacto a faire** (drop step 1) |
| MOS 8/20-25/50 | OK | aucune |
| 5 actes × 5 cartes | ACT_SEQUENCE [standard/shop/standard/event/boss] | OK |
| MOS HUD "Carte X/25" | non implemente | **a ajouter** |
| Card flip | non implemente | **a ajouter** (Phase 2 backlog) |
| asset_spawn_animator | non extrait | **a faire** (cascade refacto SigleToken) |
| Merlin speech-bar + TTS | non implemente | **a ajouter** (Phase 2.1.5/2.1.6 backlog) |

### 24.5 Cascade obligatoire game-design (rappel §21.4)

Toute touche au game design declenche la cascade :
- **Wave 1 parallele** : `game_designer.md` + `ux_flow.md` + `game_playtester.md`
- **Wave 2 sequentielle** : `game_design_auditor.md`

### 24.6 Test sessions canonical (10 sessions reference)

Pour zero angle mort, executer regulierement les 10 sessions de reference identifiees 2026-05-16 :
S1 Onboarding, S2 Boot Stability, S3 Run Abandon, S4 LLM Disconnect, S5 Mid-Run Tension, S6 Cross-Run Memory, S7 Long Session FPS, S8 Tactile Accessibility, S9 Visual Coherence, S10 Save Corruption.

Detail : voir `task_plan.md` Active Feature v7.7.3.

---

*Fin de bible v3.5*
