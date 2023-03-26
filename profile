# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# Put stuff that applies to your whole session, such as programs that you want
# to start when you login, and environment variable definitions

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

export XDG_CONFIG_HOME="$HOME/.config"

# vim
if command -v nvim &> /dev/null; then
    export GIT_EDITOR=nvim
    export EDITOR=nvim
    export VISUAL=nvim
elif command -v vim &> /dev/null; then
    export GIT_EDITOR=vim
    export EDITOR=vim
    export VISUAL=vim
else
    export GIT_EDITOR=vi
fi

test -d "$HOME/.rbenv/bin" && export PATH="$HOME/.rbenv/bin:$PATH" || true

test -s "$HOME/.nix-profile/etc/profile.d/nix.sh" && source $HOME/.nix-profile/etc/profile.d/nix.sh || true
