#!/usr/bin/env python3
"""
A script to be called from within tmux to create a git worktree and a new session.
"""

import os
import subprocess
import sys
from pathlib import Path


def run_command(cmd, capture=True, check=True, cwd=None):
    """Run a shell command and return the result."""
    try:
        if capture:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                check=check,
                cwd=cwd
            )
            return result.stdout.strip(), result.returncode
        else:
            result = subprocess.run(cmd, shell=True, check=check, cwd=cwd)
            return "", result.returncode
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return "", e.returncode


def tmux_message(message):
    """Display a tmux message."""
    run_command(f'tmux display-message "{message}"', capture=False, check=False)


def get_branches():
    """Get all branches for fuzzy finding, excluding current branch.

    Branches are prefixed with indicators:
    - '* branch' = worktree directory exists for this branch (correct checkout)
    - '* branch (other)' = worktree directory exists for this branch but 'other' is checked out
    - '! branch' = branch is checked out in a different worktree directory
    - '  branch' = no worktree directory for this branch
    """
    # Get current branch
    current_branch, _ = run_command("git branch --show-current")

    # Get all branches
    branches_output, _ = run_command(
        "git branch -a --format='%(refname:short)' | "
        "grep -v 'HEAD' | "
        "sed 's/origin\\///' | "
        "sort -u"
    )

    # Filter out current branch
    branches = [
        b for b in branches_output.split('\n')
        if b and b != current_branch
    ]

    # Get worktree map: directory-name -> checked-out branch
    worktree_map = get_all_worktrees_with_status()

    # Add indicators to branch names
    decorated_branches = []
    for branch in branches:
        # Convert branch name to safe directory name (slashes to dashes)
        safe_branch = branch.replace('/', '-')

        # Check if a worktree directory exists for this branch
        if safe_branch in worktree_map:
            checked_out = worktree_map[safe_branch]
            # Worktree directory exists for this branch name
            if checked_out == branch:
                # Correct branch is checked out
                decorated_branches.append(f"* {branch}")
            else:
                # Different branch is checked out - show parenthetical
                decorated_branches.append(f"* {branch} ({checked_out})")
        elif branch in worktree_map.values():
            # This branch is checked out in a different worktree directory
            decorated_branches.append(f"! {branch}")
        else:
            # No worktree directory for this branch
            decorated_branches.append(f"  {branch}")

    # Sort by indicator priority: * first, then !, then regular
    def sort_key(branch):
        indicator = branch[0]
        if indicator == '*':
            priority = 0
        elif indicator == '!':
            priority = 1
        else:
            priority = 2
        # Within each priority, sort alphabetically by branch name (after stripping indicator)
        branch_name = branch.lstrip('*! ')
        if '(' in branch_name:
            branch_name = branch_name[:branch_name.index('(')].strip()
        return (priority, branch_name.lower())

    decorated_branches.sort(key=sort_key)

    return decorated_branches


def branch_exists_locally(branch_name):
    """Check if branch exists locally."""
    _, returncode = run_command(
        f"git show-ref --verify --quiet refs/heads/{branch_name}",
        check=False
    )
    return returncode == 0


def branch_exists_remotely(branch_name):
    """Check if branch exists remotely."""
    _, returncode = run_command(
        f"git show-ref --verify --quiet refs/remotes/origin/{branch_name}",
        check=False
    )
    return returncode == 0


def get_worktree_path(branch_name):
    """Get the worktree path for a branch if it exists."""
    output, _ = run_command("git worktree list --porcelain")

    lines = output.split('\n')
    worktree_path = None

    for i, line in enumerate(lines):
        if line.startswith('worktree '):
            worktree_path = line.split(' ', 1)[1]
        elif line.startswith('branch '):
            branch_ref = line.split(' ', 1)[1]
            if branch_ref == f"refs/heads/{branch_name}":
                return worktree_path
            worktree_path = None

    return None


