# vim:foldmethod=marker:foldlevel=0

# NOTE: zsh files are loaded in the following order:
# .zshenv               - contains exported variables
# .zprofile if login    - basically same as .zlogin but sourced before .zshrc
# .zshrc if interactive - set options, load shell modules, etc
# .zlogin if login      - startx
# .zlogout sometimes    - clear/reset terminal

# NOTE: what is/should I set $ZDOTDIR ?

# Source zprofile {{{

# termite/tmux is not a login shell, thus does not load (z)profile
if [[ "$TERM" == 'xterm-termite' || "$TERM" == 'screen' ]]; then
  source "$HOME/.zprofile"
  # XDG_CONFIG_HOME="$HOME/.config"
  # PANEL_WM_NAME=bspwm_panel
  # PANEL_FIFO="/tmp/panel-fifo"
  # PANEL_HEIGHT=35

  # export PANEL_FIFO PANEL_HEIGHT PANEL_WM_NAME XDG_CONFIG_HOME

  # # Golang
  # export GOPATH=~/go
  # if [ ! -d ~/go/bin ]; then
  #   mkdir -p ~/go/{bin,src}
  # fi
fi

# }}}
# INTERNAL UTILITY FUNCTIONS {{{1

# NOTE: These are taken from github.com/statico/dotfiles/.zshrc

# Returns whether the given command is executable or aliased.
function _has () {
  return $( whence $1 >/dev/null )
}

# Returns whether the given statement executed cleanly. Try to avoid this
# because this slows down shell loading.
function _try () {
  return $( eval $* >/dev/null 2>&1 )
}

# Returns whether the current host type is what we think it is. (HOSTTYPE is
# set later.)
function _is () {
  return $( [ "$HOSTTYPE" = "$1" ] )
}

# Returns whether out terminal supports color.
function _color () {
  return $( [ -z "$INSIDE_EMACS" ] )
}

function _command_exists () {
    type "$1" > /dev/null 2>&1
}

# }}}
# ZSHENV {{{

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

export ZPLUG_HOME="$HOME/.zplug"
ZSH_DIR=$HOME/dotfiles/zsh

SCRIPTS_PATH="$HOME/dotfiles/scripts" && [ -d "$SCRIPTS_PATH" ] || SCRIPTS_PATH=""
OS161_PATH="/opts/os161/bin" && [ -d "$OS161_PATH" ] || OS161_PATH=""
HEROKU_PATH="/usr/local/heroku/bin" && [ -d "$HEROKU_PATH" ] || HEROKU_PATH=""
RBENV_PATH="$HOME/.rbenv" && [ -d "$RBENV_PATH" ] || RBENV_PATH=""
NPM_BIN_PATH="$HOME/node_modules/.bin" && [ -d "$NPM_BIN_PATH" ] || NPM_BIN_PATH=""
CARGO_BIN_PATH="/home/j1n/.cargo/bin" && [ -d "$CARGO_BIN_PATH" ] || CARGO_BIN_PATH=""

path=(
  ~/.bin
  ~/.local/{bin,sbin}
  /usr/local/{bin,sbin}
  /usr/bin
  /usr/bin/{site,vendor,core}_perl
  $path
)

export PATH="$CARGO_BIN_PATH:$NPM_BIN_PATH:$HEROKU_PATH:$SCRIPTS_PATH:$GOPATH/bin:$OS161_PATH:${PATH}"

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# rbenv || rvm
if [ -d "$RBENV_PATH" ]; then
  [ -d "$RBENV_PATH/bin" ] && export PATH="$RBENV_PATH/bin:$PATH"

  _command_exists rbenv && eval "$(rbenv init -)"

  [ -d "$RBENV_PATH/plugins/ruby-build/bin" ] && \
    export PATH="$RBENV_PATH/plugins/ruby-build/bin:$PATH"
elif [ -d ~/.rvm ]; then
  [ -d "$HOME/.rvm/bin" ] && export PATH="$HOME/.rvm/bin:$PATH"
  source ~/.rvm/scripts/rvm
fi

export ZSH_CACHE_DIR="$HOME/.zsh/cache"

# Set the the list of directories that cd searches.
cdpath+=(~)
cdpath+=(~/github)
cdpath+=(~/tryout)

# }}}
# USER CONFIGURATION {{{

# vi mode
bindkey -v

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# }}}
# PLUGINS {{{

if [ ! -d $ZPLUG_HOME ]; then
  git clone https://github.com/zplug/zplug $ZPLUG_HOME
fi

source $ZPLUG_HOME/init.zsh

# Theme!
# zplug "mafredri/zsh-async", from:github, defer:0
# zplug "sindresorhus/pure",  use:pure.zsh, from:github, as:theme

zplug "denysdovhan/spaceship-prompt", use:spaceship.zsh, from:github, as:theme

