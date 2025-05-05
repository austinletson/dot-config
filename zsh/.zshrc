# -- Environment Variables --
# Set editor
export EDITOR='nvim'

# Set current year ledger file
export LEDGER_FILE="$HOME/finances/2025.journal"

# -- History Configuration --
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=10000

# -- Aliases --
# vim
alias vim=nvim
alias view="nvim -R"

# Backlight alias 
alias bl="sudo xbacklight -set"

alias ta='tmux attach -t $(tmux list-sessions -F "#{session_name}" | fzf)'
alias tn='tmux new -s'

alias lg="lazygit"

# Miller
alias mcsv='mlr --csv --from'
alias mcsvp='mlr --csv --opprint --from'

# Git
alias gs="git branch --sort=-committerdate | fzf --preview 'git show --color=always {-1}' --tmux --height 40% --layout reverse \
--bind 'enter:become(git switch {-1})'"

# append history to share between tmux sessions
setopt inc_append_history


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

# Ctrl-P and Ctrl-N to scroll through recent history in insert mode
bindkey -M viins '^P' up-history
bindkey -M viins '^N' down-history


# Configure editing commands in vim
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line

# OSC 133 prompt jump so tmux can jump to last prompt
preexec () {
  echo -n "\\x1b]133;A\\x1b\\"
}

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
