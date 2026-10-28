#!/usr/bin/env bash
# Classify local branches for prune: merged (auto-drop), closed (ask), active, skip.
# Usage: classify.sh <repo-root>
# stdout TSV: status<TAB>branch<TAB>worktree_or_-<TAB>pr_or_-<TAB>remote
# status: merged | closed | active | skip
# remote: alive | gone | none
set -euo pipefail

repo_root=${1:?repo root required}
cd "$repo_root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git work tree: $repo_root" >&2
  exit 1
fi

default_ref=$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || true)
if [[ -n "$default_ref" ]]; then
  default_branch=${default_ref#refs/remotes/origin/}
elif git show-ref --verify --quiet refs/remotes/origin/main; then
  default_branch=main
elif git show-ref --verify --quiet refs/remotes/origin/master; then
  default_branch=master
else
  echo "cannot resolve default branch" >&2
  exit 1
fi
default_remote_ref="origin/$default_branch"

remote_slug=
if command -v gh >/dev/null 2>&1; then
  remote_slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi

# Prefer MERGED, else CLOSED, else first PR for this head ref name.
pr_state_for_branch() {
  local branch=$1
  if [[ -z "$remote_slug" ]] || ! command -v jq >/dev/null 2>&1; then
    echo "-"
    return
  fi
  local json
  json=$(gh pr list --repo "$remote_slug" --head "$branch" --state all \
    --limit 5 --json number,state,mergedAt,url 2>/dev/null || true)
  if [[ -z "$json" || "$json" == "[]" ]]; then
    echo "-"
    return
  fi
  printf '%s' "$json" | jq -r '
    (map(select(.mergedAt != null or .state == "MERGED")) | .[0]) as $m
    | if $m then "MERGED #\($m.number) \($m.url)"
      else (map(select(.state == "CLOSED")) | .[0]) as $c
      | if $c then "CLOSED #\($c.number) \($c.url)"
        else (.[0] | "\(.state) #\(.number) \(.url)")
        end
      end
  ' 2>/dev/null || echo "-"
}

# Tip SHA may be a merged PR head under a different branch name (rename / retarget).
pr_merged_for_tip() {
  local tip=$1
  if [[ -z "$remote_slug" ]] || ! command -v jq >/dev/null 2>&1; then
    echo "-"
    return
  fi
  local json
  json=$(gh api "repos/${remote_slug}/commits/${tip}/pulls" 2>/dev/null || true)
  if [[ -z "$json" || "$json" == "[]" ]]; then
    echo "-"
    return
  fi
  printf '%s' "$json" | jq -r '
    (map(select(.merged_at != null)) | .[0]) as $m
    | if $m then "MERGED #\($m.number) https://github.com/\($m.base.repo.full_name // "'"$remote_slug"'")/pull/\($m.number)"
      else "-"
      end
  ' 2>/dev/null || echo "-"
}

# Use | as delimiter: bash IFS tab collapses empty %(upstream:track) when in sync
# and shifts %(worktreepath) into the track field.
while IFS='|' read -r branch upstream track worktree; do
  [[ "$branch" == "$default_branch" ]] && continue

  wt=${worktree:-}
  [[ -z "$wt" ]] && wt=-

  if [[ -z "$upstream" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "skip" "$branch" "$wt" "-" "none"
    continue
  fi

  if [[ "$track" == *gone* ]]; then
    remote_state=gone
  else
    remote_state=alive
  fi

  pr_info=$(pr_state_for_branch "$branch")
  status=
  if git merge-base --is-ancestor "$branch" "$default_remote_ref" 2>/dev/null; then
    status=merged
    [[ "$pr_info" == "-" ]] && pr_info="ancestor of $default_branch"
  elif [[ "$pr_info" == MERGED* ]]; then
    status=merged
  else
    tip=$(git rev-parse --verify "$branch" 2>/dev/null || true)
    tip_pr=-
    if [[ -n "$tip" ]]; then
      tip_pr=$(pr_merged_for_tip "$tip")
    fi
    if [[ "$tip_pr" == MERGED* && "$remote_state" == alive ]]; then
      # Zombie remote: tip is a merged PR head under another ref name.
      # Require remote alive so a new branch started at that tip (remote gone /
      # retargeted) is not auto-dropped — e.g. follow-on WIP still on the merged tip.
      status=merged
      pr_info=$tip_pr
    elif [[ "$tip_pr" == MERGED* && "$remote_state" == gone ]]; then
      status=closed
      pr_info="tip $tip_pr (ask: new work on merged tip?)"
    elif [[ "$remote_state" == gone ]]; then
      status=closed
    else
      status=active
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$status" "$branch" "$wt" "$pr_info" "$remote_state"
done < <(
  fmt='%(refname:short)|%(upstream:short)|%(upstream:track)|%(worktreepath)'
  git for-each-ref --format="$fmt" refs/heads
)
