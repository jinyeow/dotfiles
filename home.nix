{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "jinyeow";
  home.homeDirectory = "/home/jinyeow";
  
  # Environment Variables
  home.sessionVariables = {
    EDITOR = "vim";
  };

  # Packages to install
  home.packages = [
    # pkgs is the set of all packages in the default home.nix implementation
    pkgs.bash
    pkgs.exa
    pkgs.fzf
    pkgs.go
    pkgs.jq
    pkgs.neovim
    pkgs.openssh
    pkgs.readline
    pkgs.ripgrep
    pkgs.tig
    pkgs.tmux
    pkgs.vim
    pkgs.yq
    pkgs.zoxide
  ];
  
  # Raw configuration files
  home.file.".bashrc".source = ./bashrc;
  home.file.".bash_aliases".source = ./bash/bash_aliases;
  home.file.".bash_profile".source = ./bash/bash_profile;
  home.file.".inputrc".source = ./inputrc;
  home.file.".profile".source = ./profile;
  home.file.".tmux.conf".source = ./tmux.conf;
  home.file.".vimrc".source = ./vimrc;

  # home.file.".gitconfig".source = ./gitconfig;

  # Git config using Home Manager modules
  programs.git = {
    enable = true;
    userName = "jinyeow";
    userEmail = "justin@puah.dev";
    aliases = {
      a = "add";
      aliases = "config --get-regexp alias";
      amend = "commit --amend";
      branches = "branch -a";
      c = "commit";
      co = "checkout";
      ctags = "!.git/hooks/ctags";
      delete = "rm -r --cached";
      discard = "checkout --";
      filediff = "diff --name-status";
      graph = "log --graph -50 --branches --remotes --tags  --format=format:'%Cgreen%h %Creset• <(75,trunc)%s (%cN, %cr) %Cred%d' --date-order";
      ignore = "'!gi() { curl -L -s https://www.gitignore.io/api/$@ ;}; gi'";
      last = "log -1 HEAD --format=format:\"%Cred%H\"";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      remotes = "remote -v";
      s = "status";
      stashes = "stash list";
      tags = "tag";
      uncommit = "reset --mixed HEAD~";
      unstage = "reset -q HEAD --";
      unmerged = "diff --name-only --diff-filter=U";
      test = "status";
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
