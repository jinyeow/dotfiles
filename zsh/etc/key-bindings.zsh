# See: 'http://zshwiki.org/home/zle/bindkeys'
# Section: 'reading $terminfo[]'

# create a zkbd compatible hash;
# to add other keys to this hash, see: man 5 terminfo
typeset -A key

key[Home]=${terminfo[khome]}
key[End]=${terminfo[kend]}
key[Insert]=${terminfo[kich1]}
key[Delete]=${terminfo[kdch1]}
key[Up]=${terminfo[kcuu1]}
key[Down]=${terminfo[kcud1]}
key[Left]=${terminfo[kcub1]}
key[Right]=${terminfo[kcuf1]}
key[PageUp]=${terminfo[kpp]}
key[PageDown]=${terminfo[knp]}

# setup key accordingly {{{
[[ -n "${key[Home]}"     ]] && bindkey "${key[Home]}"     beginning-of-line
[[ -n "${key[End]}"      ]] && bindkey "${key[End]}"      end-of-line
[[ -n "${key[Insert]}"   ]] && bindkey "${key[Insert]}"   overwrite-mode
[[ -n "${key[Delete]}"   ]] && bindkey "${key[Delete]}"   delete-char
[[ -n "${key[Up]}"       ]] && bindkey "${key[Up]}"       up-line-or-history
[[ -n "${key[Down]}"     ]] && bindkey "${key[Down]}"     down-line-or-history
[[ -n "${key[Left]}"     ]] && bindkey "${key[Left]}"     backward-char
[[ -n "${key[Right]}"    ]] && bindkey "${key[Right]}"    forward-char

# Additional keybindings to help navigate through the terminal
[[ -n "^B" ]] && bindkey "^B" backward-char
[[ -n "^F" ]] && bindkey "^F" forward-char
[[ -n "^A" ]] && bindkey "^A" beginning-of-line
[[ -n "^E" ]] && bindkey "^E" end-of-line

# }}}

# The following should fix keys when in vi-mode-normal {{{
# fix keys HOME
bindkey -M viins "^[[1" beginning-of-line
bindkey -M vicmd "^[[1" beginning-of-line

# fix keys END
bindkey -M viins "^[[4" end-of-line
bindkey -M vicmd "^[[4" end-of-line

# fix keys INSERT
bindkey -M viins "^[[2~" overwrite-mode
bindkey -M vicmd "^[[2~" overwrite-mode

# fix keys DELETE
bindkey -M viins "^[[3~" delete-char
bindkey -M vicmd "^[[3~" delete-char

# fix keys PGUP
bindkey -M viins "^[[5~" history-substring-search-up
bindkey -M vicmd "^[[5~" history-substring-search-up

# fix keys PGDOWN
bindkey -M viins "^[[6~" history-substring-search-down
bindkey -M vicmd "^[[6~" history-substring-search-down

# }}}

# keybinds for fzf-git.zsh {{{
# NOTE: Not using these keybindings.
#       Using a single menu fzf-git to run all of these from instead.
#       Under ALT+g. This is due to CTRL+g beind taken by fzf-marks now.
#       As of 01/11/17 00:32.

# FZF_GIT_PREFIX='\eg'

# # NOTE: unbind ctrl+g. Not using it before, and need to use it for fzf-git
# bindkey -r "$FZF_GIT_PREFIX"

# join-lines() {
#   local item
#   while read item; do
#     echo -n "${(q)item} "
#   done
# }

# bind-git-helper() {
#   local char
#   for c in $@; do
#     eval "fzf-g$c-widget() { local result=\$(fzf-g$c | join-lines); zle reset-prompt; LBUFFER+=\$result }"
#     eval "zle -N fzf-g$c-widget"
#     eval "bindkey \"$FZF_GIT_PREFIX$c\" fzf-g$c-widget"
#   done
# }
# bind-git-helper f b t r h
# unset -f bind-git-helper

# }}}

# Finally, make sure the terminal is in application mode, when zle is
# active. Only then are the values from $terminfo valid.
function zle-line-init () {
    echoti smkx
}
function zle-line-finish () {
    echoti rmkx
}
zle -N zle-line-init
zle -N zle-line-finish
# vim:foldmethod=marker:foldlevel=0
