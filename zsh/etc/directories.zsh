###############################################################################
#                            DIRECTORIES                                      #
#                         ------------------                                  #
###############################################################################

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

# alias -- -='cd -'
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

alias md='mkdir -pv'
alias rd=rmdir
alias d='dirs -v | head -10'

# List directory contents
if which exa >/dev/null ; then
  alias ls='exa --classify'
  alias lsa='exa --classify --all'
  alias l='exa --long --classify --all --git'
  alias ll='exa --long --classify --git'
  alias la='exa --long --classify --all --header --modified --accessed --git --extended'
else
  alias lsa='ls -lah --color=always'
  alias l='ls -lah --color=always'
  alias ll='ls -lh --color=always'
  alias la='ls -lAh --color=always'
fi

# Push and pop directories on directory stack
alias pu='pushd'
alias po='popd'
