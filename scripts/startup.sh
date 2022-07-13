#!/usr/bin/env zsh

~/scripts/update_packages.sh

function echo_task { echo -e '\033[1mTASK: '"$1"'\033[0m'; }
function echo_ok { echo -e '\033[33m'"$1"'\033[0m'; }
function echo_warn  { echo -e '\033[31mWARNING: '"$1"'\033[0m'; }

echo_task "[+] Run 'zplug update' to update zplug and plugins..."
# echo_task "[+] Updating zplug and plugins..."
# source $HOME/.zplug/init.zsh
# zplug update
# echo_ok "...done!"

echo_task "[+] Run 'rbenv update' to update rbenv and plugins..."
# echo_task "[+] Updating rbenv and plugins..."
# rbenv update
# echo_ok "...done!"

echo_task "[+] Run 'cargo install-update -a' to update installed rust packages..."
echo_task "[+] Run 'aur_git_update_noconfirm' to update the AUR '*-git' packages..."

echo_task "[+] Updating Gems..."
gem update
echo_ok "...done!"

# echo_task "[+] Cleaning Gems..."
# gem cleanup
# echo_ok "...done!"

printf "[*] /// Dropbox status: "
dropbox-cli status

printf "[!] Startup complete.\n"
