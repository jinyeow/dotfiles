###############################################################################
#                             FUNCTIONS                                       #
#                         ------------------                                  #
###############################################################################

# echo helpers
function echo_task { echo -e '\033[1mTASK: '"$1"'\033[0m'; }
function echo_ok { echo -e '\033[33m'"$1"'\033[0m'; }
function echo_warn  { echo -e '\033[31mWARNING: '"$1"'\033[0m'; }

# wd
if [ -e "$HOME/.zplug/repos/mfaerevaag/wd/wd.sh" ]; then
  function wd () {
    . ~/.zplug/repos/mfaerevaag/wd/wd.sh
  }
fi

# Opens vim with files, or else opens recent session,
# else starts vim with Obsession
# function vim() {
#   if test $# -gt 0; then
#     env vim "$@"
#   elif test -f Session.vim; then
#     env vim -S
#   else
#     env vim -c Obsession
#   fi
# }

# See folder hierarchy in separate TMUX pane.
# Watches TMUX pane "1" and auto updates every second.
function livels () { while :; do clear; tmux display-message -p -F "#{pane_current_path}" -t1 | xargs tree -L 1 ; sleep 1; done }

# Make a directory then cd into it
function take () {
  if [ -z "$1" ]; then echo "USAGE: take DIRECTORY_NAME" && return 1; fi
  if ! [ -d "$1" ]; then
    mkdir -p $1
  fi
  cd $1
}

# Read markdown files like man pages
function mandoc () {
  if [ -z "$1" ]; then echo "USAGE: mandoc MARKDOWN_FILE" && return 1; fi
  pandoc -s -f markdown -t man "$*" | man -l -
}

# Google from the terminal
function google () {
  if [ -z "$1" ]; then echo "USAGE: google QUERY" && return 1; fi
  open "https://www.google.com/#q=$1"
}

# Extract the following formats by typing 'extract $1'
function extract () {
  if [ -z "$1" ]; then echo "USAGE: extract FILE_TO_EXTRACT" && return 1; fi
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)
        tar xvjf $1
        ;;
      *.tar.gz)
        tar xvzf $1
        ;;
      *.tar.xz)
        tar xvJf $1
        ;;
      *.tar.lzma)
        tar --lzma xvf $1
        ;;
      *.bz2)
        bunzip2 $1
        ;;
      *.rar)
        unrar $1
        ;;
      *.gz)
        gunzip $1
        ;;
      *.tar)
        tar xvf $1
        ;;
      *.tbz2)
        tar xvjf $1
        ;;
      *.tgz)
        tar xvzf $1
        ;;
      *.zip)
        unzip $1
        ;;
      *.Z)
        uncompress $1
        ;;
      *.7z)
        7z x $1
        ;;
      *)
        echo "'$1' cannot be extracted via extract()"
        ;;
    esac
  else
    echo "'$1' if not a valid file"
  fi
}

# Prints a very nice looking "path" instead of the long string that is default
function path () {
    echo $PATH | tr ":" "\n" | \
        awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\"); \
        sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\"); \
        sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\"); \
        sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\"); \
        sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\"); \
        print }"
}

# Generate useful things
function generate () {
  case $1 in
    proj|projection*)
      printf "Generating projection ~~\n\n"
      shift 1
      gen_projection.sh $@
      ;;
    -gi|gi|gitignore)
      printf "Generating gitignore ~~\n\n"
      shift 1
      gen_gitignore.sh $@
      ;;
    *)
      echo "Invalid option. Nothing to generate."
      ;;
  esac
}

# Provide 'up', so instead of 'cd ../../../' you simply type 'up 3'
function up () {
  if [[ "$#" -lt 1 ]]; then
    cd ..
  else
    cdstr=""
    for ((i=0; i<$1; i++)); do
      cdstr="../${cdstr}"
    done
    cd "${cdstr}" || exit
  fi
}