# Let zplug manage zplug
zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# Oh-My-Zsh
zplug "plugins/vi-mode",           from:oh-my-zsh, ignore:oh-my-zsh.sh
zplug "plugins/archlinux",         from:oh-my-zsh, ignore:oh-my-zsh.sh
zplug "plugins/colored-man-pages", from:oh-my-zsh, ignore:oh-my-zsh.sh
zplug "plugins/gem",               from:oh-my-zsh, ignore:oh-my-zsh.sh
zplug "plugins/golang",            from:oh-my-zsh, ignore:oh-my-zsh.sh
zplug "plugins/npm",               from:oh-my-zsh, ignore:oh-my-zsh.sh
zplug "plugins/pip",               from:oh-my-zsh, ignore:oh-my-zsh.sh

# Misc Plugins
zplug "gusaiani/elixir-oh-my-zsh",        from:github
zplug "zdharma/fast-syntax-highlighting", from:github
# zplug "marzocchi/zsh-notify",             from:github

# FZF Related
zplug "urbainvaes/fzf-marks", from:github
# NOTE: zplug "ytet5uy4/fzf-widgets", from:github is interesting but unneeded ATM.

# Completions
zplug "srijanshetty/zsh-pandoc-completion", from:github

# Zsh-users
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-autosuggestions"

if ! zplug check --verbose; then
  printf "Install zplug plugins? [y/N]: "
  if read -q; then
    echo; zplug install
  fi
fi

# NOTE: this needs to be placed last or else some plugins (e.g. fancy-ctrl-z)
# aren't loaded properly.
zplug load --verbose > "/tmp/.zplug-load.log"

# }}}
# Load MODULES {{{
# export ZSH=$HOME/.zsh
# ln -s $HOME/dotfiles/zsh $ZSH

# NOTE: The order that the modules are loaded in is IMPORTANT!
#       Do NOT change the order arbitrarily.
MODULES=(
  'options'
  'env'
  'alias'
  'completion'
  'directories'
  'grep'
  'functions'
  'edit'
  'history'
  'fzf'
  'fzf-git'
  'key-bindings'
  'golang'
  'reddit'
  'color-functions'
  'colors'
)

for module in $MODULES
do
  if [ -e $ZSH_DIR/etc/$module.zsh ]; then
    source $ZSH_DIR/etc/$module.zsh
  fi
done
unset MODULES

# }}}
# PLUGIN CONFIG {{{

source $ZSH_DIR/etc/spaceship-options.zsh

if zplug list | search "zsh-autosuggestions" > /dev/null; then
  source $ZSH_DIR/config/autosuggestions.zsh
fi

# }}}
# MISC {{{

# Required for Termite ctrl+shift+t: open terminal in current dir
if [[ $TERM == xterm-termite ]]; then
  . /etc/profile.d/vte.sh
  __vte_osc7
fi

# Vi-mode INSERT/NORMAL indicator (right hand side)
# FIXME: unused currently this needs to be placed below the theme/vi-mode plugin load.
# function zle-line-init zle-keymap-select {
#     RPS1="${${KEYMAP/vicmd/[ NORMAL ]}/(main|viins)/-- INSERT --}"
#     RPS2=$RPS1
#     zle reset-prompt
# }

# NOTE: the below is from vi-mode.plugin.zsh edited to use NORMAL and INSERT,
# instead of <<<
# function vi_mode_prompt_info() {
#   echo "${${KEYMAP/vicmd/[ NORMAL ]}/(main|viins)/-- INSERT --}"
# }

# # define right prompt, if it wasn't defined by a theme
# if [[ "$RPS1" == "" && "$RPROMPT" == "" ]]; then
#   RPS1='$(vi_mode_prompt_info)'
# fi

# Enable math functions
zmodload zsh/mathfunc

# "command not found" hook for official packages.
if which pkgfile > /dev/null ; then
  source /usr/share/doc/pkgfile/command-not-found.zsh
fi

# }}}
# FZF {{{

[ -f /etc/profile.d/fzf-extras.bash ] && source /etc/profile.d/fzf-extras.bash
[ -f /etc/profile.d/fzf-extras.zsh ] && source /etc/profile.d/fzf-extras.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf + ag configuration
if _has fzf && _has ag; then
  export FZF_DEFAULT_COMMAND='ag -nocolor -g ""'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# }}}

# Set Solarized theme colors based on night/day {{{
if [ "$TERM" == 'xterm-termite' ]; then
  # Init and Set Termite colors
  switchtheme.sh
fi

# }}}

# Check for a local zshrc file {{{
if [[ -r ~/.zsh.local ]]; then
  source ~/.zsh.local
fi
# }}}

# Autorun startup.sh ONCE at log in. {{{
startuptmpfile="/tmp/startup_done"
if ! [ -e "$startuptmpfile" ]; then

  # MOTD + TODO
  source $ZSH_DIR/utilities/motd.zsh
  source $ZSH_DIR/utilities/todo.zsh

  echo
  printf "Run startup script? [y/N] "; read -r -k 1
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if $HOME/dotfiles/scripts/startup.sh ; then touch "$startuptmpfile"; fi
  elif [[ $REPLY =~ ^N$ ]]; then
    touch "$startuptmpfile"
  fi
fi
# }}}

# Don't end with errors.
true
