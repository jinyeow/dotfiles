# Put stuff that applies to your whole session, such as programs that you want
# to start when you login, and environment variable definitions

export XDG_CONFIG_HOME="$HOME/.config"

test -d "$HOME/.rbenv/bin" && export PATH="$HOME/.rbenv/bin:$PATH" || true
