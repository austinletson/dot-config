if status is-interactive
    # Commands to run in interactive sessions can go here
end

abbr -a hx helix


set fish_key_bindings fish_user_key_bindings

set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin /home/austin/.ghcup/bin $PATH # ghcup-env

# Set up pyenv (added for Airflow development)
pyenv init - | source
