#!/bin/bash

# Author:       Jin-Yeow J Puah
# Last Updated: 12/11/16
#
# This is a script to 'generate' a gitignore.
# Using the GITIGNORE_URL this script fetches and downloads the appropriate
# general gitignore files for the given filetypes
#
# For example,
#   $ gen_gitignore ruby elixir
# will use the url:
#   https://www.gitignore.io/api/ruby,elixir
# to create a .gitignore file.

GITIGNORE_URL="https://www.gitignore.io/api/"
args=$(echo $@ | sed 's/ /,/g')

echo -n "[+] Generating .gitignore in $(pwd) for $(echo $args | sed 's/,/, /g')..."

wget -q -O ".gitignore" $GITIGNORE_URL$args

echo "tags" >> ".gitignore"

if [ -f ".gitignore" ]; then
  echo "done!"
  echo "[+] Contents of .gitignore:"
  cat ".gitignore"
else
  echo "\n[!] Error occurred!"
fi
