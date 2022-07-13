#!/usr/bin/env bash

reddit_icon=""
rw_status=""

if [ -f "/tmp/reddwatch.pid" ]; then
  if pgrep -x reddwatch >/dev/null ; then
    list=$($HOME/.rbenv/shims/reddwatch -P | ruby -n -e 'puts $_ unless $_.match(/^{:[a-z]+=>.*}$/)')
    rw_status="$reddit_icon: $list"
    # rw_status="$reddit_icon: on"
  fi
else
  rw_status="$reddit_icon: %{F#66}off%{F-}"
fi
echo "$rw_status"

