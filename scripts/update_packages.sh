#!/bin/bash

function echo_task { echo -e '\033[1mTASK: '"$1"'\033[0m'; }
function echo_ok { echo -e '\033[33m'"$1"'\033[0m'; }
function echo_warn  { echo -e '\033[31mWARNING: '"$1"'\033[0m'; }
function echo_go { echo -e '\e[32m\e[1m'"$1"'\e[0m'; }

echo_warn "[*] /// Starting package updates!\n"

# echo_task "[+] Updating Arch Packages..."
# pacaur -Syu
# echo_ok "...done!"

echo_task "[+] Updating from Official Arch Repository..."
sudo pacman -Syu
echo_ok "...done!"

echo_task "[+] Updating from AUR..."
trizen -Su --aur --needed --show-ood
echo_ok "...done!"

echo_task "[+] Updating locate database..."
sudo updatedb
echo_ok "...done!"

echo_task "[+] Updating pkgfile..."
sudo pkgfile --update
echo_ok "...done!"

echo_go "\n[*] /// Finished updating installed packages."
