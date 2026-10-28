# skills

Personal agent skills for coding agents. Install with [skills.sh](https://skills.sh).

[![skills.sh](https://skills.sh/b/lochiego/skills)](https://skills.sh/lochiego/skills)

## Install

```bash
npx skills@latest add lochiego/skills -a cursor   # omit -a to choose agent
# global (all projects): add -g
```

Update installed skills with `npx skills@latest update`. Re-run `add` to pick up new skills.

## Skills

| Skill | Description |
| --- | --- |
| [`clean-old-branches`](./skills/engineering/clean-old-branches/SKILL.md) | Prune merged or gone local branches/worktrees; delete remotes for merged. |
| [`port-skill`](./skills/meta/port-skill/SKILL.md) | Port a personal skill from local dirs into this collection (public-safe). |

More skills land under `skills/<category>/<name>/`.

## Layout

Each skill is a directory with a `SKILL.md` (YAML frontmatter + instructions), per the [Agent Skills specification](https://agentskills.io/specification):

```text
skills/
└── <category>/
    └── <skill-name>/
        └── SKILL.md
```

Required frontmatter: `name`, `description`.

## License

MIT
