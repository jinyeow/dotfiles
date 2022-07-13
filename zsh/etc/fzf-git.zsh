# GIT heart FZF
# -------------
# NOTE: changed all function names from 'g*' to 'fzf-g*' to avoid alias conflicts.
# e.g. gf -> fzf-gf

function is_in_git_repo() {
  git rev-parse HEAD > /dev/null 2>&1
}

function fzf-gf() {
  is_in_git_repo || return
  file=$(git -c color.status=always status --short --untracked-files=all |
  fzf-tmux -m --ansi --nth 2..,.. \
    --preview '(git diff --color=always -- {-1} | sed 1,4d; cat {-1}) | head -500' |
  cut -c4- | sed 's/.* -> //')
  ! [ -z "$file" ] && $EDITOR "$file" && return 1 || return 0
}

function fzf-gb() {
  is_in_git_repo || return
  git branch -a --color=always | grep -v '/HEAD\s' | sort |
  fzf-tmux --ansi --multi --tac --preview-window right:70% \
    --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1) | head -'$LINES |
  sed 's/^..//' | cut -d' ' -f1 |
  sed 's#^remotes/##'
}

function fzf-gt() {
  is_in_git_repo || return
  git tag --sort -version:refname |
  fzf-tmux --multi --preview-window right:70% \
    --preview 'git show --color=always {} | head -'$LINES
}

function fzf-gh() {
  is_in_git_repo || return
  git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" --graph --color=always |
  fzf-tmux --ansi --no-sort --reverse --multi --bind 'ctrl-s:toggle-sort' \
    --header 'Press CTRL-S to toggle sort' \
    --preview 'grep -o "[a-f0-9]\{7,\}" <<< {} | xargs git show --color=always | head -'$LINES |
  grep -o "[a-f0-9]\{7,\}"
}

function fzf-gr() {
  is_in_git_repo || return
  git remote -v | awk '{print $1 "\t" $2}' | uniq |
  fzf-tmux --tac \
    --preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" {1} | head -200' |
  cut -d$'\t' -f1
}

if [[ -z "${FZF_GIT_COMMAND}" ]] ; then

    FZF_VERSION=$(fzf --version | awk -F. '{ print $1 * 1e6 + $2 * 1e3 + $3 }')
    MINIMUM_VERSION=16001

    if [[ $FZF_VERSION -gt $MINIMUM_VERSION ]]; then
        FZF_GIT_COMMAND="fzf --height 40% --reverse"
    elif [[ ${FZF_TMUX:-1} -eq 1 ]]; then
        FZF_GIT_COMMAND="fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}"
    else
        FZF_GIT_COMMAND="fzf"
    fi

    export FZF_GIT_COMMAND
fi

function fzf-git() {
  fzf-git-menu

  # zle && zle reset-prompt
  zle redisplay
}

function fzf-git-menu() {
  is_in_git_repo || return

  local list
  list=$( \
    echo 'Files' && \
    echo 'Branch' && \
    echo 'Tags' && \
    echo 'History' && \
    echo 'Remote' && \
  )

  rm -f /tmp/fzfGitTypes > /dev/null
  echo $list > /tmp/fzfGitTypes

  # type=$(cat /tmp/fzfGitTypes | fzf-tmux --query="" --reverse --select-1 --exit-0) \
  type=$(cat /tmp/fzfGitTypes | $(echo ${FZF_GIT_COMMAND})) \
    || return 1
  case `echo $type` in
    'Files') fzf-gf && fzf-git-menu;;
    'Branch') fzf-gb && fzf-git-menu;;
    'Tags') fzf-gt; fzf-git-menu;;
    'History') fzf-gh; fzf-git-menu;;
    'Remote') fzf-gr && fzf-git-menu;;
  esac
  rm -f /tmp/fzfGitTypes > /dev/null
}
zle     -N    fzf-git
bindkey '\eg' fzf-git
