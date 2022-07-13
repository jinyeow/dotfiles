# ================================================
# REDDIT
# ================================================

# Hit up the Reddit API with httpie+jq and return up to 100 of the hottest posts
reddit_summon() {
  local base='https://www.reddit.com/'
  local key='.title'
  local limit_count=50 # default number of posts to GET
  local multi=''
  local search=''
  local sub=''
  local url=''
  local user="user/Chaoist/" # default user for a multireddit

  local fin=0

  while [ $# -gt 0 ]; do
    case $1 in
      --sub*)
        shift 1
        sub="r/$1"
        shift 1
        ;;
      --multi)
        shift 1
        multi="m/$1"
        shift 1
        ;;
      --user|-u)
        shift 1
        user="user/$1/"
        shift 1
        ;;
      -l|--limit)
        shift 1
        limit_count=$1
        shift 1
        ;;
      -s|--search)
        shift 1
        search="$1"
        shift 1
        ;;
      -k|--keys)
        shift 1
        key="$1"
        shift 1
        ;;
      -t|--table)
        shift 1
        key='"\(.id)\t| \(.title)"'
        ;;
      -h|--help)
        shift 1
        fin=1
        break
        ;;
      *)
        echo "[!] Invalid option '$1'.\n"
        fin=1
        break
        ;;
    esac
  done

  # echo "$key"
  if [ ! -z "$sub" ]; then
    url="$base$sub"
  elif [ ! -z "$multi" ] && [ ! -z "$user" ]; then
    url="$base$user$multi"
  else
    echo "[!] No subreddit or multireddit specified."
    echo "    Note that a user must be given when scraping a multi.\n"
    fin=1
  fi

  if [ "$fin" -ne 1 ]; then
    if [ ! "$(http --headers $url)" =~ "404 Not Found" ]; then
      http $url/.json\?limit\=$limit_count | \
        jq '[select(.data != null) | .data .children [] | .data | with_entries(select(.key == ("selftext", "title", "url", "id")))]' | \
        jq -c --arg term "$search" '[.[] | select(.title | contains($term))]' | \
        jq -r ".[] | $key"
    else
      echo "[!] 404 Not Found."
    fi
  else
    echo "USAGE: $0 [options]"
    echo "OPTIONS:"
    echo "  -l, --limit:  Define the number of posts to retrieve."
    echo "  -s, --search: Search term to filter the posts by (based on title)."
    echo "  -k, --keys:   The key(s) to output."
    echo "      --sub:    Define which subreddit to scrape."
    echo "      --multi:  Define which multi-subreddit to scrape."
    echo "  -u, --user:   The user that the '--multi' belongs to. A --multi requires a --user."
    echo "  -h, --help:   Print this message."
  fi
}

# Prints out comments associated with a post and subreddit.
# Currently only prints out top-level comments; no replies.
# FIXME: fix printing outprinting out nested replies to comments.
comments() {
  local fin=0
  local sub=''
  local id=''
  # local output='"## \(.author) said:\n\(.body)\n\n\t=> # \(.replies.data.children[].data.author) said: \(.replies.data.children[].data.body)\n-------------------------------\n"'
  local output='"## \(.author) said:\n\(.body)\n-------------------------------\n"'

  while [ $# -gt 0 ]; do
    case $1 in
      -s|--sub)
        shift 1
        sub="$1"
        shift 1
        ;;
      -i|--id)
        shift 1
        id="$1"
        shift 1
        ;;
      -o|--output)
        shift 1
        output="$1"
        shift 1
        ;;
      -h|--help)
        shift 1
        fin=1
        ;;
      *)
        echo "Invalid option '$1'."
        fin=1
        break
        ;;
    esac
  done

  if [ -z "$sub" ]; then
    echo "Define a subreddit using the -s flag."
    fin=1
  elif [ -z "$id" ]; then
    echo "Define a post id using the -i flag."
    fin=1
  fi

  if [ "$fin" -eq 0 ]; then
    http https://www.reddit.com/r/$sub/comments/$id/.json | \
      jq '[[.[] | .data .children []] | .[1:] | .[].data]' | \
      jq '[.[] | with_entries(select(.key == ("author", "body", "replies")))]' | \
      jq -r ".[] | $output"
  elif [ "$fin" -eq 1 ]; then
    echo "USAGE: $0 [options]"
    echo "OPTIONS:"
    echo "  -s, --sub:  Define the subreddit."
    echo "  -i, --id:   Define the post id."
    echo "  -h, --help: Print this message."
  fi
}

