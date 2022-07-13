homelink: ## Link config files that belong in $HOME
	ln -vsf ${PWD}/agiginore ${HOME}/.agiginore
	ln -vsf ${PWD}/asoundrc ${HOME}/.asoundrc
	ln -vsf ${PWD}/ctags ${HOME}/.ctags
	ln -vsf ${PWD}/inputrc ${HOME}/.inputrc
	ln -vsf ${PWD}/mpd ${HOME}/.mpd
	ln -vsf ${PWD}/ncmpcpp ${HOME}/.ncmpcpp
	touch ${HOME}/.notags
	ln -vsf ${PWD}/profile ${HOME}/.profile
	ln -vsf ${PWD}/psqlrc ${HOME}/.psqlrc
	ln -vsf ${PWD}/scripts ${HOME}/scripts
	mkdir -p ${HOME}.ssh
	ln -vsf ${PWD}/ssh/config ${HOME}/.ssh/config
	ln -vsf ${PWD}/stalonetrayrc ${HOME}/.stalonetrayrc
	ln -vsf ${PWD}/tmux_snapshot ${HOME}/tmux_snapshot
	ln -vsf ${PWD}/tmux.conf ${HOME}/.tmux.conf
	ln -vsf ${PWD}/urxvt ${HOME}/.urxvt
	ln -vsf ${PWD}/warprc ${HOME}/.warprc
	ln -vsf ${PWD}/weechat ${HOME}/.weechat
	ln -vsf ${PWD}/xinitrc ${HOME}/.xinitrc
	ln -vsf ${PWD}/Xmodmap ${HOME}/.Xmodmap
	ln -vsf ${PWD}/Xresources ${HOME}/.Xresources

gitlink: ## Link Git related files
	ln -vsf ${PWD}/gitconfig ${HOME}/.gitconfig
	ln -vsf ${PWD}/gitignore ${HOME}/.gitignore
	ln -vsf ${PWD}/git_template ${HOME}/.git_template

zshlink: ## Link ZSH related files
	ln -vsf ${PWD}/zprofile ${HOME}/.zprofile
	ln -vsf ${PWD}/zshenv ${HOME}/.zshenv
	ln -vsf ${PWD}/zshrc ${HOME}/.zshrc

vimlink: ## Link (Neo)Vim related files
	ln -vsf ${PWD}/vim/config.vim ${PWD}/config/nvim/init.vim
	ln -vsf ${PWD}/vim/common/after ${PWD}/config/nvim/after
	ln -vsf ${PWD}/vim/common/autoload ${PWD}/config/nvim/autoload
	ln -vsf ${PWD}/vim/common/ftdetect ${PWD}/config/nvim/ftdetect
	ln -vsf ${PWD}/vim/common/plugin ${PWD}/config/nvim/plugin
	ln -vsf ${PWD}/vim/common/syntax ${PWD}/config/nvim/syntax
	ln -vsf ${PWD}/vim/config.vim ${PWD}/vimrc
	ln -vsf ${PWD}/vimrc ${HOME}/.vimrc
	mkdir -p ${HOME}/.vim
	ln -vsf ${PWD}/vim/common/after ${HOME}/.vim/after
	ln -vsf ${PWD}/vim/common/autoload ${HOME}/.vim/autoload
	ln -vsf ${PWD}/vim/common/ftdetect ${HOME}/.vim/ftdetect
	ln -vsf ${PWD}/vim/common/plugin ${HOME}/.vim/plugin
	ln -vsf ${PWD}/vim/common/syntax ${HOME}/.vim/syntax

etclink: ## Link to /etc
	sudo mkdir -p /etc/pacman.d/hooks
	sudo ln -vsf ${PWD}/etc/pacman.conf /etc/pacman.conf
	sudo ln -vsf ${PWD}/etc/pacman.d/hooks/paccache.hook \
		/etc/pacman.d/hooks/paccache.hook
	sudo ln -vsf ${PWD}/etc/pacman.d/hooks/reflector.hook \
		/etc/pacman.d/hooks/reflector.hook
	sudo mkdir -p /etc/NetworkManager
	sudo ln -vsf ${PWD}/etc/NetworkManager/NetworkManager.conf \
		/etc/NetworkManager/NetworkManager.conf
	sudo cp ${PWD}/50-synaptics.conf /etc/X11/xorg.conf.d/

configlink: ## Link config directory
	mkdir -p ${HOME}/.config
	ln -vsf ${PWD}/config/archey3.cfg ${HOME}/.config/archey3.cfg
	ln -vsf ${PWD}/config/alacritty ${HOME}/.config/alacritty
	ln -vsf ${PWD}/config/bspwm ${HOME}/.config/bspwm
	ln -vsf ${PWD}/config/compton.conf ${HOME}/.config/compton.conf
	ln -vsf ${PWD}/config/dunst ${HOME}/.config/dunst
	ln -vsf ${PWD}/config/nvim ${HOME}/.config/nvim
	ln -vsf ${PWD}/config/ranger ${HOME}/.config/ranger
	ln -vsf ${PWD}/config/sxhkd ${HOME}/.config/sxhkd
	ln -vsf ${PWD}/config/termite ${HOME}/.config/termite
	ln -vsf ${PWD}/config/zathura ${HOME}/.config/zathura

