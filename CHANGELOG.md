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
- `.dm/lib/dm-quota.sh` : quota GitHub restant (GraphQL et REST), sans en consommer. Le quota
  est par compte : toutes les sessions et apps qui utilisent `gh` y puisent.
- `dm-board.sh status-all` : le statut de toutes les issues driven en une lecture.
- `tests/references.test.mjs` : échoue si la prose cite un template, un script `.dm/lib`,
  une commande `/dm-*`, un agent ou un skill qui n'existe pas.
- Ligne `isolation` dans `## Checks` (remplie par `/dm-architect`) : base, schéma, index
  Redis ou préfixe de file propres à chaque worktree de ticket, nommés d'après `dm-port.sh`.
  `worktree-manager` l'applique à la création, `/dm-ship` lance le teardown au nettoyage.
  Deux tickets en parallèle ne verrouillent ni ne vident plus la même base de test.

### Modifié
- L'US suit ses tickets : chaque `status-set` sur un ticket recalcule son US, dans la même
  lecture du board. Avant, seul `/dm-ship` le faisait, et l'US restait en `backlog` pendant
  que ses tickets avançaient. Un ticket `ready` compte désormais : l'US passe `in progress`.
  `/dm-status` signale une US décalée (ticket déplacé à la main sur GitHub) et donne la
  commande `parent-sync`. `/dm-release` ne pose plus l'US à la main : elle passe `shipped`
  avec son dernier ticket.
- `/dm-init` utilise le champ `Status` natif du Project : ses options (Todo, In Progress,
  Done) sont remplacées par `backlog | ready | in progress | test | shipped`. Il ne crée plus
  de champ « DM Status ». Les projets existants qui en ont un continuent de fonctionner :
  `dm-board.sh` lit le champ indiqué par `status_field_id`.
- `AGENTS.md` réduit à ce qui sert à chaque session (139 → 68 lignes, ~1 700 → ~600 mots) :
  règle absolue, Quick Fix, branches et dossiers, ids, stratégie de ship, conventions,
  Checks. Le reste vit dans la commande ou l'agent qui l'applique (ports et design system
  dans `implementer`, isolation dans `worktree-manager`, jours restants dans `/dm-status`,
  ADR immuables dans `/dm-architect`, commit des docs de story dans `/dm-docs`). Un test
  plafonne sa taille. Les projets déjà installés gardent leur `AGENTS.md` (jamais réécrit).
- `dm-witness.sh` nomme les fichiers que la commande a modifiés quand il n'enregistre pas
  le passage (`coverage/`, `test-results/`…). Sans ce tampon, la revue et `/dm-ship`
  relançaient la suite complète. L'implementer les ajoute au `.gitignore`, le reviewer en
  fait un constat mineur.
- Revue en rounds : chaque `/dm-review` ajoute un `## Round <n>` à
  `docs/reviews/<story>/<ticket>.md` sans réécrire les précédents ; le round suivant vérifie
  que chaque constat critique ou majeur est corrigé. `dm-gate.sh`, `/dm-ship`, `/dm-execute`
  et `/dm-status` lisent le **dernier** verdict.
- Descriptions des commandes, skills et agents : « Use when… / Not for… », pour que Codex
  déclenche le bon skill et renvoie vers la commande voisine.
- `dm-board.sh` lit la liste des issues une seule fois par appel (`parent-sync` en faisait
  2 à 3). `/dm-status`, `/dm-release` et `/dm-orchestrator` lisent le board une fois avec
  `status-all` au lieu d'un `status-get` par story ou ticket.
- `tdd-skill` : tests ciblés à chaque tâche et pour les mutations ; suite complète une seule
  fois, avant le commit du ticket. `quality-bar` : mutations du reviewer sur les fichiers ciblés.
- Chargement à la demande : les chemins canvas et brief de `/dm-design` passent dans
  `templates/design-path-*.md`, lus seulement quand ce chemin est choisi.

### Corrigé
- `dm-board.sh` lit le statut dans le Project configuré (`project_id`) et sur le champ
  configuré (`status_field_id`). Il prenait le premier Project de l'issue et son champ
  « Status » par défaut : faux dès qu'une issue est dans deux Projects, ou quand `/dm-init`
  a créé un champ « DM Status » (`status-set` échouait avec « no project item id »).
  Une seule requête GraphQL paginée, 100 éléments par point.
- Liste du board tronquée : GitHub renvoie parfois moins d'éléments que `totalCount` sans
  erreur. Relecture bornée (3 essais), puis échec explicite au lieu d'un faux « not found ».
- Sécurité : `dm-config.sh` entoure les valeurs de `.dm/config.json` d'apostrophes. Avec des
  guillemets doubles, une valeur contenant `$(…)` ou des backticks était exécutée.
  Ces trois correctifs viennent du projet lagarde.
- `dm-board.sh` ne lisait que 200 issues : au-delà, un ticket devenait « issue not found ».
  Il lit désormais tout le board, page par page, sans limite.

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