# Transfer files using transfer.sh website
function transfer () {
  if [ $# -eq 0 ]; then
    echo "ERROR: No file specified. Please provide a file to transfer."
    return 1
  fi

  # $tmpfile holds the transfer.sh URL of the transferred file.
  tmpfile=$( mktemp -t transferXXX )
  if tty -s; then
    basefile=$(basename "$1" | sed -e 's/[^a-zA-Z0-9._-]/-/g')
    curl --progress-bar --upload-file "$1" "https://transfer.sh/$basefile" >> $tmpfile
  else
    curl --progress-bar --upload-file "-" "https://transfer.sh/$1" >> $tmpfile
  fi

  cat $tmpfile
  rm -f $tmpfile
}

# uses streamlink (and thus youtube-dl) to stream crunchyroll anime in vlc
function crunchyroll () {
  if [ -z "$1" ]; then echo "USAGE: crunchyroll ANIME_URL" && return 1; fi
  streamlink --crunchyroll-username=jin-yeow@hotmail.com $1 best
}

# uses youtube-dl to download the entire anime series from crunchyroll
function crunchyroll-dl () {
  if [ -z "$1" ]; then echo "USAGE: crunchyroll-dl ANIME_URL" && return 1; fi
  youtube-dl --sub-lang enUS --write-sub --sub-format srt -o "%(title)s.%(ext)s" -u JyP8 "$1"
}

# tmux function.
# tm with no sessions open it will create a session called "new".
# tm irc it will attach to the irc session (if it exists), else it will create it.
# tm with one session open, it will attach to that session.
# tm with more than one session open it will let you select the session via fzf.
function tm () {
  local session
  newsession=${1:-new}
  session=$(tmux list-sessions -F "#{session_name}" | \
    fzf --query="$1" --select-1 --exit-0) &&
    tmux attach-session -t "$session" || tmux new-session -s $newsession
}

# Downloads video and sends desktop notification when done
function ytdl () {
  if [ -z "$1" ]; then echo "USAGE: ytdl YOUTUBE_URL" && return 1; fi
  # TODO: use the array of args and loop through them doing the same thing
  youtube-dl $1 && notify-send "YouTube-dl" "Finished downloading $(youtube-dl -e $1)."
}

# Reloads dunst config
function dunstreload () {
  killall dunst && notify-send "<b>Dunst Announcement</b>" "Reloaded dunst config successfully." \
    || notify-send "<b>Dunst Announcement</b>" "Dunst config reload unsuccesful."

  notify-send -u critical "Test message: critical test 1"
  notify-send -u normal "Test message: normal test 2"
  notify-send -u low "Test message: low test 3"
  notify-send -u critical "Test message: critical test 4"
  notify-send -u normal "Test message: normal test 5"
  notify-send -u low "Test message: low test 6"
  notify-send -u critical "Test message: critical test 7"
  notify-send -u normal "Test message: normal test 8"
  notify-send -u low "Test message: low test 9"
}

# Git clone into custom output directory based on the Github user then cd into it.
function gclcd () {
  if [ -z "$1" ]; then echo "USAGE: gclcd USER [REPO]" && return 1; fi
  user="$1"
  repo="dotfiles"
  if ! [ -z "$2" ]; then repo="$2"; fi

  git clone https://github.com/"$user"/"$repo" "$user" && cd "$user"
}

# print available colors and their numbers
function colours () {
  for i in {0..255}; do
    printf "\x1b[38;5;${i}m colour${i}"
    if (( $i % 5 == 0 )); then
      printf "\n"
    else
      printf "\t"
    fi
  done
}

function hist () {
  history | awk '{a[$2]++}END{for(i in a){print a[i] " " i}}' | sort -rn | head
}

# gets .gitignore template from gitignore.io
function mkgitignore () {
  if [ $# -lt 1 ]; then
    echo "USAGE: $0 ruby,python,etc,..."
    echo "Use '$0 list' to see a list of all of the currently supported gitignore.io templates."
  else
    if which curl >/dev/null ; then
      curl --location --silent https://www.gitignore.io/api/$@
    elif which wget >/dev/null ; then
      wget --quiet -O- https://www.gitignore.io.api/$@
    else
      echo "please install curl or wget to run this function."
      return 1
    fi
  fi
}

function avgdl () {
  # Usage: avgdl <url> <last seg #> <output file>
  url=$(echo "$1" | sed 's/seg-.*$/seg-/')
  suffix="-v1-a1.ts"
  for i in $(seq 1 $2)
  do
    wget -O - "$url$i$suffix" >> "$3"
  done
}

# The fancy-ctrl-z function is this simple so I added it here.
# I can now do without the "plugin" in my zshrc.
function fancy-ctrl-z () {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER="fg"
    zle accept-line
  else
    zle push-input
    zle clear-screen
  fi
}
zle -N fancy-ctrl-z
bindkey '^Z' fancy-ctrl-z
