# Core
{ config, pkgs, lib, ... }:

let
  name = "Justin Puah";
  username = builtins.getEnv "USER";
  email = "justin@puah.me";
  devEmail = "justin@puah.dev";
  host = ((lib.removeSuffix "\n") (builtins.readFile "/etc/hostname"));
in
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Environment Variables
  home.sessionVariables = {
    dotfiles = "$HOME/dotfiles";
    LANG = "en_US.UTF-8";
    MANPAGER = "nvim +Man! -";
  };

  # Packages to install
  home.packages = with pkgs; [
    # pkgs is the set of all packages in the default home.nix implementation
    bashInteractive
    coreutils
    direnv
    exa
    fd
    fzf
    git-extras
    htop
    ncurses
    openssh
    perl
    rclone
    ripgrep
    tmux
    unzip
    vim
    wget
    zoxide
  ];
  
  # Raw configuration files
  home.file.".curlrc".source = ./curlrc;
  home.file.".config/direnv/direnv.toml".source = ./config/direnv/direnv.toml;
  home.file.".gitignore".source = ./gitignore;
  home.file.".inputrc".source = ./inputrc;
  home.file.".ripgreprc".source = ./ripgreprc;
  home.file.".tigrc".source = ./tigrc;
  home.file.".tigrc.vim".source = ./tigrc.vim;
  home.file.".tmux.conf".source = ./tmux.conf;
  home.file.".vimrc".source = ./vimrc;
  home.file.".config/nvim/init.vim".source = ./vimrc;
  home.file.".wgetrc".source = ./wgetrc;

  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
      initExtra = ''
        ${builtins.readFile ./bash/sensible.bash}
        ${builtins.readFile ./bashrc}
        ${builtins.readFile ./bash/bash_aliases}
      '';
      profileExtra = ''
        ${builtins.readFile ./profile}

        # To let home-manager add bash completions
        test -d "$HOME/.nix-profile" && export XDG_DATA_DIRS=$HOME/.nix-profile/share:$XDG_DATA_DIRS || true
      '';
    };

    bat = {
      enable = true;
    };
  };

  # Git config using Home Manager modules
  programs.git = {
    enable = true;
    userName = "${name}";
    userEmail = lib.mkDefault "${devEmail}";
    aliases = {
      a = "add";
      aliases = "config --get-regexp alias";
      amend = "commit --amend";
      branches = "branch -a";
      c = "commit";
      co = "checkout";
      cm = "commit -m";
      ctags = "!.git/hooks/ctags";
      delete = "rm -r --cached";
      delete-merged-branches = "!git branch --merged | grep -v \\* | grep -v deploy/* | xargs -I % git branch -d %";
      discard = "checkout --";
      fa = "fetch --all";
      filediff = "diff --name-status";
      graph = "log --graph -50 --branches --remotes --tags  --format=format:'%Cgreen%h %Creset• <(75,trunc)%s (%cN, %cr) %Cred%d' --date-order";
      ignore = "'!gi() { curl -L -s https://www.gitignore.io/api/$@ ;}; gi'";
      last = "log -1 HEAD --format=format:\"%Cred%H\"";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      remotes = "remote -v";
      s = "status";
      st = "status";
      stashes = "stash list";
      tags = "tag";
      uncommit = "reset --mixed HEAD~";
      undo = "reset --hard HEAD~";
      unstage = "reset -q HEAD --";
      unmerged = "diff --name-only --diff-filter=U";
    };
    extraConfig = {
      core = {
        excludesfile = "~/.gitignore";
        preloadindex = "true";
        untrackedCache = "true";
      };
      color = {
        ui = "auto";
      };
      commit = {
        gpgsign = "false";
      };
      diff = {
        tool = "vimdiff";
        algorithm = "histogram";
      };
      gpg = {
        program = "gpg";
      };
      help = {
        autocorrect = "1";
      };
      push = {
        default = "simple";
      };
      tag = {
        gpgsign = "false";
      };
    };
    ignores = [
      "**/&undodir"
      "**/*.swp"
      "*.pyc"
      "**/*.tags"
      "**/tags"
      "**Session.vim"
      "**/_build"
    ];
  };

  # imports = if username == "jpuah"
  imports = if host == "NRL-5CG1380ZN7"
  then [ ./nix/nrl.nix ]
  else [ ./nix/null.nix ];

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
