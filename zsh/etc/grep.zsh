# Sets an alias for search based on what commands are available on the system.
# Uses either ripgrep, ag, egrep, or grep in that order.
# If using (e)grep adds on some useful options.

if which ripgrep >/dev/null 2>&1; then
    SEARCH="ripgrep"
elif which ag >/dev/null 2>&1; then
    SEARCH="ag"
elif which egrep >/dev/null 2>&1; then
    SEARCH="egrep"
else
    SEARCH="grep"
fi

# is x grep argument available?
grep-flag-available() {
    echo | $SEARCH $1 "" >/dev/null 2>&1
}

GREP_OPTIONS=""

# color grep results
if grep-flag-available --color=auto; then
    GREP_OPTIONS+=" --color=auto"
fi

# ignore VCS folders (if the necessary grep flags are available)
VCS_FOLDERS="{.bzr,CVS,.git,.hg,.svn}"

if grep-flag-available --exclude-dir=.cvs; then
    GREP_OPTIONS+=" --exclude-dir=$VCS_FOLDERS"
elif grep-flag-available --exclude=.cvs; then
    GREP_OPTIONS+=" --exclude=$VCS_FOLDERS"
fi

# export grep settings
alias search="$SEARCH$GREP_OPTIONS"

# clean up
unset GREP_OPTIONS
unset VCS_FOLDERS
unfunction grep-flag-available
unset SEARCH
