---
name: clean-old-branches
description: >-
  Finds local branches and worktrees that are merged (PR MERGED, tip SHA of a
  merged PR, or ancestor of default) or whose upstream remote is gone, classifies
  each as merged (safe to drop) or closed/unmerged (ask first), then removes
  approved worktrees and branches across workspace repos — and deletes the
  remote branch for merged items when it still exists. Use when the user asks to
  prune gone branches, clean up merged worktrees, drop stale local branches, or
  tidy .worktrees after PRs merge or close.
---

# Clean Old Branches

Clean local branches and `.worktrees/` entries that are already merged, or whose
remote tracking branch no longer exists. For merged items, also delete the
remote branch when it is still alive.

## Policy

| Condition                                                                                 | Action                                                         |
| ----------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Merged (see below), remote gone or alive                                                  | Drop worktree + local branch; `git push origin --delete` if remote alive — no ask |
| Remote gone + linked PR `CLOSED` (not merged), or remote gone and not merged              | Ask before drop (local only; do not delete a remote that is already gone) |
| Remote alive + not merged (open work, or closed-unmerged PR still on remote)              | Leave alone; report as active                                  |
| Default branch (`main` / `master` / `origin/HEAD`)                                        | Never delete                                                   |

**Merged** means any of:

1. Branch tip is an ancestor of `origin/<default>`, or
2. A GitHub PR with `--head <branch>` is `MERGED`, or
3. The tip commit is associated with a `MERGED` PR under any head ref name **and**
   the remote for this local branch is still **alive** — covers renames /
   retargets where a zombie remote kept the old name. If the tip matches a
   merged PR but the remote is already **gone**, classify as **closed** (ask):
   that tip may be a new branch started from the merged head (uncommitted WIP
   still sits on the same SHA).

**Squash merges are the normal merge path.** A branch tip is often not an
ancestor of the default branch after squash/rebase-merge. Classification must
treat GitHub PR `MERGED` (or tip-SHA match) as merged. Deleting those locals with
`git branch -D` is the happy path — do **not** ask for approval when status is
`merged`.

Do not force-delete dirty worktrees. If `git worktree remove` fails on dirty
files, report the path and ask; only use `--force` after explicit yes.

## Scope

1. Every git root in the Cursor workspace (multi-root OK).
2. Under each root, also scan `.worktrees/*` via `git worktree list`.
3. Skip bare repos and non-git folders.

## Workflow

Copy and track:

```
Prune progress:
- [ ] 1. Discover repos
- [ ] 2. Fetch --prune each
- [ ] 3. Classify branches
- [ ] 4. Report
- [ ] 5. Drop merged (local + remote)
- [ ] 6. Ask + drop closed (if approved)
- [ ] 7. Summarize
```

### 1. Discover repos

For each workspace folder, if it is a git work tree (`git rev-parse --is-inside-work-tree`), treat its common git dir as one repo. Deduplicate when several workspace folders share one `.git` (linked worktrees).

### 2. Fetch

In each unique repo root (prefer the main checkout, not a nested worktree):

```bash
git fetch --prune --tags origin
```

Needs network + host git credentials (`all` / non-sandbox). If fetch fails, stop that repo and continue others.

### 3. Classify

Run the helper shipped with this skill (preferred — stable columns). After a
Cursor global install the path is:

```bash
bash ~/.cursor/skills/clean-old-branches/scripts/classify.sh <repo-root>
```

If the skill lives elsewhere, run `scripts/classify.sh` next to this `SKILL.md`.

Stdout TSV: `status`, `branch`, `worktree_or_-`, `pr_or_-`, `remote` (`alive`|`gone`|`none`).

Or classify by hand:

