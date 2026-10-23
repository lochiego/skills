# Maintainer notes

This repo is a [skills.sh](https://skills.sh) skill package.

## Adding a skill

1. Create `skills/<category>/<skill-name>/SKILL.md`.
2. Set frontmatter `name` (kebab-case, matches folder) and `description` (third person: WHAT + WHEN).
3. List the skill in [README.md](README.md).
4. Keep skills public-safe: no secrets, no machine-only absolute paths, no employer-only internals.

## Install check

```bash
npx skills@latest add lochiego/skills --list
```
