#!/usr/bin/env bash
# Print a compact "repo:branch" indicator for the tmux status line.
#
# Usage: tmux_status_git.sh <dir> [fallback]
#
# Output shapes (tmux format escapes included):
#   repo:branch                     - main worktree of the repo
#   wt repo:branch                  - managed worktree, name matches checkout
#   wt repo:branch ⚠ dir:other      - managed worktree whose directory was named
#                                     for a different branch than the one checked out
#
# Managed worktrees are the ones created by tmux_git_worktree_session.py, i.e.
# sibling directories named "{repo}-worktree-{branch-with-slashes-as-dashes}".

set -uo pipefail

dir="${1:-$PWD}"
fallback="${2:-}"

# tmux re-expands this output as a format string, so '#' in any text we
# interpolate (repo, branch, ...) must be escaped; our own #[...] must not be.
esc() { printf '%s' "${1//#/##}"; }
emit() { printf '%s\n' "$1"; }

[ -d "$dir" ] || { emit "$(esc "$fallback")"; exit 0; }

common_dir=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  emit "$(esc "$fallback")"
  exit 0
}
toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || {
  emit "$(esc "$fallback")"
  exit 0
}

repo=$(basename "$(dirname "$common_dir")")

branch=$(git -C "$dir" branch --show-current 2>/dev/null)
if [ -z "$branch" ]; then
  # Detached HEAD: show the short sha instead.
  branch="@$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
fi

dim='#[fg=colour245]'
strong='#[fg=default,bold]'
warn='#[fg=colour203,bold]'
reset='#[fg=default,nobold]'

out="${dim}$(esc "$repo"):${strong}$(esc "$branch")${reset}"

# Is this a managed worktree directory, and does its name still match the checkout?
wt_dir=$(basename "$toplevel")
prefix="${repo}-worktree-"
if [ "$toplevel" != "$(dirname "$common_dir")" ]; then
  out="${dim}wt ${reset}${out}"
  if [ "${wt_dir#"$prefix"}" != "$wt_dir" ]; then
    dir_branch="${wt_dir#"$prefix"}"
    if [ "$dir_branch" != "${branch//\//-}" ]; then
      out="${out} ${warn}⚠ dir:$(esc "$dir_branch")${reset}"
    fi
  fi
fi

emit "$out"
