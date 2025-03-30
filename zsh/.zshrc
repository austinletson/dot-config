# -- Environment Variables --
# Set editor
export EDITOR='nvim'

# Set current year ledger file
export LEDGER_FILE="$HOME/finances/2025.journal"


# -- Aliases --
# vim
alias vim=nvim
alias view="nvim -R"

# Backlight alias 
alias bl="sudo xbacklight -set"

alias ta='tmux attach -t $(tmux list-sessions -F "#{session_name}" | fzf)'
alias tn='tmux new -s'

alias lg="lazygit"


# Always start ssh-agent
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    ssh-agent -t 1h > "$XDG_RUNTIME_DIR/ssh-agent.env"
fi
if [[ ! -f "$SSH_AUTH_SOCK" ]]; then
    source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
fi

# Source private env vars
source ~/.config/zsh/env.sh

# -- vi mode --
bindkey -v
# 10ms for key sequences
KEYTIMEOUT=1
# fix bindkey escape strangeness
bindkey "^?" backward-delete-char


# Configure editing commands in vim
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# -- plugins --
# Pure prompt
fpath+=(~/.config/zsh/pure)
autoload -U promptinit; promptinit
prompt pure

# fzf-tab
autoload -U compinit; compinit
source ~/.config/zsh/fzf-tab/fzf-tab.plugin.zsh

# fish like highlighting and autosuggestions
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# -- setup programs with shell interaction --

# -- FZF --
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# -- Zoxide --
eval "$(zoxide init zsh)"

# -- br --
source /home/austin/.config/broot/launcher/bash/br

# -- python environment --

# Created by `pipx` on 2025-03-19 12:10:26
export PATH="$PATH:/home/austin/.local/bin"

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
