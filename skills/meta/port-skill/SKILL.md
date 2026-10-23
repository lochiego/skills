---
name: port-skill
description: >-
  Ports a personal agent skill from local skill directories into this public
  skill collection repo. Sanitizes for public use and updates the README skill
  list. Use when the user asks to port, publish, or move a personal skill into
  the collection.
---

# Port skill into this collection

Copy a personal skill into this repo so others can install it with `npx skills`.

## Preconditions

1. Confirm the working directory (or a path the user gives) is this skill collection:
   - `git remote -v` should point at the install owner/repo, or
   - README should document `npx skills add <owner>/<repo>`
2. If not, ask for the clone path and switch there.

## Discover candidates

List skills (name + one-line description from frontmatter):

- `~/.cursor/skills/*/SKILL.md`
- `~/.agents/skills/*/SKILL.md`
- Other paths only if the user names them

Prefer `~/.cursor/skills/` by default.

Do **not** port third-party upstream skills (copies installed from other authors) unless the user explicitly wants a maintained fork.

Ask which skill(s) to port. Port only what they choose.

## For each chosen skill

1. Read `SKILL.md` and sibling files (`scripts/`, references, assets).
2. **Sanitize for public release (required):**
   - Strip secrets, tokens, credentials, private URLs
   - Replace machine-absolute home paths with `~` or documented placeholders
   - Remove or rewrite content that only works inside one employer's monorepo, internal tools, or proprietary packages
   - If the skill cannot be made general without losing its purpose, **refuse the port** and say why
3. Propose a category: `meta`, `engineering`, `productivity`, or a name the user chooses.
4. Copy into `skills/<category>/<dir-name>/`, preserving supporting files after sanitization.
5. Ensure frontmatter:
   - `name`: kebab-case, matches the folder name
   - `description`: third person, WHAT + WHEN, max 1024 chars
6. Add a one-line entry under the README **Skills** section.

## Finish

1. Show a short diff summary (paths touched, category, any sanitization changes).
2. Do **not** commit unless the user asks.
3. After they push, give the install command using owner/repo from `git remote` (do not hardcode):

```bash
npx skills@latest add <owner>/<repo> --skill <name> -g
```
