# National Rugby League
{ config, pkgs, lib, ... }:

let
  email = "jpuah@nrl.com.au";
in
{
  # Environment Variables
  # home.sessionVariables = {
  # };

  # Packages to install
  # home.packages = with pkgs; [
  #   # pkgs is the set of all packages in the default home.nix implementation
  # ];
  
  # Raw configuration files
  # home.file.".tmux.conf".source = ./tmux.conf;
  # home.file.".vimrc".source = ./vimrc;
  # home.file.".config/nvim/init.vim".source = ./vimrc;

  # Git config using Home Manager modules
  programs.git = {
    userEmail = lib.mkForce "${email}";
  };
}