def get_all_worktrees_with_status():
    """Get all worktrees mapped by their directory-named branch.

    Returns a dict mapping directory-name-branch to checked-out branch:
    - Key: branch name extracted from directory (e.g., "feature-branch")
    - Value: currently checked-out branch in that worktree

    Example: {"feature-A": "feature-A", "old-branch": "new-branch"}
    This shows feature-A worktree has correct branch, but old-branch worktree has new-branch checked out.
    """
    output, _ = run_command("git worktree list --porcelain")

    # Get repo name to parse worktree paths
    main_worktree, _ = run_command(
        "git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2"
    )
    repo_name = os.path.basename(main_worktree)

    worktree_map = {}
    lines = output.split('\n')
    current_worktree = None
    current_branch = None

    def process_entry():
        """Helper to process a complete worktree entry."""
        if current_worktree and current_branch:
            worktree_basename = os.path.basename(current_worktree)
            # Extract expected branch name from worktree path
            # Format: {repo_name}-worktree-{branch_name}
            prefix = f"{repo_name}-worktree-"
            if worktree_basename.startswith(prefix):
                # This is a managed worktree, extract the directory-name branch
                directory_branch = worktree_basename[len(prefix):]
                # Store mapping: directory name -> checked out branch
                worktree_map[directory_branch] = current_branch

    for line in lines:
        if line.startswith('worktree '):
            # Process previous entry before starting new one
            process_entry()
            current_worktree = line.split(' ', 1)[1]
            current_branch = None
        elif line.startswith('branch '):
            branch_ref = line.split(' ', 1)[1]
            if branch_ref.startswith('refs/heads/'):
                current_branch = branch_ref.replace('refs/heads/', '')

    # Process the last entry
    process_entry()

    return worktree_map


def get_git_status(worktree_path):
    """Get git status for a worktree."""
    status_output, returncode = run_command(
        "git status --short",
        cwd=worktree_path,
        check=False
    )

    if returncode != 0:
        return "(error reading status)"

    if not status_output:
        return "(clean)"

    return status_output


def create_fzf_preview_script():
    """Create a temporary preview script for fzf."""
    preview_script = r'''#!/bin/bash
# Strip indicators (*, !, spaces) and parenthetical from branch name
# Example: "* branch (other)" -> "branch", "! branch" -> "branch"
BRANCH_RAW="$1"
BRANCH=$(echo "$BRANCH_RAW" | sed 's/^[*! ]*//' | sed 's/ (.*//')

# Get repo name for constructing worktree path
REPO_NAME=$(basename "$(git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2)")

# Convert branch name to safe directory name (slashes to dashes)
SAFE_BRANCH="${BRANCH//\//-}"

# Look for worktree by directory name pattern first
WORKTREE_PATH=""
DIRECTORY_BRANCH=""
while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.*)$ ]]; then
        path="${BASH_REMATCH[1]}"
        basename=$(basename "$path")
        if [[ "$basename" == "${REPO_NAME}-worktree-${SAFE_BRANCH}" ]]; then
            WORKTREE_PATH="$path"
            DIRECTORY_BRANCH="$BRANCH"
            break
        fi
    fi
done < <(git worktree list --porcelain)

# If not found by directory name, look for worktree by checked-out branch
if [[ -z "$WORKTREE_PATH" ]]; then
    current_path=""
    current_branch=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.*)$ ]]; then
            current_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.*)$ ]]; then
            current_branch="${BASH_REMATCH[1]}"
            if [[ "$current_branch" == "$BRANCH" ]]; then
                WORKTREE_PATH="$current_path"
                # Extract directory branch name
                basename=$(basename "$current_path")
                PREFIX="${REPO_NAME}-worktree-"
                if [[ "$basename" == "$PREFIX"* ]]; then
                    DIRECTORY_BRANCH="${basename#$PREFIX}"
                fi
                break
            fi
        fi
    done < <(git worktree list --porcelain)
fi

echo "Branch: $BRANCH"
echo ""

if [[ -n "$WORKTREE_PATH" ]]; then
    echo "Status: Existing worktree"
    echo "Path: $WORKTREE_PATH"

    # Check for mismatch: directory name vs checked-out branch
    ACTUAL_BRANCH=$(cd "$WORKTREE_PATH" && git branch --show-current)

    if [[ -n "$DIRECTORY_BRANCH" && "$DIRECTORY_BRANCH" != "$ACTUAL_BRANCH" ]]; then
        ACTUAL_SAFE="${ACTUAL_BRANCH//\//-}"
        DIR_SAFE="${DIRECTORY_BRANCH//\//-}"
        if [[ "$DIR_SAFE" != "$ACTUAL_SAFE" ]]; then
            echo ""
            echo "⚠️  MISMATCH DETECTED:"
            echo "   Directory named for: $DIRECTORY_BRANCH"
            echo "   Actually checked out: $ACTUAL_BRANCH"
        fi
    fi

    echo ""
    echo "Git status:"
    cd "$WORKTREE_PATH" && git status --short 2>/dev/null || echo "  (clean)"
elif git show-ref --verify --quiet refs/heads/"$BRANCH"; then
    echo "Status: Local branch"
elif git show-ref --verify --quiet refs/remotes/origin/"$BRANCH"; then
    echo "Status: Remote branch"
else
    echo "Status: New branch (will be created)"
fi
'''

    import tempfile
    fd, path = tempfile.mkstemp(suffix='.sh', text=True)
    with os.fdopen(fd, 'w') as f:
        f.write(preview_script)

    os.chmod(path, 0o755)
    return path


