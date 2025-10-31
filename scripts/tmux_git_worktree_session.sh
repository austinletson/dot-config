#!/bin/bash
# A script to be called from within tmux to create a git worktree and a new session.

# The branch name is passed as the first argument from the tmux command-prompt
BRANCH_NAME=$1

if [[ -z "$BRANCH_NAME" ]]; then
    tmux display-message "❌ No branch name provided."
    exit 1
fi

# Find the root of the current git repository
GIT_ROOT=$(git rev-parse --show-toplevel)
if [[ $? -ne 0 ]]; then
    tmux display-message "❌ Not in a git repository."
    exit 1
fi

REPO_NAME=$(basename "$GIT_ROOT")
# Sanitize branch name for the path and session name (e.g., "feature/login" -> "feature-login")
SAFE_BRANCH_NAME=${BRANCH_NAME//\//-}

SESSION_NAME="$REPO_NAME-$SAFE_BRANCH_NAME"
WORKTREE_PATH="$GIT_ROOT/../$SESSION_NAME"

# Check if worktree or session already exists
if [ -d "$WORKTREE_PATH" ] || tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
    tmux display-message "❗️ Worktree or session '$SESSION_NAME' already exists."
    # Optionally, you could switch to it here
    tmux switch-client -t="$SESSION_NAME"
    exit 0
fi

# Create the worktree
git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH"
if [[ $? -ne 0 ]]; then
    tmux display-message "❌ Failed to create git worktree."
    exit 1
fi

tmux display-message "✅ Created worktree at $WORKTREE_PATH"

# Create and switch to the new session
tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_PATH"
tmux switch-client -t "$SESSION_NAME"
