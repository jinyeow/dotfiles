###############################################################################
#                               ALIAS                                         #
#                         ------------------                                  #
###############################################################################

## reddit_summon aliases
alias summonerschool='reddit_summon --sub summonerschool'
alias noveltranslations='reddit_summon --sub noveltranslations'
alias worldnews='reddit_summon --sub worldnews'
alias multihub='reddit_summon --sub multihub'
alias rulix='reddit_summon --multi rulix -u Chaoist'

## RC aliases
alias vimrc="vim ~/.vimrc"
alias nvimrc="nvim ~/.config/nvim/init.vim"
alias bspwmrc="$EDITOR ~/.config/bspwm/bspwmrc"
alias sxhkdrc="$EDITOR ~/.config/sxhkd/sxhkdrc"
alias zshrc="$EDITOR ~/.zshrc"

## Package aliases
alias packages="comm -23 <(pacman -Qeq | sort) <(pacman -Qgq base base-devel | sort)"
# alias pipupdate="sudo pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs sudo pip install -U"
# alias pipupgrade="sudo pip install --upgrade pip"
# alias pip2upgrade="sudo pip2 install --upgrade pip"

## Script aliases
alias lockscreen="locker.sh"
alias update="update_packages.sh"
alias tdl="todo list"

## Program aliases
alias eclimd="cd ~/workspace; $ECLIPSE_HOME/eclimd"

# Get 256 colors
# alias tmux='tmux -2'

## Git aliases
alias gcd='cd $(git rev-parse --show-toplevel 2&> /dev/null || echo ".")'
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gcl='git clone --recursive'
alias gcm='git commit -vm'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gcmsg='git commit -am'
alias gpcd='gp && cd'

## TMUX aliases
alias ta='tmux attach -t'
alias tad='tmux attach -d -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'
alias tksv='tmux kill-server'
alias tkss='tmux kill-session -t'

## Rails aliases
if [ "$(rails -v)" =~ '5(.[0-9]+)+' ]; then
  # Rails aliases
  alias rc='rails console'
  alias rcs='rails console --sandbox'
  alias rd='rails destroy'
  alias rdb='rails dbconsole'
  # alias rg='rails generate' # this conflicts with 'rg' (ripgrep)
  alias rgm='rails generate migration'
  alias rp='rails plugin'
  alias ru='rails runner'
  alias rs='rails server'
  alias rsd='rails server --debugger'
  alias rsp='rails server --port'

  # Rake aliases
  alias rdm='rails db:migrate'
  alias rdms='rails db:migrate:status'
  alias rdr='rails db:rollback'
  alias rdc='rails db:create'
  alias rds='rails db:seed'
  alias rdd='rails db:drop'
  alias rdrs='rails db:reset'
  alias rdtc='rails db:test:clone'
  alias rdtp='rails db:test:prepare'
  alias rdmtc='rails db:migrate db:test:clone'
  alias rdsl='rails db:schema:load'

  alias rlc='rails log:clear'
  alias rn='rails notes'

  alias rr='rails routes'
  alias rrg='rails routes | grep'

  alias rt='rails test'
  alias rti='rails test:integration'
  alias rtm='rails test:models'

  alias rmd='rails middleware'
  alias rsts='rails stats'
fi

## All Other aliases
alias _='sudo'
alias chmod='chmod -v'
alias chown='chmod -v'
alias clr='clear;tput cup $LINES 0'
alias cp='cp -iv'
alias df='df -h'
alias dir='dir --color=auto'
alias du='du -cksh'
alias dus='du -ms * | sort -n'
alias egrep="egrep --color=auto"
alias external_ip='wget http://ipinfo.io/ip -qO -'
alias ffs='sudo $(fc -ln -1)' # Repeat the last command using sudo
alias filesize="stat -f \"%z bytes\"" # File size
alias fuck='sudo $(fc -ln -1)'
alias fgrep='fgrep --color=auto'
alias help="man"
alias info='info --vi-keys'
# alias internal_ip='ip -4 -o a | ag "wlp3s0" | ag --nocolor -o "(\d{1,3}\.){3}\d{1,3}/\d{1,2}"'
alias internal_ip="nmcli dev show wlp3s0 | grep IP4.ADDR | ruby -ne 'puts \$_.split(/\s+/).last.strip'"
alias j='jobs'
# alias l='ls -lFh'     #size,show type,human readable
# alias la='ls -lAFh'   #long list,show almost all,show type,human readable
# alias lr='ls -tRFh'   #sorted by date,recursive,show type,human readable
# alias lt='ls -ltFh'   #long list,sorted by date,show type,human readable
# alias ll='ls -l'      #long list
# alias ldot='ls -ld .*'
# alias lS='ls -1FSsh'
# alias lart='ls -1Fcart'
# alias lrt='ls -1Fcrt'
alias ls='ls --color=auto'
alias mkdir='nocorrect mkdir -pv'
alias mv='mv -iv'
alias pcr='paccache -r && paccache -ruk0'
alias please='sudo'
alias rename='rename -v'
alias ripgrep='rg'
alias rm='rm -iv'
alias rsync='rsync -hv --progress'
alias sw='echo Press CTRL-D to stop;time cat' # Shitty stopwatch
alias tree="tree -A -I 'CVS|*~|.git' -h"
alias vdir='vdir --color=auto'

# Vagrant
alias vupssh='vagrant up && vagrant ssh'
alias vup='vagrant up'
alias vssh='vagrant ssh'
alias vhalt='vagrant halt'

alias a3="neofetch"
alias howtotwitchchat="mandoc ~/dotfiles/misc/twitch_chat_irc_howto.md"
alias ri="ri -f ansi"
alias rot13='tr a-zA-Z n-za-mN-ZA-M' # ROT13 de/encode text
alias rtfm="man"
alias weather="curl http://wttr.in"

alias zzz="sudo shutdown -P +60"
alias bye="sudo shutdown -P now"

# Updates the AUR packages that are sourced from git repos.
alias aur_git_update="trizen -Sua --devel --noedit --needed"
alias aur_git_update_noconfirm="trizen -Sua --devel --noedit --needed --noconfirm"

# for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
#     alias "$method"="http $method"
# done

if which nvim >/dev/null && which fv >/dev/null ; then
  alias fv="fv -c nvim"
fi

