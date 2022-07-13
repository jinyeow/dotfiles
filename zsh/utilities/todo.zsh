# vim:foldmethod=marker:foldlevel=0
# ================================================
# Load TODOs or TASKs {{{
# ================================================
if [[ -d $(task show) ]] && (( $(ls $(task show) | wc -l) > 0 )); then
  task -l
elif [[ -d ~/.todo.d ]]; then
  if (( $(ls ~/.todo.d | wc -l) > 0 )); then
    todo -l
  fi
else
  echo "No tasks or todos."
fi

# }}}

