###############################################################################
#                                ENV                                          #
#                         ------------------                                  #
###############################################################################

# User specific XDG directories
# export XDG_DATA_HOME=$HOME/.local/share
# export XDG_CONFIG_HOME=$HOME/.config

export BROWSER='firefox'

if [ -x $(which nvim) ]; then
  export EDITOR='nvim'
  export DIFF='nvim -d'
  export VISUAL='nvim'
elif [ -x $(which vim) ]; then
  export EDITOR='vim'
  export DIFF='vimdiff'
  export VISUAL='vim'
else
  export EDITOR='vi'
fi

# Reduce lag in Vi-mode
export KEYTIMEOUT=1

# For Eclim
export ECLIPSE_HOME="/usr/lib/eclipse"

## pager
export PAGER="less"
export LESS='-g -i -M -R -w -z-4'

export TMPDIR='/tmp'

# postgres
export PGROOT='/var/lib/postgres'
export PGDATA='/var/lib/postgres/data'
