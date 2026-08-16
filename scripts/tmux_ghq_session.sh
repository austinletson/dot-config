#!/bin/bash
# Select a git repository and create or switch to a tmux session.
#
#   Enter       Open the selected repo (default: 1 window)
#   Ctrl-O      Open the selected repo with a 3-window (code/claude/shell) layout
#   Ctrl-F      `ghq get` the pasted URL/owner-repo first, then open it
#               (paste a repo spec like git@github.com:AxiomaticX/lean-extract.git,
#                or https://github.com/AxiomaticX/lean-extract.git, or owner/repo,
#                then press Ctrl-F to fetch and open)

fzf_result=$(ghq list --full-path | fzf \
    --layout=reverse \
    --prompt="Select Git Repository > " \
    --header="Enter=open   Ctrl-O=3-window layout   Ctrl-F=ghq get (paste URL, then Ctrl-F)" \
    --print-query \
    --expect=ctrl-o,ctrl-f)
fzf_exit=$?

# fzf exits non-zero for both cancel (Esc, exit 130, empty output) AND
# no-match accept (exit 1, but still prints query+key). So don't gate on the
# exit code — detect cancel by empty output instead.
if [[ -z "$fzf_result" ]]; then
    exit 0
fi

# --print-query always emits the query on line 1; --expect emits the pressed
# key on line 2 (empty if none); the selected item, if any, is on line 3.
query=$(printf '%s\n' "$fzf_result" | sed -n '1p')
key_pressed=$(printf '%s\n' "$fzf_result" | sed -n '2p')
repo_path=$(printf '%s\n' "$fzf_result" | sed -n '3p')

# Ctrl-F: fetch the pasted query with ghq, then resolve its local path.
if [[ -z "$repo_path" && "$key_pressed" == "ctrl-f" && -n "$query" ]]; then
    echo "Fetching: $query"
    if ! ghq get "$query"; then
        echo
        echo "ghq get failed for: $query"
        echo "Press any key to close..."
        read -n1
        exit 1
    fi

    # ghq stores <root>/<host>/<user>/<project>; `ghq list -e -p` matches
    # "project" or "user/project". Derive that from the pasted spec.
    q="${query%.git}"
    q="${q#ssh://}"; q="${q#git://}"; q="${q#https://}"; q="${q#http://}"
    q="${q#*@}"                      # drop scp-like "git@" user prefix
    before="${q%%[:/]*}"             # text before the first ':' or '/'
    if [[ "$before" == *.* ]]; then  # looks like a host -> drop it + separator
        q="${q#"$before"}"
        q="${q#[:/]}"
    fi

    repo_path=$(ghq list --full-path --exact "$q" | head -n1)
    if [[ -z "$repo_path" ]]; then
        echo "Could not resolve local path for: $query"
        echo "Press any key to close..."
        read -n1
        exit 1
    fi
fi

# Nothing selected and no fetch requested.
if [[ -z "$repo_path" ]]; then
    exit 0
fi

# Sanitize the repo name into a valid tmux session name
# (e.g. "my.project.com" becomes "my-project-com")
session_name=$(basename "$repo_path" | tr . -)

# If the session does NOT exist, create it based on the key press.
if ! tmux has-session -t="$session_name" 2>/dev/null; then
    if [[ "$key_pressed" == "ctrl-o" ]]; then
        # Custom 3-window layout: code (nvim), claude, shell
        tmux new-session -d -s "$session_name" -c "$repo_path" -n "code"
        tmux send-keys -t "$session_name:code" "nvim" C-m
        tmux new-window -t "$session_name" -c "$repo_path" -n "claude"
        tmux new-window -t "$session_name" -c "$repo_path" -n "shell"
        tmux select-window -t "$session_name:code"
    else
        # Default: single-window session
        tmux new-session -d -s "$session_name" -c "$repo_path"
    fi
fi

# If we are inside tmux, switch to the session. Otherwise, attach to it.
if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
