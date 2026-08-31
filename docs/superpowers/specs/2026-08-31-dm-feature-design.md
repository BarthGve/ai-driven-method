# `/dm-feature` — ajouter une feature à un produit déjà livré

Date: 2026-08-31
Statut: design validé, prêt pour plan d'implémentation

## Problème

driven cadre un produit une fois (`/dm-prd` → `/dm-stories`), puis livre story par
story jusqu'à `/dm-release`. Rien ne couvre ce qui vient après : une feature
demandée quand l'application tourne déjà en production.

État vérifié du dépôt :

- `/dm-release` s'arrête à `shipped`. Aucune suite n'est prévue.
- `/dm-stories` dérive du PRD et **réécrit** `docs/stories.md` en entier. Le
  relancer pour ajouter une feature écrase le découpage existant. Les Issues
  parent, elles, sont idempotentes (`Skip create if [<story-id>] already exists`),
  donc le board survivrait au relancement mais le fichier non.
- `/dm-continue` ne s'applique pas : il exige explicitement l'absence de
  `docs/prd.md`.

## Décisions de cadrage

1. **Le PRD est vivant.** La feature est cadrée puis intégrée au PRD, qui décrit
   donc toujours le produit tel qu'il est. C'est ce qui garde `/dm-stories`,
   `/dm-architect` et `/dm-status` cohérents entre eux.
2. **L'amendement est tracé dans le PRD lui-même**, en section d'historique. Sans
   trace, plus rien ne distingue ce qui a été promis en v1 de ce qui a été ajouté
   en v1.4, et le cimetière devient inutile : on ne peut plus dire « on avait
   exclu ça, et voilà pourquoi on est revenu dessus ».
3. **La feature franchit deux barrières** : une relecture en contexte vierge, et
   un contrôle d'impact architectural.

Nom : `/dm-feature <slug>`, aligné sur la convention `dm-*`.

## Comportement

Frontmatter :

    description: Add a feature to a shipped product — amend the PRD, append stories
    argument-hint: <feature slug or short description>
    allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion

Préconditions, fail-closed :

- `docs/prd.md` manquant → STOP : « pas de PRD — `/dm-prd`, ou `/dm-continue` sur
  un projet existant » ;
- `docs/stories.md` manquant → STOP : « produit pas encore découpé — `/dm-stories` ».

La commande ne code rien. Elle cadre, amende, découpe, et rend la main au
pipeline par story habituel.

Étapes, dans l'ordre :

1. Cadrer la feature avec l'utilisateur (AskUserQuestion, une question à la fois) :
   besoin, utilisateurs concernés, ce qui entre dans le périmètre, ce qui reste
   dehors. Si la feature sort du cimetière du PRD, exiger la justification du
   revirement — c'est le seul cas où le cimetière peut être contredit.
2. Passer la liste du déclencheur architectural, point par point, et enregistrer
   les éléments touchés.
3. Amender `docs/prd.md` : corps mis à jour, entrée ajoutée sous `## Amendements`.
4. Découper en une ou plusieurs stories, ids en continuité de l'existant, et les
   **ajouter** à `docs/stories.md`.
5. Créer une Issue parent par story en `backlog`, via l'appel existant :
   `bash .dm/lib/dm-board.sh issue-create-us <story-id> "<title>" <body-file>`.
   Il est déjà idempotent sur le préfixe `[<story-id>]`.
6. Lancer la relecture en contexte vierge (`stories-reviewer`), sortie dans
   `docs/reviews/features/<id>.md`.
7. Commit sur la ligne d'intégration, comme `/dm-stories` : `next` si l'init a eu
   lieu, sinon la branche par défaut. Message `docs: feature <slug>`.

Fin : si le déclencheur architectural a été touché, « Next step: /dm-architect »,
sinon « Next step: /dm-research <story-id> ».

## Amendement du PRD

`src/templates/prd.md` n'a **pas** de section d'historique : il s'arrête à
`## Success criteria`. Il faut l'ajouter au template, sinon la commande improvise
une structure à chaque projet.

Nouvelle section `## Amendements`, une entrée par feature :

    ### <date> — v<version cible> — <slug>
    **Entre dans le périmètre :** …
    **Sorti du cimetière ?** non | oui — <justification du revirement>
    **Stories :** s07-…, s08-…

