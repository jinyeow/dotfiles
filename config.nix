{
  packageOverrides = pkgs: with pkgs; {
    myPackages = pkgs.buildEnv {
      name = "my-packages";
      paths = [
        certbot
        ctags
        dig
        docker
        docker-compose
        ffmpeg
        go
        jq
        neovim
        nginx
        pwgen
        ranger
        silver-searcher
        tig
        tree
        xsel
        yq
        yt-dlp
      ];
      extraOutputsToInstall = [ "man" "doc" ];
    };
  };
}
