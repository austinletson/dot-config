#!/usr/bin/env bash

# Script to interactively select and SSH into a morphcloud instance using fzf

set -euo pipefail

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install it first." >&2
    exit 1
fi

# Check if morphcloud is installed
if ! command -v morphcloud &> /dev/null; then
    echo "Error: morphcloud is not installed." >&2
    exit 1
fi

# Get the list of instances
instances=$(morphcloud instance ls)

if [ -z "$instances" ]; then
    echo "No instances found." >&2
    exit 1
fi

# Extract just the data rows (skip header, separator lines, and summary)
data_lines=$(echo "$instances" | grep -E '^morphvm_' || true)

if [ -z "$data_lines" ]; then
    echo "No instances available." >&2
    exit 1
fi

# Use fzf to select an instance, showing full instance list in preview
selected=$(echo "$data_lines" | fzf \
    --header="Select a morphcloud instance to SSH into" \
    --preview="echo '$instances'" \
    --preview-window=up:50% \
    --height=100% \
    --border \
    --prompt="Instance > " \
    --pointer="→" \
    --layout=reverse)

if [ -z "$selected" ]; then
    echo "No instance selected." >&2
    exit 0
fi

# Extract the instance ID (first column)
instance_id=$(echo "$selected" | awk '{print $1}')

echo "Connecting to instance: $instance_id"
morphcloud instance ssh "$instance_id"
