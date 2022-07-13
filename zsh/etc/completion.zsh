###############################################################################
#                             COMPLETION                                      #
#                         ------------------                                  #
###############################################################################

# Prepend to fpath
fpath=(
  $HOME/dotfiles/zsh/zsh-completions
  $ZPLUG_HOME/repos/zsh-users/zsh-completions/src
  $fpath
)

autoload -U $HOME/dotfiles/zsh/zsh-completions/*(:t)
# autoload -U $ZPLUG_HOME/repos/zsh-users/zsh-completions/src/*(:t)

# Load menu-style completion.
zmodload -i zsh/complist
bindkey -M menuselect '^M' accept

# The following lines were added by compinstall

zstyle ':completion:*' use-perl true
zstyle ':completion:*' auto-description '%d'
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' completions 1
zstyle ':completion:*' expand prefix suffix
zstyle ':completion:*' format $'\n%BCompleting %d%b'
zstyle ':completion:*' glob 1
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd directory
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' list-suffixes true
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' max-errors 5
zstyle ':completion:*' menu select=0
zstyle ':completion:*' original false
zstyle ':completion:*' preserve-prefix '//[^/]##/'
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p (%l)%s
zstyle ':completion:*' verbose true

zstyle :compinstall filename "$HOME/dotfiles/zsh/etc/completion.zsh"

autoload -Uz compinit
compinit
# End of lines added by compinstall

# From oh-my-zsh/lib/completion.zsh (can't see any difference based on some simple tests)
# zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'r:|=*' 'l:|=* r:|=*'
# zstyle ':completion:*' menu select

# Used to look up the format style for warnings
zstyle ':completion:*:warnings' format 'No matches for: %d'

# Use a cache for completions to speed things up
zstyle ':completion:*' use-cache true

# Sets the cache location
zstyle ':completion:*' cache-path $ZSH_CACHE_DIR

# Organizing completions by category
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format $'\n%B%d%b'

# Ignore useless files, like .pyc.
zstyle ':completion:*:(all-|)files' ignored-patterns '(|*/).pyc'

# Completing process IDs with menu selection.
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

# Make zsh know about hosts already accessed by SSH
zstyle -e ':completion:*:(ssh|scp|sftp|rsh|rsync):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

# Specific command completions or overrides.
# compdef '_files -g "*.{pdf,ps}"' evince
# compdef '_files -g "*.{pdf,ps}"' zathura

# Show dots while waiting to complete. Useful for systems with slow net access,
# like those places where they use giant, slow NFS solutions. (Hint.)
# expand-or-complete-with-dots() {
#   echo -n "\e[31m......\e[0m"
#   zle expand-or-complete
#   zle redisplay
# }
# zle -N expand-or-complete-with-dots
# bindkey "^I" expand-or-complete-with-dots

# Function Usage: doc packagename
#                 doc pac<TAB>
# FIXME
function doc() { cd /usr/share/doc/$1 && ls }
compdef '_path_files -W /usr/share/doc -/' doc

