###############################################################################
#                              OPTIONS                                        #
#                         ------------------                                  #
###############################################################################

# Intelligent Commands
setopt auto_cd

# Enable extended globbing
setopt extendedglob

# Allow [ or ] whereever you want
unsetopt nomatch

#-- Settings
setopt correct
setopt glob_dots
setopt print_exit_value

unsetopt flowcontrol

#-- Completion
setopt always_to_end
setopt auto_menu         # show completion menu on successive tab press
setopt auto_param_slash
setopt complete_in_word
setopt glob_complete
setopt list_beep
setopt list_packed
setopt no_beep

#-- Directories
# Changing/making/removing directory
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt pushd_silent

# Sets a limit on the directory stack
# DIRSTACKSIZE=8

#-- History
setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_dups # ignore duplication command history list
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_verify
setopt inc_append_history
setopt share_history # share command history data

#-- Job Control
setopt notify

## jobs
setopt long_list_jobs

# recognize comments
setopt interactive_comments

