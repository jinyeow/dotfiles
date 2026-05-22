#!/bin/sh
COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

# Skip auto-generated commit messages (merge, squash)
case "$COMMIT_SOURCE" in
    merge|squash) exit 0 ;;
esac

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || exit 0

# Branch skip list. Override per-repo with:
#   git config hooks.skipBranches "main,release/*,hotfix/*"
SKIP_CSV=$(git config --get hooks.skipBranches 2>/dev/null)
if [ -z "$SKIP_CSV" ]; then
    SKIP_CSV="main,master,develop,staging,test,deploy/*"
fi

OLD_IFS="$IFS"
IFS=','
for pattern in $SKIP_CSV; do
    # Trim whitespace
    pattern=$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # shellcheck disable=SC2254  # glob pattern intentional
    case "$BRANCH" in
        $pattern) exit 0 ;;
    esac
done
IFS="$OLD_IFS"

# Detect ticket ID from branch name:
#   JIRA: feature/PROJ-123-description  →  Refs: PROJ-123
#   ADO:  feature/1234-description      →  Refs: AB#1234
TICKET=$(printf '%s' "$BRANCH" | sed -n 's|.*/\([A-Z][A-Z]*-[0-9][0-9]*\).*|\1|p')
if [ -n "$TICKET" ]; then
    TRAILER="Refs: $TICKET"
else
    ID=$(printf '%s' "$BRANCH" | sed -n 's|.*/\([0-9][0-9]*\)-.*|\1|p')
    [ -n "$ID" ] || exit 0
    TRAILER="Refs: AB#$ID"
fi

# Skip if trailer already present (e.g. amending an already-tagged commit)
grep -qF "$TRAILER" "$COMMIT_MSG_FILE" && exit 0

# Append as a git trailer — blank line separates body from footer
TRIMMED=$(sed -e 's/[[:space:]]*$//' "$COMMIT_MSG_FILE" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba}')
printf '%s\n\n%s\n' "$TRIMMED" "$TRAILER" > "$COMMIT_MSG_FILE"
