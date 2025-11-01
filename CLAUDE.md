# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository containing shell configuration, terminal multiplexer setup, and editor configuration for a macOS development environment. The configuration is git-tracked and centers around a tmux + neovim + zsh workflow with heavy use of fzf for fuzzy finding.

## Key Configuration Files

- `zsh/zshrc` - Main zsh configuration with vi mode, aliases, and plugin loading
- `tmux/tmux.conf` - Tmux configuration with custom keybindings and session management
- `nvim/init.lua` - Neovim configuration (Kickstart-based)
- `kitty/kitty.conf` - Kitty terminal emulator configuration
- `scripts/` - Custom shell scripts added to PATH

## Custom Tmux Workflow

This configuration has a sophisticated tmux-based project management workflow:

### Session Management Scripts

1. **Git Worktree Sessions** (`tmux_git_worktree_session.sh`)
   - Bound to `Ctrl-A W` in tmux
   - Creates git worktrees and associated tmux sessions
   - Uses fzf to select existing branches or create new ones
   - Session naming: `{repo-name}-worktree-{branch-name}`
   - Worktrees are created as siblings to the main repository

2. **Repository Sessions** (`tmux_ghq_session.sh`)
   - Bound to `Ctrl-A G` in tmux
   - Uses `ghq` for repository management
   - Creates sessions from repositories managed by ghq
   - `Ctrl-O` during selection creates a 3-window layout: code (nvim), claude, shell
   - Default creates single window session

### Tmux Key Bindings

- Prefix: `Ctrl-A` (not default `Ctrl-B`)
- `Ctrl-A G` - Open repository selector (ghq)
- `Ctrl-A W` - Create worktree session
- `Ctrl-A ;` - Quick popup shell
- `Ctrl-A g` - Open lazygit in popup
- `Ctrl-A o` - Session switcher with delete capability (`Alt-d`)
- Vim-style pane navigation: `Ctrl-A h/j/k/l`
- Split panes: `Ctrl-A |` (horizontal), `Ctrl-A -` (vertical)

## Shell Configuration

### Zsh Setup

- Vi mode enabled (KEYTIMEOUT=1 for fast escape)
- Editor: `nvim`
- History shared between tmux sessions (INC_APPEND_HISTORY)
- Custom scripts directory added to PATH: `~/.config/scripts`

### Key Aliases

- `vim` → `nvim`
- `avim` → AstroVim (alternative nvim config)
- `lg` → lazygit
- `mssh` → Interactive morphcloud SSH selector
- `gs` → Interactive git branch switcher with preview
- `ta` → Attach to tmux session (fzf selection)

### Custom Zsh Keybindings

- `Ctrl-E` - Edit command in vim
- `Ctrl-\` - Run current command in new tmux pane
- `Ctrl-P`/`Ctrl-N` - History navigation (insert mode)
- `Alt-C` (typed as `ç` on macOS) - fzf cd widget

### Plugins

- **pure** - Minimal prompt
- **fzf-tab** - Tab completion with fzf
- **zsh-syntax-highlighting** - Fish-like syntax highlighting

## Neovim Configuration

- Based on Kickstart.nvim structure
- Leader key: `Space`
- Configuration split between `init.lua` and `lua/` directory
- Uses lazy.nvim plugin manager (lock file: `lazy-lock.json`)

## Scripts

All scripts in `~/.config/scripts/` are in PATH:

- `flatten_json.py` - Flatten nested JSON structures
- `morphcloud-ssh-fzf.sh` - Interactive SSH selector for morphcloud instances
- `tmux_ghq_session.sh` - Repository session creator
- `tmux_git_worktree_session.sh` - Worktree session creator

## Development Workflow

### Making Changes

When modifying configuration files:
1. Changes are immediately effective for new shells/sessions
2. Existing tmux sessions need manual sourcing: `tmux source ~/.config/tmux/tmux.conf`
3. Zsh changes require: `source ~/.config/zsh/zshrc` or new shell
4. Neovim changes require restart or `:source %`

### Testing Scripts

Scripts can be tested directly:
```bash
bash ~/.config/scripts/script_name.sh
```

Or after changes to PATH-added scripts, start a new shell or `hash -r` to clear the command hash.

## Git Configuration

- `.gitignore` excludes: `raycast/`, `zsh/secrets`, `gcloud/`, `gh/`
- Untracked directories: `git/`, `uv/` (visible in status)
- Repository is actively maintained with frequent commits
- Main branch: `main`

## Environment Details

- Platform: macOS (Darwin)
- Terminal: Kitty
- Shell: Zsh
- Editor: Neovim
- Multiplexer: Tmux
- Repository manager: ghq
- Git UI: lazygit
- Fuzzy finder: fzf (essential dependency)

## Important Dependencies

These tools are required for full functionality:
- `fzf` - Fuzzy finder (critical for most scripts)
- `ghq` - Git repository manager
- `lazygit` - Git TUI
- `tmux` - Terminal multiplexer
- `nvim` - Editor
- `git` - Version control with worktree support
