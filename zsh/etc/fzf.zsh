# ================================================
# PERSONAL FZF EXTRAS + FUNCTIONS
# ================================================

# ALT-I - Paste the selected entry from locate output into the command line
fzf-locate-widget() {
  local selected
  if selected=$(locate / | fzf -q "$LBUFFER"); then
    LBUFFER=$selected
  fi
  zle redisplay
}
zle     -N    fzf-locate-widget
bindkey '\ei' fzf-locate-widget

# mpc+fzf to change songs
fzf-mpc() {
  # Ensures mpd is 'turned on'
  if [ "$(pgrep mpd)" == "" ]; then mpd; fi
  fm # See below fm() and other fm*() functions
  zle redisplay
}
zle     -N    fzf-mpc
bindkey '\em' fzf-mpc

# MPD FTW - taken from https://github.com/piotryordanov/fzf-mpd/
# This function will invoke a menu that lets you select
# What kind of search you wish to do.
fm() {
  local list
  list=$(echo 'Title' && \
    echo 'Genre' && \
    echo 'Artist' && \
    echo 'Albums' && \
    echo 'Current Playlist' && \
    echo 'Clear Playlist')
  rm -f /tmp/fileTypes
  echo $list > /tmp/fileTypes

  type=$(cat /tmp/fileTypes | \
    fzf-tmux --query="" --reverse --select-1 --exit-0 ) || return 1
  case `echo $type` in
    'Title') fms ${@};;
    'Genre') fmg ${@};;
    'Artist') fmaa ${@};;
    'Albums') fma ${@};;
    'Current Playlist') fmp ${@};;
    'Clear Playlist') fmc;;
  esac
  rm -f /tmp/fileTypes
}

# Search Playlist
fmp() {
  local song_position
  song_position=$(echo -n "\n$(mpc -f "%position%) %artist% - %title%" playlist)" | \
    fzf-tmux --query="$1" --reverse | \
    sed -n 's/^\([0-9]\+\)).*/\1/p') || return 1
  [ -n "$song_position" ] && mpc -q play $song_position
  fm
}

# Search for any Song
fms() {
  local song
  song=$(mpc ${@} list title | \
    fzf-tmux --query="$1" --reverse --select-1 --exit-0) || return 1
  # mpc ${@} clear;
  [ -n "$song" ] && (mpc ${@} search title $song | \
    mpc ${@} insert; mpc ${@} play; mpc ${@} next)
  echo $FMOPTS
  fm
}

# Search Genres
fmg() {
  local genre
  genre=$(mpc ${@} list genre | \
    fzf-tmux --query="$1" --reverse --select-1 --exit-0) || return 1
  mpc ${@} clear;
  [ -n "$genre" ] && mpc ${@} search genre $genre | mpc ${@} insert; mpc ${@} play
  fm
}

# Search Artists
fmaa() {
  local artist
  artist=$(mpc ${@} list artist | \
    fzf-tmux --query="$1" --reverse --select-1 --exit-0) || return 1
  mpc ${@} clear;
  [ -n "$artist" ] && mpc ${@} search artist $artist | mpc ${@} insert; mpc ${@} play
  fm
}

# Search Albums
fma() {
  local albums
  album=$(mpc ${@} list album | \
    fzf-tmux --query="$1" --reverse --select-1 --exit-0) || return 1
  mpc ${@} clear;
  [ -n "$album" ] && mpc ${@} search album $album | mpc ${@} insert; mpc ${@} play
  fm
}

# Clear the playlist and invoke the fm()
fmc() {
  mpc ${@} clear
  fm
}

# fbr - checkout git branch (local only)
fzf-br() {
  local branches branch
  branches=$(git branch -vv) &&
  branch=$(echo "$branches" | fzf +m) &&
  git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
  zle redisplay
}
zle     -N    fzf-br
bindkey '\eb' fzf-br

# fbr - checkout git branch (including remote branches)
# fzf-br() {
#   local branches branch
#   branches=$(git branch --all | grep -v HEAD) &&
#   branch=$(echo "$branches" |
#            fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
#   git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
# }

# fkill - kill process
fzf-kill() {
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

  if [ "x$pid" != "x" ]
  then
    kill -${1:-9} $pid
  fi

  zle redisplay
}

# fda - including hidden directories
fzf-da() {
  local dir
  dir=$(find ${1:-.} -type d 2> /dev/null | fzf +m) && cd "$dir"
  zle reset-prompt
}
zle     -N    fzf-da
bindkey '\ez' fzf-da

# fdr - cd to selected parent directory
# fzf-dr() {
#   local declare dirs=()
#   get_parent_dirs() {
#     if [[ -d "${1}" ]]; then dirs+=("$1"); else return; fi
#     if [[ "${1}" == '/' ]]; then
#       for _dir in "${dirs[@]}"; do echo $_dir; done
#     else
#       get_parent_dirs $(dirname "$1")
#     fi
#   }
#   local DIR=$(get_parent_dirs $(realpath "${1:-$(pwd)}") | fzf-tmux --tac)
#   cd "$DIR"
#   zle redisplay
# }
# zle     -N    fzf-dr
# bindkey '\en' fzf-dr

# Use mkgitignore(), gitignore.io, and fzf to generate a .gitignore file
# Cache the output and update every 2 weeks.
fzf-gitignore() {
  cache_dir="$HOME/.cache/gitignore_io"
  if ! [ -d "$cache_dir" ]; then
    mkdir -p "$cache_dir" >/dev/null
  fi

  list=''
  curtime=$(date +'%s')
  if [ -f "$cache_dir/list" ]; then
    oldtime=$(cat "$cache_dir/list.mtime")
    if [ $((curtime - oldtime)) -gt 1209600 ]; then
      list=$(mkgitignore list | ruby -n -e 'puts $_.strip.split(/,/).join("\n")')
      echo "$list" > "$cache_dir/list"
      stat -c '%Y' "$cache_dir/list" > "$cache_dir/list.mtime"
    else
      list=$(cat "$cache_dir/list")
    fi
  else
    list=$(mkgitignore list | ruby -n -e 'puts $_.strip.split(/,/).join("\n")')
    echo "$list" > "$cache_dir/list"
    stat -c '%Y' "$cache_dir/list" > "$cache_dir/list.mtime"
  fi

  # TODO: give a better fzf command so it doesn't take up the whole page.
  type=$(echo "$list" | fzf)

  if [ -f "$cache_dir/$type" ]; then
    oldtime=$(cat "$cache_dir/$type.mtime")
    if [ $((curtime - oldtime)) -gt 1209600 ]; then
      mkgitignore "$type" > "$cache_dir/$type"
      cat "$cache_dir/$type"
      stat -c '%Y' "$cache_dir/$type" > "$cache_dir/$type.mtime"
    else
      cat "$cache_dir/$type"
    fi
  else
    mkgitignore "$type" > "$cache_dir/$type"
    cat "$cache_dir/$type"
    stat -c '%Y' "$cache_dir/$type" > "$cache_dir/$type.mtime"
  fi
}
