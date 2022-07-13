[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx

emulate sh -c 'source /etc/profile'
emulate sh -c "source $HOME/.profile"

# XDG_CONFIG_HOME="$HOME/.config"
# PANEL_WM_NAME=bspwm_panel
# PANEL_FIFO="/tmp/panel-fifo"
# PANEL_HEIGHT=35

# export PANEL_FIFO PANEL_HEIGHT PANEL_WM_NAME XDG_CONFIG_HOME

# Golang
export GOPATH=~/go
if [ ! -d ~/go/bin ]; then
  mkdir -p ~/go/{bin,src}
fi
