#!/bin/bash
# A script to be called from within tmux to create a git worktree and a new session.

# Function to display tmux messages
tmux_message() {
    tmux display-message "$1"
}

# Function to get all branches for fuzzy finding
get_branches() {
    git branch -a --format='%(refname:short)' | \
        grep -v "HEAD" | \
        grep -v "^$(git branch --show-current)$" | \
        sed 's/origin\///' | \
        sort -u
}

# Function to check if branch exists locally
branch_exists_locally() {
    git show-ref --verify --quiet refs/heads/"$1"
}

# Function to check if branch exists remotely
branch_exists_remotely() {
    git show-ref --verify --quiet refs/remotes/origin/"$1"
}


# Change to the directory where tmux was called from
cd "$(tmux display-message -p '#{pane_current_path}')"

# If branch name is provided as argument, use it directly
if [[ -n "$1" ]]; then
    BRANCH_NAME="$1"
else
    # Use fzf for branch selection/creation
    if ! command -v fzf &> /dev/null; then
        tmux_message "❌ fzf not found. Please install fzf or provide branch name as argument."
        exit 1
    fi

    # Create a temporary file for fzf input
    TEMP_BRANCHES=$(mktemp)
    get_branches > "$TEMP_BRANCHES"

    # Use fzf with custom prompt and allow new input
    BRANCH_NAME=$(cat "$TEMP_BRANCHES" | fzf \
        --prompt="Select branch or type new name: " \
        --print-query \
        --height=100% \
        --border \
        --info=inline \
        --layout=reverse \
        --preview="echo 'Branch: {}'; if git show-ref --verify --quiet refs/heads/{}; then echo 'Status: Local branch'; elif git show-ref --verify --quiet refs/remotes/origin/{}; then echo 'Status: Remote branch'; else echo 'Status: New branch (will be created)'; fi" \
        --preview-window=bottom:3:wrap \
        --bind="enter:accept" | tail -n1)
    
    rm "$TEMP_BRANCHES"
    
    # Check if user cancelled
    if [[ -z "$BRANCH_NAME" ]]; then
        tmux_message "❌ No branch selected."
        exit 1
    fi
fi

# Find the root of the current git repository
GIT_ROOT=$(git rev-parse --show-toplevel)
if [[ $? -ne 0 ]]; then
    tmux_message "❌ Not in a git repository."
    exit 1
fi

# Get the actual repo name from the main worktree
MAIN_WORKTREE=$(git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2)
REPO_NAME=$(basename "$MAIN_WORKTREE")

# Sanitize branch name for the path and session name
SAFE_BRANCH_NAME=${BRANCH_NAME//\//-}

SESSION_NAME="$REPO_NAME-worktree-$SAFE_BRANCH_NAME"
WORKTREE_PATH="$GIT_ROOT/../$SESSION_NAME"

# Check if worktree or session already exists
if [ -d "$WORKTREE_PATH" ] || tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
    tmux_message "❗️ Worktree or session '$SESSION_NAME' already exists."
    # Switch to existing session
    tmux switch-client -t="$SESSION_NAME"
    exit 0
fi

# Determine how to create the worktree based on branch existence
if branch_exists_locally "$BRANCH_NAME"; then
    # Branch exists locally
    tmux_message "🔄 Creating worktree for existing local branch '$BRANCH_NAME'..."
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
elif branch_exists_remotely "$BRANCH_NAME"; then
    # Branch exists remotely, create local tracking branch
    tmux_message "🔄 Creating worktree for remote branch '$BRANCH_NAME'..."
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "origin/$BRANCH_NAME"
else
    # New branch
    tmux_message "🔄 Creating worktree for new branch '$BRANCH_NAME'..."
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH"
fi

if [[ $? -ne 0 ]]; then
    tmux_message "❌ Failed to create git worktree."
    exit 1
fi

tmux_message "✅ Created worktree at $WORKTREE_PATH"

# Create and switch to the new session
tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_PATH"
tmux switch-client -t "$SESSION_NAME"
