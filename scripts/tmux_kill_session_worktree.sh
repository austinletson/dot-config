#!/bin/bash
# Kill the current tmux session and, if it lives in a git worktree, remove that
# worktree too (only when the worktree is clean — `git worktree remove` without
# --force refuses to remove a dirty worktree).
#
# Invoked from tmux with the session name and pane path expanded by tmux:
#   bash tmux_kill_session_worktree.sh '#{session_name}' '#{pane_current_path}'

SESSION_NAME="$1"
PANE_PATH="$2"

cd "$PANE_PATH" 2>/dev/null || true

# Figure out whether we're in a git worktree that can be removed.
WORKTREE_PATH=""
MAIN_WORKTREE=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null)
    MAIN_WORKTREE=$(git worktree list --porcelain | grep '^worktree ' | head -1 | cut -d' ' -f2-)
    # Only treat linked worktrees (not the main checkout) as removable.
    if [[ "$WORKTREE_PATH" == "$MAIN_WORKTREE" ]]; then
        WORKTREE_PATH=""
    fi
fi

# --- Confirmation ---
echo "Session to kill:   $SESSION_NAME"
if [[ -n "$WORKTREE_PATH" ]]; then
    echo "Worktree to remove: $WORKTREE_PATH"
    STATUS=$(git -C "$WORKTREE_PATH" status --short 2>/dev/null)
    if [[ -n "$STATUS" ]]; then
        echo
        echo "⚠️  Worktree has uncommitted changes — removal will be skipped:"
        echo "$STATUS"
    fi
else
    echo "(not in a removable git worktree — only the session will be killed)"
fi
echo
read -rp "Proceed? [y/N] " ans
case "$ans" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 0 ;;
esac

# --- Remove the worktree first (while the session/popup still exists) ---
if [[ -n "$WORKTREE_PATH" ]]; then
    # cd out of the worktree we're about to delete so git (and the shell) don't
    # sit in a directory that's disappearing. Run git from the main worktree.
    cd "$MAIN_WORKTREE" 2>/dev/null || true
    if git -C "$MAIN_WORKTREE" worktree remove "$WORKTREE_PATH" 2>&1; then
        echo "✓ Removed worktree: $WORKTREE_PATH"
    else
        echo "✗ Failed to remove worktree (likely uncommitted changes)."
        echo "  Session NOT killed. Resolve changes or remove manually with --force."
        read -n1 -rp "Press any key to close."
        exit 1
    fi
fi

# --- Switch away + kill, but AFTER this popup closes ---
# The popup is an overlay anchored to this very session, so a switch-client /
# kill-session issued from inside it gets swallowed — the client can't leave or
# destroy the session it's displaying the popup on. So we defer the work to a
# server-side background job (`run-shell -b`), which outlives the popup process,
# and give the popup a moment to close first. When it fires, no popup is open,
# so switching to the most-recently-attached other session and killing this one
# both work normally. If there's no other session, kill-session exits tmux.
NEXT=$(tmux list-sessions -F '#{session_last_attached} #{session_name}' 2>/dev/null \
        | grep -v " ${SESSION_NAME}$" | sort -rn | head -1 | cut -d' ' -f2-)

DEFERRED="tmux kill-session -t \"$SESSION_NAME\""
if [[ -n "$NEXT" ]]; then
    DEFERRED="tmux switch-client -t \"$NEXT\"; $DEFERRED"
fi

tmux run-shell -b "sleep 0.3; $DEFERRED"
