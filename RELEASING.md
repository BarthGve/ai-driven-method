# Releasing driven

driven n'est pas une application driven : pas de board, pas de wiki, pas d'Issues par
ticket. `/dm-release` suppose tout ça, donc il ne s'applique pas ici. La release se fait
à la main, en quatre commandes.

Pré-1.0 : le **mineur** peut casser l'interface d'installation (flags, chemins posés),
le **patch** jamais.

## 1. Vérifier

```bash
node --test tests/*.mjs
git status --short          # doit être propre
```

## 2. Bumper

`dm-version.sh` n'est pas réservé aux repos applicatifs : il lit le `VERSION` du
répertoire courant, synchronise `package.json` / `pyproject.toml` s'ils existent, et
ouvre la section du changelog.

```bash
bash src/lib/dm-version.sh bump minor    # ou major / patch
```

## 3. Remplir le changelog

`CHANGELOG.md` a reçu une section vide pour la nouvelle version. Écris-la avant de taguer :
ce que le visiteur lit, c'est ça, pas les messages de commit.

## 4. Taguer et publier

```bash
ver="$(bash src/lib/dm-version.sh current)"
git add VERSION CHANGELOG.md
git commit -m "chore: release v${ver}"
git tag "v${ver}"
git push origin main --tags
gh release create "v${ver}" --repo BarthGve/ai-driven-method \
  --title "v${ver}" --notes-from-tag
```

`--notes-from-tag` reprend le message du tag ; pour reprendre le changelog à la place,
utilise `--notes-file` avec un extrait de la section.

## Ce que ça change pour les utilisateurs

`install.sh` estampille `VERSION` dans `.dm-version` de chaque projet installé. Un
utilisateur peut donc comparer sa version à la dernière release, ce qu'un SHA ne
permettait pas.
