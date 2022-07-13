# Solutions to Various Issues
-----------------------------

* Laptop Randomly shutsdown?
    - dmesg
    - journalctl

* Error: File X corrupted...PGP error, etc.
    - Fix: Change mirror in /etc/pacman.d/mirrorlist and then do a pacman -Syy

* Firefox freaks out when in fullscreen mode or when panel is hidden:
    - Solution:
      Remove 'xf86-video-intel' package. Not sure why but when this is removed,
      the problem goes away.

* Some places to check when disk gets full:
    - /var/log/journal/*
      * NB: to manually clean out /var/log/journal use:
        - `journalctl --vacuum-time=`, or
        - `journalctl --vacuum-size=`
    - /var/cache/pacman/pkg/*
      * NB: the command `paccache -r` or `paccache -ruk0` may help

* Installing Elm through `npm install -g elm`, elm-repl doesn't work on Arch.
  To get it working you need to do:
    `sudo ln -s libncurses++w.so.6.0 libtinfo.so.5`

* Setting POSTGRESQL for the regular user:
  - From terminal:
    $ sudo -u postgres -i
    $ psql
    psql> CREATE ROLE username superuser login createdb username username;
      e.g. CREATE ROLE j1n superuser login createdb j1n j1n
    NOTE: if the 'createdb' part doesn't fire off try:
    psql> CREATE DATABASE username OWNER username;
      (can also do from the terminal prompt '$ createdb `whoami`')

* To fix PURE zsh theme prompt to get git prompt that changes from green to red
  when there are untracked files:
    - add the following lines below 'local git_color=...':
      """
      local git_color=green
      [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1 && \
        [[ ! -z $(git status --porcelain --ignore-submodules -unormal) ]] && \
        git_color=red
      """
      OR (see zsh/custom/modified/pure.zsh)
      """
      [ ${prompt_pure_git_dirty} ] && git_color=red
      """

* <C-H> Mapping doesn't move between Neovim to Tmux:
  Solution:
    https://github.com/neovim/neovim/wiki/Troubleshooting#my-ctrl-h-mapping-doesnt-work

* To install hp printer:
  - pacman -S hplip
  - $ hplip -i <ip-address-of-wireless-printer>

* <C-r> (fzf-history-widget) may not work:
  Issue:
    <C-r> mapping may stop working for all applications (e.g. fzf-history-widget in terminal; redo in neovim)
  Reason:
    Trello uses <C-r> for refresh. For some reason this has a bad interaction with the other programs stopping
    them from using <C-r> for their mappings
  Solution:
    Close Trello when not in use to be able to use <C-r>. Obviously not the best, but at least it (somewhat)
    solves the issue.

* <C-z> and/or fancy-ctrl-z() does not work:
  Issue:
    <C-z> doesn't work and results in freezing of neovim or doesn't do anything at all in vim; tested in
    (Neo)vim, man
  Reason:
    Unknown as of 04/01/18 16:11
  Solution:
    I'm still looking for one

* dmenu_extended/xdg-open self created epubs/mp4/other filetypes via FF/the browser:
  Issue:
    xdg-open doesn't correctly parse the mimetype of self created files (e.g. files created via webnovel-dl or
    my avgdl() function) and opens them first with Firefox which then opens the correct application
  Reason:
    Not sure, maybe I didn't add in some bits/header info/something to specify the mimetype properly
  Solution:
    I installed 'perl-file-mimeinfo' and did a 'sudo update-mime-database /usr/share/mime' and now everything
    works like it should.
    Not sure which fixed it or whether it was both. Still doing both doesn't hurt.