def create_worktree_removal_script():
    """Create a temporary script for removing worktrees."""
    removal_script = r'''#!/bin/bash
# Script to remove a worktree given a decorated branch name

BRANCH_RAW="$1"

# Strip indicators (*, !, spaces) and parenthetical from branch name
BRANCH=$(echo "$BRANCH_RAW" | sed 's/^[*! ]*//' | sed 's/ (.*//')

# Get repo name for constructing worktree path
REPO_NAME=$(basename "$(git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2)")

# Convert branch name to safe directory name (slashes to dashes)
SAFE_BRANCH="${BRANCH//\//-}"

# Look for worktree by directory name pattern first
WORKTREE_PATH=""
while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.*)$ ]]; then
        path="${BASH_REMATCH[1]}"
        basename=$(basename "$path")
        if [[ "$basename" == "${REPO_NAME}-worktree-${SAFE_BRANCH}" ]]; then
            WORKTREE_PATH="$path"
            break
        fi
    fi
done < <(git worktree list --porcelain)

# If not found by directory name, look for worktree by checked-out branch
if [[ -z "$WORKTREE_PATH" ]]; then
    current_path=""
    current_branch=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.*)$ ]]; then
            current_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.*)$ ]]; then
            current_branch="${BASH_REMATCH[1]}"
            if [[ "$current_branch" == "$BRANCH" ]]; then
                WORKTREE_PATH="$current_path"
                break
            fi
        fi
    done < <(git worktree list --porcelain)
fi

if [[ -z "$WORKTREE_PATH" ]]; then
    echo "Error: No worktree found for branch '$BRANCH'"
    exit 1
fi

# Don't allow removing the main worktree
MAIN_WORKTREE=$(git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2)
if [[ "$WORKTREE_PATH" == "$MAIN_WORKTREE" ]]; then
    echo "Error: Cannot remove the main worktree"
    exit 1
fi

# Remove the worktree (without --force)
echo "Removing worktree: $WORKTREE_PATH"
if git worktree remove "$WORKTREE_PATH" 2>&1; then
    echo "✓ Successfully removed worktree for '$BRANCH'"

    # Also kill the associated tmux session if it exists
    SESSION_NAME="${REPO_NAME}-worktree-${SAFE_BRANCH}"
    if tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t="$SESSION_NAME" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "✓ Also killed tmux session '$SESSION_NAME'"
        fi
    else
        echo "ℹ No tmux session found for '$SESSION_NAME'"
    fi
else
    echo "✗ Failed to remove worktree (may have uncommitted changes)"
    exit 1
fi
'''

    import tempfile
    fd, path = tempfile.mkstemp(suffix='.sh', text=True)
    with os.fdopen(fd, 'w') as f:
        f.write(removal_script)

    os.chmod(path, 0o755)
    return path


