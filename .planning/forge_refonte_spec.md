# Forge Refonte Spec — Lance & Oublie

**Date**: 2026-05-09
**Source**: 8 user answers via AskUserQuestion (this session)
**Status**: spec verrouillé, attente go pour implémentation
**Scope**: refonte complète du shell UI Octogent web

---

## Persona & workflow primaire

**Persona** : utilisateur "Lance + oublie".
**Cycle quotidien** :
1. Ouvre `http://localhost:8787`
2. Clique LIGHT THE FORGE (1 bouton)
3. Ferme l'onglet
4. 4-8h plus tard, ré-ouvre, voit ce qui a été commit
5. Si rouge dans la pill → click + investigation drawer

**Aucune intervention en cours de route attendue.** Toute friction = bug à fixer.

---

## Architecture UI (radicale)

### Single-screen layout, no tabs

Les 8 onglets actuels (AGENTS / DECK / ACTIVITY / CODE INTEL / MONITOR / CONVERSATIONS / PROMPTS / SETTINGS) sont **TOUS RETIRÉS** de la nav UI. La route `/` rend une vue unique. Routes profondes (`/deck`, `/monitor`, etc.) ne sont plus exposées dans la barre — elles peuvent rester accessibles via URL directe pour debug, mais pas via UI navigation.

### Above-the-fold (no scroll)

Trois zones empilées verticalement, lisibles sans scroller à 1080p :

```
┌─────────────────────────────────────────────────────────┐
│ HEALTH PILL : 🟢 FORGE OK · 4 active · 0 stuck · 12 commits/24h │  ← 32px
├─────────────────────────────────────────────────────────┤
│                                                         │
│        [ ▶ LIGHT THE FORGE ]                            │  ← gros bouton
│              started 1h 23m ago                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ ACTIVE TERMINALS (4)                                    │
│  ▸ studio_director · running · "audit visuel scenes"    │
│  ▸ swarm-3 · running · "fix MenuOptions null refs"      │
│  ▸ swarm-7 · processing · "build EssenceCaption Label"  │
│  ▸ godot_runtime · idle · "verify_all next cycle"       │
└─────────────────────────────────────────────────────────┘

                                                  [ + ]   ← floating, bottom-right
```

**Pas de** : sparkline, claude usage rails, mini-charts, octopus deck, conversations list, prompts library, monitor heatmap. Toutes ces vues sont supprimées du chrome principal.

---

## Bouton LIGHT THE FORGE — ON/OFF unique

- **Une seule action** : start ou stop. Pas de slider workers, pas de dropdown cible, pas de settings.
- État `idle` : bouton vert "▶ LIGHT THE FORGE".
- État `running` : bouton rouge "■ DOUSE THE FORGE" + label "started Xm ago".
- Workers count fixe : 9 (DEFAULT_WORKER_COUNT existant en code).
- Bypass permissions : forcé `true` (déjà fait commit 3341b7d0).

---

## Health pill — agrégation visible

Position : top-left, height 32px.

**Format compact** :
```
🟢 FORGE OK · 4 active · 12 commits/24h
🟡 DEGRADED · 0 active · 2 stuck-permission · last verify 1h ago
🔴 FORGE DOWN · API unreachable · auto-recovery in progress
⚪ checking...
```

Clickable → ouvre incident drawer (read-only timeline des derniers events).

---

## Auto-recovery silencieuse — 3 retries × 5min

Quand DOWN ou DEGRADED détecté :
1. **Retry 1** (immédiat): kill zombies + restart Octogent + re-spawn workers.
2. **Retry 2** (après 5min): même si DEGRADED persiste.
3. **Retry 3** (après 5min): dernier essai.
4. **Si encore fail après 15min** : pause auto-mode + push browser notification + freeze. Attente click utilisateur.

Pas de log visible utilisateur sauf via incident drawer.

---

## Persistence — server-side

- Auto-mode tourne **côté Octogent** (watchdog + tentacles + claude PTYs).
- Browser fermé → aucun impact.
- Re-ouverture browser → snapshot de l'état actuel.
- Hard-stop server-side : 24h max (watchdog `MAX_HOURS` existant). Reset au prochain LIGHT THE FORGE.

---

## Alertes

**Badge in-app** : pill change couleur. Polling 8s (existant).

**Push browser HTML5** :
- DEGRADED >15min OU recovery échec après 3 retries → notification.
- Permission demandée à la 1ère ouverture (`Notification.requestPermission()`).
- Title: "MERLIN Forge", body: "Action required — DEGRADED 15m" + click → focus tab.
- Pas de spam : max 1 notif / état dégradé / 1h.

**PAS de webhook** Discord/Slack ni email/SMS dans cette première itération (peut être ajouté plus tard via n8n MCP en option settings).

---

## Sessions Claude manuelles — drawer xterm.js

**Trigger** : bouton flottant `+` en bas à droite.

