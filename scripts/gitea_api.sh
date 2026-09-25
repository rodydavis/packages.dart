#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# Gitea REST API Client for Antigravity AI Factory
# Manages Issues, Comments, and Pull Requests with full traceability.
# ==============================================================================

GITEA_URL="${GITEA_SERVER_URL:-https://git.rodydavis.dev}"
GITEA_REPO="${GITEA_REPOSITORY:-rodydavis/packages.dart}"
TOKEN="${GITEA_TOKEN:-}"

if [ -z "$TOKEN" ] && [ -f "$HOME/.config/gitea/token" ]; then
  TOKEN="$(cat "$HOME/.config/gitea/token" | tr -d '\n\r')"
fi

if [ -z "$TOKEN" ]; then
  echo "Error: GITEA_TOKEN is not set and ~/.config/gitea/token was not found." >&2
  exit 1
fi

ACTION="${1:-help}"
shift || true

api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  if [ -n "$data" ]; then
    curl -s -X "$method" \
      -H "Authorization: token $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "$GITEA_URL/api/v1/repos/$GITEA_REPO$endpoint"
  else
    curl -s -X "$method" \
      -H "Authorization: token $TOKEN" \
      -H "Content-Type: application/json" \
      "$GITEA_URL/api/v1/repos/$GITEA_REPO$endpoint"
  fi
}

case "$ACTION" in
  create-issue)
    TITLE="$1"
    BODY="$2"
    LABELS="${3:-ai-factory}"

    PAYLOAD=$(python3 -c "
import json, sys
title = sys.argv[1]
body = sys.argv[2]
labels_str = sys.argv[3]
labels = [l.strip() for l in labels_str.split(',') if l.strip()]
print(json.dumps({'title': title, 'body': body}))
" "$TITLE" "$BODY" "$LABELS")

    RESP=$(api_call POST "/issues" "$PAYLOAD")
    ISSUE_NUM=$(echo "$RESP" | python3 -c 'import sys, json; res = json.load(sys.stdin); print(res.get("number", ""))')
    ISSUE_URL=$(echo "$RESP" | python3 -c 'import sys, json; res = json.load(sys.stdin); print(res.get("html_url", ""))')

    if [ -n "$ISSUE_NUM" ]; then
      echo "Issue #$ISSUE_NUM created: $ISSUE_URL"
      echo "$ISSUE_NUM"
    else
      echo "Error creating issue: $RESP" >&2
      exit 1
    fi
    ;;

  get-issue)
    ISSUE_NUM="$1"
    RESP=$(api_call GET "/issues/$ISSUE_NUM")
    echo "$RESP"
    ;;

  comment-issue)
    ISSUE_NUM="$1"
    COMMENT="$2"
    PAYLOAD=$(python3 -c 'import json, sys; print(json.dumps({"body": sys.argv[1]}))' "$COMMENT")
    api_call POST "/issues/$ISSUE_NUM/comments" "$PAYLOAD" >/dev/null
    echo "Comment added to Issue #$ISSUE_NUM."
    ;;

  close-issue)
    ISSUE_NUM="$1"
    COMMENT="${2:-}"
    if [ -n "$COMMENT" ]; then
      PAYLOAD=$(python3 -c 'import json, sys; print(json.dumps({"body": sys.argv[1]}))' "$COMMENT")
      api_call POST "/issues/$ISSUE_NUM/comments" "$PAYLOAD" >/dev/null
    fi
    api_call PATCH "/issues/$ISSUE_NUM" '{"state": "closed"}' >/dev/null
    echo "Issue #$ISSUE_NUM closed."
    ;;

  create-pr)
    HEAD_BRANCH="$1"
    BASE_BRANCH="${2:-main}"
    TITLE="$3"
    BODY="$4"
    ISSUE_NUM="${5:-}"

    if [ -n "$ISSUE_NUM" ]; then
      BODY="${BODY}

Closes #${ISSUE_NUM}
"
    fi

    PAYLOAD=$(python3 -c "
import json, sys
head = sys.argv[1]
base = sys.argv[2]
title = sys.argv[3]
body = sys.argv[4]
print(json.dumps({'head': head, 'base': base, 'title': title, 'body': body}))
" "$HEAD_BRANCH" "$BASE_BRANCH" "$TITLE" "$BODY")

    RESP=$(api_call POST "/pulls" "$PAYLOAD")
    PR_NUM=$(echo "$RESP" | python3 -c 'import sys, json; res = json.load(sys.stdin); print(res.get("number", ""))')
    PR_URL=$(echo "$RESP" | python3 -c 'import sys, json; res = json.load(sys.stdin); print(res.get("html_url", ""))')

    if [ -n "$PR_NUM" ]; then
      echo "Pull Request #$PR_NUM created: $PR_URL"
      if [ -n "$ISSUE_NUM" ]; then
        api_call POST "/issues/$ISSUE_NUM/comments" "{\"body\": \"Pull Request #$PR_NUM has been opened for this issue: $PR_URL\"}" >/dev/null || true
      fi
      echo "$PR_URL"
    else
      echo "Error creating PR: $RESP" >&2
      exit 1
    fi
    ;;

  list-issues)
    STATE="${1:-open}"
    api_call GET "/issues?state=$STATE"
    ;;

  *)
    echo "Usage: $0 {create-issue|get-issue|comment-issue|close-issue|create-pr|list-issues}"
    exit 1
    ;;
esac