def create_worktree_force_removal_script():
    """Create a temporary script for force-removing worktrees."""
    removal_script = r'''#!/bin/bash
# Script to force-remove a worktree given a decorated branch name

BRANCH_RAW="$1"

# Strip indicators (*, !, spaces) and parenthetical from branch name
BRANCH=$(echo "$BRANCH_RAW" | sed 's/^[*! ]*//' | sed 's/ (.*//')

# Get repo name for constructing worktree path
REPO_NAME=$(basename "$(git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2)")

# Convert branch name to safe directory name (slashes to dashes)
SAFE_BRANCH="${BRANCH//\//-}"

# Look for worktree by directory name pattern first
WORKTREE_PATH=""
while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.*)$ ]]; then
        path="${BASH_REMATCH[1]}"
        basename=$(basename "$path")
        if [[ "$basename" == "${REPO_NAME}-worktree-${SAFE_BRANCH}" ]]; then
            WORKTREE_PATH="$path"
            break
        fi
    fi
done < <(git worktree list --porcelain)

# If not found by directory name, look for worktree by checked-out branch
if [[ -z "$WORKTREE_PATH" ]]; then
    current_path=""
    current_branch=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.*)$ ]]; then
            current_path="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.*)$ ]]; then
            current_branch="${BASH_REMATCH[1]}"
            if [[ "$current_branch" == "$BRANCH" ]]; then
                WORKTREE_PATH="$current_path"
                break
            fi
        fi
    done < <(git worktree list --porcelain)
fi

if [[ -z "$WORKTREE_PATH" ]]; then
    echo "Error: No worktree found for branch '$BRANCH'"
    exit 1
fi

# Don't allow removing the main worktree
MAIN_WORKTREE=$(git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2)
if [[ "$WORKTREE_PATH" == "$MAIN_WORKTREE" ]]; then
    echo "Error: Cannot remove the main worktree"
    exit 1
fi

# Force remove the worktree (with --force)
echo "⚠️  Force removing worktree: $WORKTREE_PATH"
echo "⚠️  (uncommitted changes will be lost)"
if git worktree remove --force "$WORKTREE_PATH" 2>&1; then
    echo "✓ Successfully force-removed worktree for '$BRANCH'"

    # Also kill the associated tmux session if it exists
    SESSION_NAME="${REPO_NAME}-worktree-${SAFE_BRANCH}"
    if tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t="$SESSION_NAME" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "✓ Also killed tmux session '$SESSION_NAME'"
        fi
    else
        echo "ℹ No tmux session found for '$SESSION_NAME'"
    fi
else
    echo "✗ Failed to force-remove worktree"
    exit 1
fi
'''

    import tempfile
    fd, path = tempfile.mkstemp(suffix='.sh', text=True)
    with os.fdopen(fd, 'w') as f:
        f.write(removal_script)

    os.chmod(path, 0o755)
    return path


def create_branch_list_reload_script():
    """Create a temporary script for reloading the branch list in fzf."""
    # Get the absolute path to this script
    script_path = os.path.abspath(__file__)

    reload_script = f'''#!/usr/bin/env python3
import sys
import os

# Add script directory to path
sys.path.insert(0, os.path.dirname("{script_path}"))

# Import and call get_branches
from tmux_git_worktree_session import get_branches

branches = get_branches()
for branch in branches:
    print(branch)
'''

    import tempfile
    fd, path = tempfile.mkstemp(suffix='.py', text=True)
    with os.fdopen(fd, 'w') as f:
        f.write(reload_script)

    os.chmod(path, 0o755)
    return path


def select_branch_with_fzf(branches):
    """Use fzf to select or create a branch."""
    if not branches:
        return None

    # Create helper scripts
    preview_script = create_fzf_preview_script()
    removal_script = create_worktree_removal_script()
    force_removal_script = create_worktree_force_removal_script()
    reload_script = create_branch_list_reload_script()

    # Sibling prune script (removes stale, clean, session-less worktrees).
    prune_script = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "tmux_prune_worktrees.py"
    )

    try:
        # Write branches to a temporary file
        import tempfile
        fd, branches_file = tempfile.mkstemp(text=True)
        with os.fdopen(fd, 'w') as f:
            f.write('\n'.join(branches))

        # Run fzf
        fzf_cmd = [
            'fzf',
            '--prompt=Select branch or type new name: ',
            '--print-query',
            '--height=100%',
            '--border',
            '--info=inline',
            '--layout=reverse',
            f'--preview={preview_script} {{}}',
            '--preview-window=right:50%:wrap',
            '--bind=enter:accept',
            f'--bind=alt-d:execute({removal_script} {{}})+reload({reload_script})',
            f'--bind=alt-D:execute({force_removal_script} {{}})+reload({reload_script})',
            f'--bind=alt-p:execute(python3 {prune_script} --delete --days 7; '
            f'read -n1 -rp "Press any key...")+reload({reload_script})',
            '--header=Alt-D: Remove | Alt-Shift-D: Force remove | Alt-P: Prune >1wk stale'
        ]

        result = subprocess.run(
            fzf_cmd,
            stdin=open(branches_file, 'r'),
            capture_output=True,
            text=True
        )

        # Clean up
        os.unlink(branches_file)

        # Parse output first (fzf with --print-query outputs query on first line, selection on last)
        lines = result.stdout.strip().split('\n')

        # If user cancelled (Esc), output will be empty
        if result.returncode != 0 and not result.stdout.strip():
            return None

        # With --print-query: first line is the query, last line is the selection
        # If user typed something but didn't select (new branch), use the query
        if len(lines) == 1:
            # Only query, no selection - use the query (new branch scenario)
            selected = lines[0]
        else:
            # Multiple lines - prefer selection (last line), fall back to query (first line) if empty
            selected = lines[-1] if lines[-1] else lines[0]

        # Strip indicators (*, !, and leading spaces) and parenthetical from the branch name
        # Example: "* branch (other)" -> "branch", "! branch" -> "branch"
        if selected:
            selected = selected.lstrip('*! ')
            # Remove parenthetical if present
            if '(' in selected:
                selected = selected[:selected.index('(')].strip()

        return selected

    finally:
        # Clean up helper scripts
        os.unlink(preview_script)
        os.unlink(removal_script)
        os.unlink(force_removal_script)
        os.unlink(reload_script)


