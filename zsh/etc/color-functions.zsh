# ================================================
# COLOR FUNCTIONS
# ================================================

# Bold/No color
function echo_task { echo -e '\033[1mTASK: '"$1"'\033[0m'; }

# Yellow
function echo_ok { echo -e '\033[33m'"$1"'\033[0m'; }

# Red
function echo_warn  { echo -e '\033[31mWARNING: '"$1"'\033[0m'; }

# Bold/Green
function echo_go { echo -e '\e[32m\e[1m'"$1"'\e[0m'; }

