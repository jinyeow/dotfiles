#!/usr/bin/env sh

# 03/11/16
# Jin-Yeow J Puah
#
# Creates a local .projections.json file in the current directory
# The type is given as the only input argument.
# e.g. 'gen_projection.sh elixir' should generate a .projections.json from the
# elixir_projections.json file in dotfiles/vim/projections/

output=".projections.json"

if [ $# -lt 1 ]; then
  printf "Usage: gen_projection.sh [--force] [TYPE]"
  exit -1
elif [[ ! "$*" =~ "--force" ]] && [ -e "$output" ]; then
  echo "$output already exists."
  exit -1
fi

PROJ_DIR="$HOME/dotfiles/vim/projections/"
type=$1

projection="$PROJ_DIR""$type""_projections.json"
echo "[+] Creating $output for $type..."

if [ -e "$projection" ]; then
  cp "$projection" ./$output 2>/dev/null
  if [ -e "$output" ]; then
    echo "Done!"
  else
    echo "[!] Error: $output not created."
  fi
else
  echo "[!] $projection not found."
fi

