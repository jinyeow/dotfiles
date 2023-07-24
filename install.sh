#!/bin/bash

# simple install script for the vscode devcontainers to install dotfiles

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}

## == BASHRC ==
cp -f bashrc ~/.bashrc
cp -f bash/bash_aliases ~/.bash_aliases

## == DIRENV ==
cp -r config/direnv $XDG_CONFIG_HOME/

## == GIT ==
cp gitconfig ~/.gitconfig
cp gitignore ~/.gitignore
cp gitmessage ~/.gitmessage
cp -r git-templates/hooks ~/.git_templates

## == NVIM ==
cp -r nvim $XDG_CONFIG_HOME/

## == TMUX ==
cp tmux.conf ~/.tmux.conf

## == OTHERS ==
cp curlrc ~/.curlrc
cp ripgreprc ~/.ripgreprc
cp tigrc ~/.tigrc
cp tigrc.vim ~/.tigrc.vim
