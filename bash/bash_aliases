alias up='cd ..'
alias vim='nvim'

if which terraform.exe >/dev/null; then
  alias terraform='terraform.exe'
fi

function git_add_commit_push() {
  git add .
  git commit -m "$1"
  git push
}

if which git >/dev/null; then
  alias gst='git status'
  alias ga='git add'
  alias gc='git commit'
  alias gp='git push'
  alias gacp='git_add_commit_push'
  alias gco='git checkout'
fi
