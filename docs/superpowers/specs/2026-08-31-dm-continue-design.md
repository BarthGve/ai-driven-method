# `/dm-continue` — onboarding d'un projet existant dans le pipeline driven

Date: 2026-08-31
Statut: design validé, prêt pour plan d'implémentation

## Problème

driven cadre un produit avec `/dm-prd`, qui offre deux modes : cloner un SaaS
existant, ou greenfield. Les deux partent du produit, jamais du code. Un projet
déjà en cours — code qui tourne, Issues GitHub écrites à la main, aucun document
driven — n'a pas de porte d'entrée.

Ce qui est déjà couvert et ne doit pas être réécrit :

- `/dm-architect` applique la skill `codebase-analysis` et gère explicitement le
  cas « boilerplate ou code applicatif présent » : il analyse, se conforme, ne
  réécrit pas la stack.
- `/dm-init` est idempotent : remote, `next`, board, wiki, `VERSION` existants
  sont détectés, seuls les manques sont comblés.
- `/dm-stories` sait déjà ne pas recréer une Issue dont le titre porte le
  préfixe `[<story-id>]`.

Le trou réel est en amont : **reconstruire la baseline produit depuis un repo
existant, et raccrocher le backlog déjà écrit au format driven.**

## Décision de cadrage

Périmètre retenu : brownfield **et** import du backlog existant.

`/dm-continue` est un **orchestrateur mince**. Il produit un seul livrable neuf
puis enchaîne les commandes existantes. Il ne réimplémente ni le PRD, ni les
stories, ni l'architecture : ces templates évoluent, une seconde source de
vérité divergerait à la première modification.

## Contrainte d'ordonnancement (structurante)

Au moment où `/dm-continue` s'exécute, **le board n'existe pas** :

- `/dm-init` exige `docs/prd.md` (« Missing → STOP »), il ne peut donc pas
  précéder `/dm-prd` ;
- toute mutation board passe par `.dm/lib/dm-board.sh`, qui exige
  `.dm/config.json`, créé uniquement par `/dm-init`.

Conséquence : `/dm-continue` **ne peut pas** convertir d'Issue. Il ne peut que
proposer un mapping. L'exécution de la conversion est déportée dans
`/dm-stories`, qui tourne après l'init et possède déjà le point d'accroche.

Alternative écartée : commande en deux phases (`/dm-continue`, puis
`/dm-continue import` post-init). Plus de surface, une entrée de plus dans
`dm-help`, pour un gain nul — `/dm-stories` fait déjà le travail au bon moment.

**Correction post-lecture de `src/lib/dm-board.sh`.** Adopter une Issue écrite à
la main n'est pas un simple renommage : `cmd_status_set` résout sa cible via
`issue_project_item_id`, qui exige que l'Issue soit déjà un *project item*. Une
Issue créée à la main ne l'est pas. La bibliothèque sait pourtant le faire —
`add_issue_to_project_backlog` (item-add + backlog, avec retry) — mais c'est une
fonction shell privée, absente du dispatch de `main()`. `/dm-stories` a donc
besoin d'un sous-commande exposée : `issue-adopt <key> <number> <title>`, qui
réutilise la fonction existante. C'est le seul ajout de code shell du chantier.

Le mapping de `docs/onboarding.md` utilise des titres de section **en anglais**,
alignés sur la langue des command bodies, et traités comme des ancres
littérales : `/dm-stories` les grep tels quels, une traduction casserait le
relais en silence.

## Livrable neuf : `docs/onboarding.md`

**Product-level uniquement.** Contenu :

1. Ce que l'application fait aujourd'hui — boucle de valeur observée, utilisateurs.
2. Ce qui est déjà livré — la baseline, dérivée du code et de l'historique git.
3. Ce qui reste manifestement à faire — pistes, non contractuel.
4. Table de mapping des Issues ouvertes : `issue #N → sNN-slug` proposé.
5. Issues fermées : listées pour contexte, jamais touchées.

**Hors de ce fichier :** structure du code, conventions, patterns, stack. C'est
le travail de `/dm-architect` via `codebase-analysis`. Écrire une seconde
analyse de code ici recréerait exactement la duplication que l'orchestrateur
mince cherche à éviter.

## Traitement du passé

