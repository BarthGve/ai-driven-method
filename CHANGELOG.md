# Changelog

Toutes les versions notables de driven. Format [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
versionnage [SemVer](https://semver.org/lang/fr/). Pré-1.0 : le mineur peut casser
l'interface d'installation, le patch jamais.

## Non publié

### Ajouté
- `.dm/lib/dm-witness.sh <nom> -- <commande>` : saute un contrôle déjà passé par ce contenu
  exact (fichiers suivis et non ignorés ; `docs/reviews` et `docs/plans` exclus). La revue
  et `/dm-ship` ne relancent plus la suite complète quand le code n'a pas bougé.
- Section `## Checks` dans `AGENTS.md` (remplie par `/dm-architect`) : `focused` pendant une
  tâche, `fast` et `full` avant le commit du ticket, `ci` jamais lancé par un agent.

- `tests/references.test.mjs` : échoue si la prose cite un template, un script `.dm/lib`,
  une commande `/dm-*`, un agent ou un skill qui n'existe pas.

### Modifié
- Revue en rounds : chaque `/dm-review` ajoute un `## Round <n>` à
  `docs/reviews/<story>/<ticket>.md` sans réécrire les précédents ; le round suivant vérifie
  que chaque constat critique ou majeur est corrigé. `dm-gate.sh`, `/dm-ship`, `/dm-execute`
  et `/dm-status` lisent le **dernier** verdict.
- Descriptions des commandes, skills et agents : « Use when… / Not for… », pour que Codex
  déclenche le bon skill et renvoie vers la commande voisine.
- `tdd-skill` : tests ciblés à chaque tâche et pour les mutations ; suite complète une seule
  fois, avant le commit du ticket. `quality-bar` : mutations du reviewer sur les fichiers ciblés.
- Chargement à la demande : les chemins canvas et brief de `/dm-design` passent dans
  `templates/design-path-*.md`, lus seulement quand ce chemin est choisi.

### À savoir
- Revues existantes : un fichier sans `## Round` reste lu (dernier `Ship allowed:`) ; le
  prochain `/dm-review` y ajoute le round 2. Relance `./install.sh --hooks` : les anciens
  hooks de `.dm-hooks/` acceptent n'importe quel `Ship allowed: yes` du fichier, même suivi d'un `no`.
- `AGENTS.md` n'est jamais écrasé : ajoute la section « Checks » à la main dans les projets existants.
- `dm-witness.sh` n'est pas dans `--permissions` : il exécute la commande qu'on lui passe,
  l'autoriser reviendrait à autoriser n'importe quelle commande.
  Une règle `Bash(npm test:*)` ne couvre plus l'appel : autorise la commande exacte, par
  exemple `Bash(bash .dm/lib/dm-witness.sh full -- npm test)`.
- Le gain n'arrive dans un projet existant qu'une fois `.dm/lib` à jour commité sur `next` ;
  sans le script, les agents lancent la commande directement.

## 0.6.0 — 2026-10-08

### Ajouté
- `install.sh --permissions` (opt-in) — fusionne `src/permissions.txt` dans `.claude/settings.json` :
  les commandes `/dm-*` n'attendent plus d'approbation pour `bash .dm/lib/dm-*.sh` ni pour
  écrire dans `docs/`. Scripts listés un à un, aucun accès en écriture à `.dm/`. `uninstall`
  retire ces règles et seulement elles.
- `.dm/lib/dm-port.sh` — port stable par worktree (20000-29999). Règle « Ports » dans
  `AGENTS.md` : serveurs, e2e et vérifs navigateur lancés par un agent n'utilisent plus le
  port du serveur de dev.

### À savoir
- `AGENTS.md` n'est jamais écrasé : fusionne la règle « Ports » à la main dans les projets existants.

## 0.5.0 — 2026-08-31

### Ajouté
- `/dm-continue` — porte d'entrée brownfield : baseline produit dans `docs/onboarding.md`
  et mapping des Issues déjà écrites, sans rien muter. La conversion est appliquée plus
  tard par `/dm-stories`, une confirmation par Issue.
- `/dm-feature <slug>` — feature sur un produit déjà livré : cadrage, amendement du PRD
  (section `## Amendements`), stories ajoutées au backlog. L'impact architectural est
  décidé par une énumération, pas au jugé.
- `issue-adopt` dans `dm-board.sh` — adopte une Issue écrite à la main. `status-set` ne
  pouvait pas le faire : il résout un *project item*, et une Issue manuelle n'en est pas un.
- Voie canvas dans `/dm-design` — sur Claude Code, `/design` dessine les artboards en
  session dans `docs/designs/<id>.dc.html`. Codex et Grok gardent l'aller-retour par brief.
- `install.sh uninstall [--dry-run]` — retire exactement ce que `.dm-manifest` liste.
- `install.sh --profile full|framing|delivery` — sous-ensembles cohérents de commandes.
  Table dans `src/profiles.txt`. Skills et agents jamais filtrés.
- Prompts interactifs dans `install.sh`, sur `/dev/tty` et uniquement si stdout est un
  terminal — `curl | bash` et CI se comportent comme avant.
- `tests/install.test.mjs` — l'installeur n'avait aucun harnais.
- `VERSION` et ce changelog : driven versionne enfin ses propres livraisons.

### Corrigé
- **Injection de script dans `src/workflows/dm-gate.yml`** : `${{ github.head_ref }}` était
  interpolé dans des blocs `run:`. GitHub substitue avant que bash parse, donc une PR
  depuis un fork avec une branche nommée `feature/x$(...)` exécutait du code sur le runner.
  Les refs passent maintenant par `env:`. Le workflow est copié dans chaque repo applicatif
  par `/dm-init`, le défaut s'y propageait.
- **Fuite de token dans `src/lib/dm-wiki.sh`** : le token était dans l'URL de clone, donc
  visible dans `ps` et persisté dans `.git/config` par `git remote add`. Il passe par un
  credential helper lisant l'environnement. La liste des helpers est réinitialisée d'abord,
  car `-c credential.helper=X` empile au lieu de remplacer.
- `/dm-orchestrator` envoyait tout projet sans PRD vers `/dm-prd`, y compris un repo plein
  de code existant. Il applique désormais le prédicat de `/dm-status`.

### Modifié
- `install.sh` estampille la version sémantique dans `.dm-version`, plus un SHA git.
- `/dm-prd` accepte un troisième mode : brownfield.
- Le skill `stories-review` juge aussi une feature contre le produit déjà livré :
  duplication de travail livré, dépendance non livrée, contradiction avec la production.