install: ## Install development environment for arch linux
	sudo pacman -S \
		ack acpi acpi_call alsa-plugins alsa-utils asciidoc aspell aspell-en autopep8 \
		bspwm btfs \
		calibre cifs-utils chromium clang compton cscope ctags cups curl \
		dhex dnsmasq dropbox \
		elixir evince \
		feh ffmpegthumbnailer firefox flake8 fzf \
		gawk gdb gcc gcc-libs gimp git gnu-netcat grep gvfs gvfs-smb gzip \
		highlight htop httpie hub \
		iftop imagemagick \
		jq \
		keepassx2 \
		less lxappearance
		mlocate mpc mpd mps-youtube mpv \
		ncdu ncmpcpp neovim network-manager-applet networkmanager nitrogen nmap \
		ntfs-3g ntp \
		openssh \
		p7zip pandoc parallel pavucontrol pdfgrep postgresql postgresql-libs \
		postgresql-old-upgrade powertop pulseaudio pulseaudio-alsa pygmentize \
		python-jedi python-neovim python2-neovim python-pip python-pygments \
		python-pylint \
		r radare2 ranger redshift reflector ripgrep rsync rtmpdump rust rustfmt \
		rustup rust-racer \
		scrot sed shellcheck smartmontool sshfs stalonetray sxhkd \
		tcpdump termite texlive-latexextra thunar thunar-media-tags-plugin \
		thunar-volman thunderbird the_silver_searcher tig tlp tlp-rdw tmux \
		traceroute tree ttf-dejavu ttf-font-awesome ttf-hack tumbler typescript \
		unrar \
		vagrant valgrind vim virtualbox virtualbox-guest-iso virtualbox-host-dkms \
		vlc \
		w3m weechat wget whois wireshark-gtk wmctrl \
		x86_energy_perf_policy xautolock xclip xdo xdotool xf86-input-synaptics xsel \
		youtube-dl \
		zathura zathura-pdf-mupdf zsh

aur: ## Install AUR packages with pacaur
	pacaur -S alacritty-git arc-icon-theme-git
	pacaur -S bar-aint-recursive-git burpsuite
	pacaur -S caffeine-ng
	pacaur -S direnv discord dmenu-xft-mouse-height-fuzzy-history dropbox \
		dropbox-cli dunst-git dzen2-git
	pacaur -S fzf-extras
	pacaur -S git-extras gitflow-git gitter git-secrets global \
		gtk-arc-flatabulous-theme-git gtk-theme-arc-git
	pacaur -S i3lock-blur
	pacaur -S light-git lxappearance
	pacaur -S messengerfordesktop mog-git
	pacaur -S neofetch-git
	pacaur -S paper-icon-theme-git peco python-pywal-git
	pacaur -S rofi-git rxvt-unicode-cvs-patched-wideglyphs
	pacaur -S scudcloud streamlink-git streamlink-twitch-gui-git
	pacaur -S tdrop-git termite-ranger-fix-git thunar-dropbox tpacpi-bat-git \
		ttf-ancient-fonts ttf-font-icons ttf-ms-fonts
	pacaur -S unclutter-xfixes-git
	pacaur -S virtualbox-ext-oracle vtop
	pacaur -S websocketd-git wireshark-gtk
	pacaur -S xcb-util-cursor-git xcursors-oxygen xorg-server-utils xtitle-git
	pacaur -S zeal-git

rubyinstall: ## Install rubygems package
	RUBY_VERSION_LATEST_STABLE=2.4.2
	pacaur -S ruby ruby-build rbenv
	ln -vsf ${PWD}/gemrc ${HOME}/.gemrc
	ln -vsf ${PWD}/pryrc ${HOME}/.pryrc
	ln -vsf ${PDW}/rbenv/default-gems ${HOME}/.rbenv/default-gems
	rbenv install $RUBY_VERSION_LATEST_STABLE
	rbenv global $RUBY_VERSION_LATEST_STABLE

npmjs: ## Install node package
	pacaur -S nodejs npm
	mkdir -p ${HOME}/.node_modules
	export npm_config_prefix=${HOME}/.node_modules
	npm -g install npm
	npm -g install tern
	npm -g install jshint
	ln -vsf ${PWD}/npmrc ${HOME}/.npmrc

goinstall: ## Install go packages
	pacaur -S go
	export GOPATH="${HOME}/go"
	mkdir -p ${GOPATH}/{bin,src}
	export PATH="$PATH:$GOPATH/bin"
	go get -u github.com/nsf/gocode
	go get -u github.com/rogpeppe/godef
	go get -u golang.org/x/tools/cmd/goimports
	go get -u golang.org/x/tools/cmd/godoc
	go get -u github.com/josharian/impl
	go get -u github.com/jstemmer/gotags

backup: ## Backup archlinux packages
	mkdir -p ${HOME}/dotfiles/archlinux
	pacman -Qqen > ${HOME}/dotfiles/archlinux/pac_list
	pacman -Qnq > ${HOME}/dotfiles/archlinux/all_pac_list
	pacman -Qqem > ${HOME}/dotfiles/archlinux/aur_list

recover: ## Recovery from backup arch linux package
	sudo pacman -S --needed `cat ${HOME}/dotfiles/archlinux/pac_list`
	pacaur -S --needed $(DOY) `cat ${HOME}/dotfiles/archlinux/aur_list`

powertopinit: ## Powertop initial setup (Warning take a long time)
	sudo pacman -S powertop
	sudo powertop --calibrate
	sudo systemctl enable powertop

updatedb: ## Update file datebase
	sudo updatedb

all: aur backup configlink etclink goinstall homelink install npmjs \
	rubyinstall powertopinit recover updatedb vimlink zshlink help

.PHONY: all

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
