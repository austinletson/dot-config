#!/usr/bin/env python3
"""
Prune stale git worktrees for the current repository.

A worktree is removed only if ALL of the following hold:
  1. It is a linked worktree (never the main checkout).
  2. Its working directory is clean (no staged, unstaged, or untracked changes).
  3. It has no active tmux session (session name == worktree directory basename,
     matching the convention used by tmux_git_worktree_session.py).
  4. It has been inactive for more than N days (default 7). "Inactive" is the
     newest of several signals — last commit date, worktree admin-dir mtime,
     and worktree directory mtime — so a recently-created worktree on an old
     branch is NOT considered stale.

Removing a worktree deletes only its working directory; the branch and its
commits are left untouched, so committed work is never lost.

Usage:
    tmux_prune_worktrees.py            # dry run: show what WOULD be removed
    tmux_prune_worktrees.py --delete   # actually remove the stale worktrees
    tmux_prune_worktrees.py --days 14  # use a 14-day threshold instead of 7
    tmux_prune_worktrees.py --delete --days 30
"""

import argparse
import os
import subprocess
import sys
import time


def run(cmd, cwd=None, check=True):
    """Run a shell command; return (stdout, returncode)."""
    result = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, cwd=cwd, check=False
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"command failed: {cmd}\n{result.stderr.strip()}")
    return result.stdout.strip(), result.returncode


def list_worktrees():
    """Return a list of dicts describing every worktree in the current repo.

    Each dict has: path, branch (or None if detached), is_main, is_locked.
    The first worktree reported by git is always the main checkout.
    """
    output, _ = run("git worktree list --porcelain")
    worktrees = []
    current = None
    for line in output.split("\n"):
        if line.startswith("worktree "):
            if current is not None:
                worktrees.append(current)
            current = {
                "path": line.split(" ", 1)[1],
                "branch": None,
                "is_locked": False,
            }
        elif line.startswith("branch ") and current is not None:
            ref = line.split(" ", 1)[1]
            current["branch"] = ref.replace("refs/heads/", "")
        elif line.startswith("locked") and current is not None:
            current["is_locked"] = True
    if current is not None:
        worktrees.append(current)

    for i, wt in enumerate(worktrees):
        wt["is_main"] = i == 0
    return worktrees


def is_clean(path):
    """True if the worktree has no staged/unstaged/untracked changes."""
    status, rc = run("git status --short", cwd=path, check=False)
    if rc != 0:
        # If we can't read status, err on the side of caution: treat as dirty.
        return False
    return status == ""


def has_tmux_session(session_name):
    """True if a tmux session with this exact name exists."""
    _, rc = run(f'tmux has-session -t="{session_name}"', check=False)
    return rc == 0


def inactive_days(path):
    """Days since the worktree was last active.

    Uses the NEWEST of two signals so we don't delete a recently-created
    worktree just because its branch's last commit is old:
      - committer date of HEAD
      - mtime of the worktree's top-level directory (reflects when the worktree
        was created and when top-level files change)

    We deliberately do NOT use the admin git dir (.git/worktrees/<id>) mtime:
    running `git status`/`git log` to inspect a worktree rewrites its index
    there, bumping that mtime to "now" and making every worktree look active.
    Returns a float number of days.
    """
    now = time.time()
    signals = []

    # Last commit committer date (epoch seconds).
    commit_ts, rc = run("git log -1 --format=%ct", cwd=path, check=False)
    if rc == 0 and commit_ts.isdigit():
        signals.append(int(commit_ts))

    # Worktree directory mtime.
    if os.path.isdir(path):
        signals.append(os.path.getmtime(path))

    if not signals:
        # No signal at all — treat as very old so it becomes a candidate.
        return float("inf")

    most_recent = max(signals)
    return (now - most_recent) / 86400.0


def main():
    parser = argparse.ArgumentParser(
        description="Prune stale, clean, session-less git worktrees."
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help="actually remove worktrees (default is a dry run)",
    )
    parser.add_argument(
        "--days",
        type=float,
        default=7.0,
        help="inactivity threshold in days (default: 7)",
    )
    args = parser.parse_args()

    # Make sure we're in a git repo and run git operations from the main worktree
    # (so we never sit inside a directory we're about to remove).
    _, rc = run("git rev-parse --is-inside-work-tree", check=False)
    if rc != 0:
        print("❌ Not in a git repository.", file=sys.stderr)
        sys.exit(1)

    worktrees = list_worktrees()
    main_worktree = next((wt for wt in worktrees if wt["is_main"]), None)
    if main_worktree is None:
        print("❌ Could not determine the main worktree.", file=sys.stderr)
        sys.exit(1)
    main_path = main_worktree["path"]

    # Where are we standing? Never remove the worktree we're currently inside.
    current_top, _ = run("git rev-parse --show-toplevel", check=False)

    candidates = []
    skipped = []

    for wt in worktrees:
        path = wt["path"]
        session_name = os.path.basename(path)

        if wt["is_main"]:
            continue
        if os.path.realpath(path) == os.path.realpath(current_top or ""):
            skipped.append((path, "current worktree"))
            continue
        if wt["is_locked"]:
            skipped.append((path, "locked"))
            continue
        if has_tmux_session(session_name):
            skipped.append((path, f"active tmux session '{session_name}'"))
            continue
        if not is_clean(path):
            skipped.append((path, "uncommitted changes"))
            continue

        age = inactive_days(path)
        if age <= args.days:
            skipped.append((path, f"active {age:.1f}d ago (< {args.days:g}d)"))
            continue

        candidates.append((path, age, session_name))

    # --- Report skipped ---
    if skipped:
        print("Kept:")
        for path, reason in skipped:
            print(f"  • {os.path.basename(path)} — {reason}")
        print()

    if not candidates:
        print("Nothing to prune. ✨")
        return

    verb = "Removing" if args.delete else "Would remove"
    print(f"{verb} {len(candidates)} stale worktree(s) (> {args.days:g} days inactive):")
    for path, age, _ in candidates:
        print(f"  • {os.path.basename(path)} — inactive {age:.1f}d — {path}")
    print()

    if not args.delete:
        print("Dry run. Re-run with --delete to remove them.")
        return

    # --- Actually remove ---
    for path, _, session_name in candidates:
        # Run from the main worktree so git isn't operating from inside `path`.
        _, rc = run(f'git worktree remove "{path}"', cwd=main_path, check=False)
        if rc == 0:
            print(f"✓ Removed {path}")
            # Clean up a matching tmux session if one appeared in the meantime.
            if has_tmux_session(session_name):
                run(f'tmux kill-session -t="{session_name}"', check=False)
                print(f"  ✓ killed tmux session '{session_name}'")
        else:
            print(f"✗ Failed to remove {path} (skipped)")


if __name__ == "__main__":
    # When invoked from tmux, start from the pane's directory so we operate on
    # the repo the user is actually in.
    pane_path, rc = run(
        "tmux display-message -p '#{pane_current_path}'", check=False
    )
    if rc == 0 and pane_path and os.path.isdir(pane_path):
        os.chdir(pane_path)
    main()
