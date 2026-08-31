# Changelog

Toutes les versions notables de driven. Format [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
versionnage [SemVer](https://semver.org/lang/fr/). Pré-1.0 : le mineur peut casser
l'interface d'installation, le patch jamais.

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