def create_worktree(branch_name, worktree_path):
    """Create a git worktree for the branch."""
    if branch_exists_locally(branch_name):
        # Branch exists locally
        tmux_message(f"🔄 Creating worktree for existing local branch '{branch_name}'...")
        _, returncode = run_command(
            f'git worktree add "{worktree_path}" "{branch_name}"',
            capture=False,
            check=False
        )
    elif branch_exists_remotely(branch_name):
        # Branch exists remotely, create local tracking branch
        tmux_message(f"🔄 Creating worktree for remote branch '{branch_name}'...")
        _, returncode = run_command(
            f'git worktree add -b "{branch_name}" "{worktree_path}" "origin/{branch_name}"',
            capture=False,
            check=False
        )
    else:
        # New branch
        tmux_message(f"🔄 Creating worktree for new branch '{branch_name}'...")
        _, returncode = run_command(
            f'git worktree add -b "{branch_name}" "{worktree_path}"',
            capture=False,
            check=False
        )

    return returncode == 0


def create_and_switch_to_session(session_name, worktree_path):
    """Create a new tmux session and switch to it."""
    run_command(
        f'tmux new-session -d -s "{session_name}" -c "{worktree_path}"',
        capture=False
    )
    run_command(
        f'tmux switch-client -t "{session_name}"',
        capture=False
    )


def main():
    # Get branch name from argument if provided
    if len(sys.argv) > 1:
        branch_name = sys.argv[1]
    else:
        # Check if fzf is available
        _, returncode = run_command("command -v fzf", check=False)
        if returncode != 0:
            tmux_message("❌ fzf not found. Please install fzf or provide branch name as argument.")
            sys.exit(1)

        # Get branches and use fzf to select
        try:
            branches = get_branches()
        except Exception as e:
            tmux_message(f"❌ Error getting branches: {e}")
            sys.exit(1)

        branch_name = select_branch_with_fzf(branches)

        if not branch_name:
            tmux_message("❌ No branch selected.")
            sys.exit(1)

    # Find the root of the current git repository
    git_root, returncode = run_command("git rev-parse --show-toplevel", check=False)
    if returncode != 0:
        tmux_message("❌ Not in a git repository.")
        sys.exit(1)

    # Get the actual repo name from the main worktree
    main_worktree, _ = run_command(
        "git worktree list --porcelain | grep '^worktree' | head -1 | cut -d' ' -f2"
    )
    repo_name = os.path.basename(main_worktree)

    # Sanitize branch name for the path and session name
    safe_branch_name = branch_name.replace('/', '-')

    session_name = f"{repo_name}-worktree-{safe_branch_name}"
    worktree_path = os.path.join(os.path.dirname(git_root), session_name)

    # Check if tmux session exists first
    _, returncode = run_command(
        f'tmux has-session -t="{session_name}"',
        check=False
    )
    if returncode == 0:
        tmux_message(f"✅ Switching to existing session '{session_name}'")
        run_command(f'tmux switch-client -t="{session_name}"', capture=False, check=False)
        sys.exit(0)

    # Check if worktree exists (but session doesn't, since we got here)
    if os.path.isdir(worktree_path):
        tmux_message(f"✅ Worktree exists, creating session '{session_name}'")
        create_and_switch_to_session(session_name, worktree_path)
        sys.exit(0)

    # Create the worktree
    if not create_worktree(branch_name, worktree_path):
        tmux_message("❌ Failed to create git worktree.")
        sys.exit(1)

    tmux_message(f"✅ Created worktree at {worktree_path}")

    # Create and switch to the new session
    create_and_switch_to_session(session_name, worktree_path)


if __name__ == "__main__":
    # Change to the directory where tmux was called from
    pane_path, _ = run_command("tmux display-message -p '#{pane_current_path}'")
    if pane_path:
        os.chdir(pane_path)

    main()