1. Default branch: `git symbolic-ref refs/remotes/origin/HEAD` → strip `refs/remotes/origin/`, else `main` then `master`.
2. For each local branch `B` with an upstream (skip the default branch):
   - **merged** if `git merge-base --is-ancestor B origin/<default>`, **or** `gh pr list --repo <owner/name> --head <B> --state merged` is non-empty, **or** `gh api repos/<owner/name>/commits/<tip>/pulls` returns a PR with `merged_at` set.
   - else **closed** if the upstream track is `[gone]` (ask class).
   - else **active** (remote still exists and not merged).
3. Attach worktree path from `git for-each-ref` / `git worktree list` when checked out (often `<root>/.worktrees/<name>`).

Never use `git branch --merged` alone without a fetch; prefer ancestor check against `origin/<default>` after prune, plus `gh` for squash merges and renames.

### 4. Report

Group by repo. Example:

```text
## my-app

Safe to drop (merged) — will delete remote when alive:
- feat/focus-events  MERGED #106 (tip of renamed head)  remote:alive  worktree: .worktrees/…
- feat/segment-boolean  remote:gone  (no worktree)

Ask before drop (closed / unmerged, remote gone):
- experiment/rxjs-stream  PR #42 CLOSED
  worktree: .worktrees/…

Still active (remote alive, not merged) — skipped:
- feat/consent-modal  PR #95 CLOSED
- feat/sw-message-ack
```

Say how many merged will be dropped (and how many remotes deleted) and how many need a decision.

### 5. Drop merged (no per-branch ask)

For each merged item, in order:

1. If the branch is the current branch of a worktree other than the one you will delete, skip with a note (should not happen if classification used worktree list).
2. If dropping the branch checked out in the **primary** repo root: `git switch <default>` first.
3. If a linked worktree exists: `git worktree remove <path>` (no `--force` unless user already approved force for that path).
4. Delete local branch with `git branch -D <branch>`. Prefer `-D` over `-d`: squash/rebase merges make `-d` refuse even when the PR is merged. Do not ask; do not fall back to “stop and report” solely because `-d` would have refused.
5. If classify `remote` is `alive`: `git push origin --delete <branch>`. Only for **merged** status. If push fails (already deleted, protected), report and continue.
6. Optional: `git worktree prune`.

Batch merged drops; do not ask per branch. One short pre-summary is enough (“Dropping N merged; deleting M remotes…”).

Only pause the merged path when a precondition fails (dirty primary checkout blocking `git switch`, dirty linked worktree blocking `git worktree remove`). That is not a squash-merge approval — fix or ask about the dirty state, then finish with `-D` and remote delete.

### 6. Closed / unmerged — ask

List each closed candidate with: branch, PR number/URL if any, worktree path, dirty or not (`git status -sb` in that worktree).

Ask once with a clear multi-select style prompt, e.g.:

- Drop all listed?
- Drop none?
- Drop only: … (user names branches)

Only then remove approved ones with `git worktree remove` + `git branch -D` (unmerged needs `-D`). Do **not** `git push --delete` for closed/unmerged unless the user explicitly asks to delete those remotes (they are already gone in the closed class).

### 7. Summarize

Per repo: dropped locals, deleted remotes, kept (user said no), skipped (active), errors.

## Hard rules

- `git push origin --delete` **only** for branches classified **merged** (step 5). Never for closed, active, skip, or the default branch.
- Never drop `main` / `master` / the default branch.
- Never `rm -rf` a worktree directory; use `git worktree remove`. (Orphaned husks left after a successful unregister — e.g. only `dist/` — may be removed after confirming they are not a registered worktree.)
- Separate read/classify Shell calls from destructive remove/delete calls (user approval hygiene).
- Destructive git (including remote delete) needs host credentials / elevated permissions as required by the agent environment.
- Prefer `gh` for PR state; if `gh` auth fails, fall back to ancestor-only merge detection and treat non-ancestors with gone remotes as **ask** (closed class); leave remote-alive non-ancestors as **active**.

## Triggers

User says things like: prune gone branches, clean merged worktrees, tidy stale branches, drop local branches after merge, clean up `.worktrees`.