**Comportement** :
- Click `+` → drawer right-side glisse depuis la droite (60% width).
- Drawer contient terminal xterm.js attaché à un nouveau worker spawn (claude-code, bypass=true, workspaceMode=shared).
- Drawer header : terminal-id + "kill" + "close" buttons.
- Esc ou click en dehors = ferme drawer (worker continue server-side).
- Multiple drawers : non supporté (1 seul ouvert à la fois). Click `+` pendant qu'un drawer est ouvert = remplace par le nouveau.

**Pas de spawn-via-click-on-worker** (l'utilisateur a explicitement choisi le bouton + uniquement).

---

## Style visuel — push thématique

**Direction** : forge MERLIN immersive, pas utilitaire plat.

**À ajouter** :
- **Grain papier subtil** : background-image SVG noise très léger sur les zones parchemin.
- **Typo gothique** sur titres principaux (FORGE OK, LIGHT THE FORGE) — Cinzel ou Cormorant Garamond.
- **Ember ambient** : 1-2 particules feu lentes en bottom-left (rappel forge), CSS-only, jamais > 1% CPU.
- **Mascot pixel** : conservé (déjà animé subtilement).
- **Palette** : forge-gold `#d6a21a` accent / phosphor `#7ec850` ok / amber `#faa32c` warn / `#d63a3a` danger / parchemin `#2d1f0f` bg.

**À retirer** : restes d'effets superflus (glows excessifs, pulse sur icônes secondaires) — l'immersion est dans la matière (papier/gold/ember), pas dans le mouvement.

---

## Phases d'implémentation (proposées)

### Phase A — Foundation (in flight, ~1 commit)

Déjà partiellement landé en `3341b7d0` :
- ✅ Health badge minimaliste (effets retirés)
- ✅ Bypass-by-default sur 4 spawn paths
- ✅ Smart-restart curl-first
- ✅ TIER 1.4 auto-repair tentacles.json
- ⏳ (build vient de finir, à committer) : agentProvider snapshot + stuckChip dans badge

### Phase B — Strip the chrome (~1 commit)

- Retirer la nav `ConsolePrimaryNav` (les 8 onglets).
- Retirer les 8 `PrimaryView*` du `PrimaryViewRouter`.
- App.tsx : route racine rend directement le SingleScreen.
- Tester : routes `/deck`, `/monitor`, etc. retournent 404 SPA fallback (acceptable).

### Phase C — SingleScreen layout (~2 commits)

- Nouveau composant `<SingleScreenForge />` avec 3 zones (badge / button / terminals).
- Réutilise `ForgeHealthBadge` + `StudioToggle` existants.
- Liste `ActiveTerminals` consomme `useTerminalSnapshots` (à créer ou réutiliser un hook existant).

### Phase D — Floating + button + drawer (~2 commits)

- `<SpawnDrawer />` avec xterm.js (déjà bundlé).
- Bouton flottant `+` `position: fixed; bottom: 24px; right: 24px;`.
- POST `/api/terminals` au click → attach drawer au new terminalId.

### Phase E — Auto-recovery 3-retry (~1 commit)

- Modifier `director-watchdog.sh` : compteur retries, pause après 3.
- Surface l'état "paused" dans la badge (nouveau `paused` state).

### Phase F — Push browser notifications (~1 commit)

- `useNotificationPermission` hook + `notifyOnDegraded` dans `useForgeHealth`.
- Throttle 1h.

### Phase G — Style thématique (~1-2 commits)

- Grain SVG noise + typo gothique title.
- Ember CSS particles (vanilla CSS, no JS lib).

### Phase H — Cleanup (~1 commit)

- Supprimer composants devenus dead (les 6 `*PrimaryView` non utilisés).
- Supprimer hooks now-dead (sparkline, claude usage charts).

**Total estimé** : ~10 commits, ~2-3 jours de travail focused.

---

## Risques connus

| Risque | Mitigation |
|---|---|
| Régression : SettingsPrimaryView contient des toggles encore lus par App.tsx (`isRuntimeStatusStripVisible` etc.) | Garder les hooks d'état, juste hide le composant. Settings reviendra plus tard si besoin via drawer. |
| Push browser nécessite HTTPS en prod (localhost OK) | OK pour usage local actuel. Documenter pour future déploiement. |
| Les xterm.js terminals ouverts par la prior UI peuvent persister hors drawer | Phase B kill all old views ; les terminals server-side restent réagissables via la liste. |
| Auto-recovery 3-retry trop agressif si pannes infra (réseau down) | Le watchdog distingue déjà "Octogent down" vs "Octogent slow". 3 retries = 15min, raisonnable. |
| Style thématique grain + ember peut nuire à la lisibilité | Toujours background-attachment: fixed + opacity ≤8%. Tester avant merge. |

---

## Validation

User a confirmé via 8 réponses AskUserQuestion. Spec considéré locked sauf retour explicite.

Prochaine étape : tu valides le scope global → on démarre Phase B (strip chrome) ou tu modifies des phases.