| Objet | Traitement | Muté ? |
| --- | --- | --- |
| Code déjà livré | baseline documentaire dans `docs/onboarding.md` | non |
| Issues ouvertes | mapping **proposé** dans `docs/onboarding.md` | non |
| Conversion des Issues | dans `/dm-stories`, après init, confirmée une par une | oui, sur accord explicite |
| Issues fermées | listées pour contexte | non |

Aucune Issue écrite à la main par l'utilisateur n'est renommée, déplacée ou
fermée sans confirmation explicite, une par une.

## Chaînage

    /dm-continue
      → /dm-prd        (3e mode : brownfield, pré-rempli depuis docs/onboarding.md)
      → /dm-init       (idempotent, inchangé)
      → /dm-stories    (reste à faire + conversion des Issues mappées)
      → /dm-architect  (analyse le code, inchangé)
      → pipeline normal

## Comportement de la commande

Frontmatter :

    description: Onboard an existing codebase into the driven pipeline
    allowed-tools: Read, Glob, Grep, Bash, Write, AskUserQuestion

`Bash` sert aux requêtes de lecture (`git log`, `git ls-files`, `gh issue list`)
et au commit docs du livrable. Aucune mutation de board, aucun appel en écriture
à `gh`. Pas de `Edit` : la commande n'écrit qu'un fichier neuf.

Préconditions, fail-closed :

- aucune source détectée → STOP : « repo vide — utilise `/dm-prd` » ;
- `docs/prd.md` déjà présent → STOP : « projet déjà cadré — utilise `/dm-status` ».

Dégradation : `gh` absent ou non authentifié → la section mapping est **skippée
avec un avertissement explicite**, la baseline s'écrit quand même. Le manque de
board ne doit pas bloquer la documentation du produit.

Branche et commit : `/dm-continue` tourne avant l'existence de `next`. Il commit
sur la branche par défaut, comme `/dm-stories` en pré-init. Le contenu est
docs-only, donc le hook `pre-commit` passe sans plan validé.

## Fichiers touchés

| Fichier | Changement |
| --- | --- |
| `src/commands/dm-continue.md` | neuf |
| `src/commands/dm-prd.md` | 3e mode `brownfield` à côté de clone / greenfield |
| `src/commands/dm-stories.md` | réutilise l'Issue mappée par `onboarding.md`, avec confirmation |
| `src/commands/dm-status.md` | sources présentes + pas de `docs/prd.md` → « Next: /dm-continue » |
| `src/commands/dm-help.md` | bloc « Projet existant » en tête ; numérotation 1-14 inchangée |
| `src/lib/dm-board.sh` | sous-commande `issue-adopt` exposant `add_issue_to_project_backlog` |
| `tests/fixtures/gh-stub.sh` | le stub `issue edit` ignore `--title` |
| `tests/commands.test.mjs`, `tests/board-parse.test.mjs` | `dm-continue` dans `required` + assertions de comportement + `issue-adopt` |
| `README.md`, `DOC.md` | documenter la porte d'entrée brownfield |

`bin/dm-build.mjs` itère `src/commands/` : le nouveau fichier se propage seul
vers les cibles codex et grok. **Aucun changement de build.**

## Prédicat « projet existant » pour `/dm-status`

Fichiers sources hors `docs/` **et** historique git de plus d'un commit.
`/dm-status` conserve son comportement actuel (pointer `/dm-prd`) quand le repo
est réellement vide.

## Tests

Dans `tests/commands.test.mjs`, au style du fichier :

- `dm-continue` ajouté au tableau `required` — sans quoi la garde est vide ;
- `/dm-continue` ne contient pas `require-ready` (il tourne hors gate board) ;
- `/dm-continue` n'appelle pas `issue-create-us` ni `dm-board.sh` en écriture ;
- `/dm-prd` mentionne le mode brownfield ;
- `/dm-status` mentionne `/dm-continue`.

## Hors périmètre

- Le pipeline driven n'est pas appliqué à ce dépôt lui-même : pas d'`AGENTS.md`
  racine, historique en commits `feat:` / `fix:` directs sur `main`.
- Pas de migration automatique des Issues fermées.
- Pas d'inférence de design system depuis le code existant : `/dm-design-system`
  reste fail-closed sur une source explicite.
