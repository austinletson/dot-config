#!/bin/bash
# A script to select a git repository and create or switch to a tmux session.
# Supports a custom layout when started with Ctrl-O.

# Use fzf to select a repository.
# --expect=ctrl-o tells fzf to listen for that key and print it on the first line of output.
# Compatible with older bash versions
fzf_result=$(ghq list --full-path | fzf --prompt="Select Git Repository > " --expect=ctrl-o)

# Exit if fzf was cancelled (e.g., user pressed Esc)
if [[ -z "$fzf_result" ]]; then
    exit 0
fi

# Extract the key pressed and the selected repository path
# Split the result by newlines
key_pressed=$(echo "$fzf_result" | head -n1)
repo_path=$(echo "$fzf_result" | tail -n1)

# If only one line returned, it means no special key was pressed
if [[ "$key_pressed" == "$repo_path" ]]; then
    key_pressed=""
fi

# Sanitize the repo name to create a valid tmux session name
# (e.g., "my.project.com" becomes "my-project-com")
session_name=$(basename "$repo_path" | tr . -)

# If the session already exists, just switch to it, regardless of the key pressed.
if tmux has-session -t="$session_name" 2>/dev/null; then
    # Fall-through to the attach/switch logic at the end
    :
# If the session does NOT exist, create it based on the key press.
else
    # --- This is the new conditional logic ---
    if [[ "$key_pressed" == "ctrl-o" ]]; then
        # Create a session with a custom 3-window layout
        tmux new-session -d -s "$session_name" -c "$repo_path" -n "code"
        tmux send-keys -t "$session_name:code" "nvim" C-m

        tmux new-window -t "$session_name" -c "$repo_path" -n "claude"
        tmux new-window -t "$session_name" -c "$repo_path" -n "shell"
        
        # Select the first window (code) to be active by default
        tmux select-window -t "$session_name:code"
    else
        # Default behavior: create a simple session with one window
        tmux new-session -d -s "$session_name" -c "$repo_path"
    fi
fi

# If we are inside tmux, switch to the session. Otherwise, attach to it.
if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
