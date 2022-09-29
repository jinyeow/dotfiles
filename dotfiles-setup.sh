#!/bin/bash

# List of dotfiles/modules:
# - Bash
# - Git
# - Neovim
# - Tmux
# - Vim
# - Zsh

# Location of dotfiles to link to
 : ${DOT_REPO:=$PWD} # change this to ~/dotfiles as default repo

# FLAGS
DEBUG=0

# ARRAYS
modules=()
ln_args=(
  -s
)

# Parse arguments
while getopts ":fd:D" opt; do
  case $opt in
    f)
      ln_args+=(-f)
      ;;
    d)
      if [[ $OPTARG == 'all' ]]; then
        modules=(
          bash
          git
          nvim
          tmux
          vim
          #zsh
        )
      else
        modules+=($OPTARG)
      fi
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 2
      ;;
    D)
      echo "DEBUG option set."
      DEBUG=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ $DEBUG -eq 1 ]; then
  echo "ln ${ln_args[@]}"
fi

echo "Modules: ${modules[@]}"

# Link dotfiles
for module in "${modules[@]}"
do
  case $module in
    bash)
      ln "${ln_args[@]}" "$DOT_REPO/bashrc" ${DOT_BASHRC:=~/.bashrc}
      echo "Linked $DOT_REPO/bashrc to $DOT_BASHRC"
      ln "${ln_args[@]}" "$DOT_REPO/bash_aliases" ${DOT_BASHALIAS:=~/.bash_aliases}
      echo "Linked $DOT_REPO/bash_aliases to $DOT_BASHALIAS"
      ln "${ln_args[@]}" "$DOT_REPO/inputrc" ${DOT_INPUTRC:=~/.inputrc}
      echo "Linked $DOT_REPO/inputrc to $DOT_INPUTRC"
      ;;
    git)
      ln "${ln_args[@]}" "$DOT_REPO/gitconfig" ${DOT_GITCONFIG:=~/.gitconfig}
      echo "Linked $DOT_REPO/gitconfig to $DOT_GITCONFIG"
      ;;
    nvim|neovim)
      ln "${ln_args[@]}" "$DOT_REPO/config/nvim" ${DOT_NVIMDIR:=~/.config/nvim}
      echo "Linked $DOT_REPO/config/nvim to $DOT_NVIMDIR"
      ;;
    tmux)
      ln "${ln_args[@]}" "$DOT_REPO/tmux.conf" ${DOT_TMUXCONF:=~/.tmux.conf}
      echo "Linked $DOT_REPO/tmux.conf to $DOT_TMUXCONF"
      ;;
    vim)
      ln "${ln_args[@]}" "$DOT_REPO/vimrc" ${DOT_VIMRC:=~/.vimrc}
      echo "Linked $DOT_VIMRC"
      ln "${ln_args[@]}" "$DOT_REPO/vim" ${DOT_VIMDIR:=~/.vim}
      echo "Linked $DOT_VIMDIR"
      ;;
    zsh)
      ln "${ln_args[@]}" "$DOT_REPO/zshrc" ${DOT_ZSHRC:=~/.zshrc}
      echo "Linked $DOT_REPO/zshrc to $DOT_ZSHRC"
      # TODO: zshenv, zprofile
      ;;
    *)
      echo "Invalid module: $module" >&2
      exit 3
      ;;
  esac
done
