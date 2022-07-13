# vim:foldmethod=marker:foldlevel=0
# ================================================
# Load MOTD {{{
# ================================================
if [[ -d ~/.motd.d ]]; then
  echo "MOTD:"
  echo "    $(date)"
  if [ -e ~/.motd.d/motd ]; then
    for line in "${(@f)$(cat ~/.motd.d/motd)}"
    do
      echo "    $line"
    done
  fi
  echo ""
fi

# }}}