Le corps du PRD — table du périmètre, cimetière — est mis à jour en place ;
l'historique se lit juste au-dessous. Un lecteur voit le produit d'aujourd'hui et
ce qui avait été promis au départ.

## Déclencheur architectural — mécanique

Tout le reste de driven est fail-closed sur un prédicat vérifiable (`validated:
yes`, `Ship allowed: yes`, `require-ready`, existence d'un fichier). Le contrôle
d'impact doit l'être aussi : une énumération, jamais « si ça touche
l'architecture ».

La feature repasse par `/dm-architect` (nouvel ADR) **avant** `/dm-plan` si elle
introduit au moins un de :

- une nouvelle dépendance runtime ;
- un service ou provider externe (paiement, mail, stockage, IA…) ;
- un nouveau magasin de persistance, ou une migration de schéma ;
- une surface d'authentification ou d'autorisation nouvelle ;
- un mécanisme asynchrone, tâche de fond ou file.

Aucun élément de la liste → directement `/dm-research`.

## Relecture en contexte vierge

Le skill `stories-review` est câblé sur « tout le découpage vs le PRD » : sa
vérification n°1 part de la table du périmètre et exige que chaque ligne soit
couverte. Deux conséquences.

**Sortie séparée.** La review de feature écrit `docs/reviews/features/<id>.md`.
Elle ne touche pas `docs/reviews/stories.md`, que `/dm-status` (étape 1) et
`/dm-research` (ligne 26) grep pour `^Stories ready:`. L'écraser casserait le
signal de cadrage du produit.

**Une section à ajouter au skill.** Aucune des huit vérifications actuelles ne
couvre le cas « produit déjà livré » :

- la feature double une story déjà **shipped** (le check n°8 ne compare que les
  stories du fichier entre elles, pas au produit livré) ;
- la feature dépend d'une story pas encore livrée ;
- la feature contredit un comportement déjà en production.

Ces trois points forment une section neuve dans
`src/skills/stories-review/SKILL.md`. Le subagent `stories-reviewer` reste
inchangé : mêmes outils, même contrat lecture seule, mêmes lignes finales
`Max severity:` / `Stories ready:`.

Gate douce, comme la review de cadrage : signalée par `/dm-status`, non bloquante.

## Ids et append

Les ids `s<NN>-<slug>` nomment chaque fichier du pipeline et chaque branche : une
collision casse le cycle entier. La commande lit le `s<NN>` maximum présent dans
`docs/stories.md` et continue la séquence.

Elle **ajoute** au fichier ; elle ne le réécrit pas. C'est exactement le défaut
qui rend `/dm-stories` inutilisable pour ce cas.

## Routage `/dm-status`

Après une release, toutes les stories sont `shipped` et la logique « next
command » n'a plus rien à proposer. Elle doit pointer `/dm-feature`. C'est le même
trou de routage que celui corrigé pour `/dm-continue` dans `/dm-status`,
`/dm-help` et `/dm-orchestrator`.

## Fichiers touchés

| Fichier | Changement |
| --- | --- |
| `src/commands/dm-feature.md` | neuf |
| `src/templates/prd.md` | section `## Amendements` |
| `src/skills/stories-review/SKILL.md` | section « feature vs produit livré » |
| `src/commands/dm-status.md` | tout `shipped` → `/dm-feature` |
| `src/commands/dm-help.md` | bloc « Après la v1 » |
| `tests/commands.test.mjs`, `tests/templates.test.mjs` | assertions |

`bin/dm-build.mjs` itère `src/commands/` et `src/skills/` : propagation
automatique vers Codex et Grok. Aucun changement de build.

Pas de nouvel appel board : la commande réutilise `issue-create-us`, déjà
idempotent sur le préfixe `[<story-id>]`.

## Hors périmètre

- **Versioning.** `/dm-release` demande déjà major/minor/patch à l'utilisateur.
  Une feature n'a pas à imposer un minor.
- **Suppression de feature.** Retirer quelque chose d'un produit livré est un
  autre problème (migration, dépréciation) et n'est pas traité ici.
- **Le design system.** `/dm-design-system` reste fail-closed sur une source
  explicite ; une feature qui a besoin d'un composant absent le signale en
  « Design system gaps », comme aujourd'hui.
