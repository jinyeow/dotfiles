# Taken from https://github.com/zeroxfourc/ludvigit/blob/master/config/ingarill.zshrc

# load things
autoload -U colors && colors
autoload -U compinit && compinit
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

zmodload -i zsh/complist

setopt always_to_end
setopt auto_cd
setopt auto_menu
setopt auto_pushd
setopt cdable_vars
setopt combining_chars
setopt complete_in_word
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify
setopt inc_append_history
setopt interactive_comments
setopt long_list_jobs
setopt multios
setopt no_flow_control
setopt no_menu_complete
setopt prompt_subst
setopt pushd_ignore_dups
setopt pushd_minus
setopt share_history

# completion
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' rehash true
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path "$HOME/.zsh_cache"

# pkgfile integration
. /usr/share/doc/pkgfile/command-not-found.zsh

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# pager
export PAGER="less"
export LESS="-FKMRX"

# editor and browser
if [[ -n "$SSH_CONNECTION" || -z "$DISPLAY" ]] ; then
	export EDITOR="nano"
	export BROWSER="w3m"
else
	export EDITOR="gedit"
	export BROWSER="firefox"
fi

# keybindings
bindkey '\e[A' up-line-or-beginning-search
bindkey '\e[B' down-line-or-beginning-search

# aliases and functions
alias sudo='sudo ' # this makes aliases work when run with sudo

alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

alias pc='pacaur'
alias pci='pacaur -S'
alias pcr='pacaur -Rsc'
alias pcu='pacaur -Syu'
alias pcud='pacaur -Syu --devel'
alias pcs='pacaur -Ss'

alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gcl='git clone --recursive'
alias gcm='git commit -vm'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'

alias shutdown='systemctl poweroff'
alias reboot='systemctl reboot'
alias suspend='systemctl suspend'
alias hibernate='systemctl hibernate'
alias emergency='systemctl emergency'

alias ls='ls --color=auto --group-directories-first'
alias l='ls -lNFh'
alias la='ls -lNAFh'
alias ldot='ls -lNFhd .*'
alias rm='rm -ri'
alias cp='cp -ri'
alias mv='mv -i'
alias srm='srm -ri'
alias grep='grep --color=auto -n'

alias history='fc -il 1 | less +G'
alias su='sudo -i'
alias manh='man -H'
alias x='exit'
alias cmd="wine cmd"
alias pkgfiles='pkgfile -l'

if [[ -z "$SSH_CONNECTION" && -z "$DISPLAY" ]] ; then
	alias sx='startx'
else
	alias sx='false'
fi

function open {
	if [[ -z "$@" ]] ; then
		file="."
	else
		file="$@"
	fi
	nohup xdg-open "$file" &>/dev/null
}

function path {
	if [[ -z "$@" ]] ; then
		echo $PATH
	else
		export PATH="$@"
	fi
}

function say {
	if [[ -z "$@" ]] ; then
		echo "Say what?" >&2
		return 1
	fi
	espeak -v en --stdout "$@" | paplay
}

function säg {
	if [[ -z "$@" ]] ; then
		echo "Säg vadå?" >&2
		return 1
	fi
	espeak -v sv --stdout "$@" | paplay
}

# prompt
prompt_dir='%{$fg_no_bold[cyan]%}%~%{$reset_color%}'
prompt_emoji='%(?.%{$fg_no_bold[green]%}👌%{$reset_color%}.%{$fg_bold[red]%}%?%{$fg_no_bold[red]%}👋%{$reset_color%})'
prompt_host='%{$fg_bold[cyan]%}%m%{$reset_color%}'
prompt_user='%{$fg_bold[cyan]%}%n%{$reset_color%}'
prompt_tail='%{$fg_bold[white]%}»%{$reset_color%}'

PROMPT="${prompt_user}@${prompt_host} ${prompt_dir} ${prompt_tail} "
RPROMPT="${prompt_emoji}"

unset prompt_dir prompt_emoji prompt_host prompt_user prompt_tail
