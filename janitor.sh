#!/bin/bash
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT=github-runners
SERVICE=runner
TARGET=4                         # desired number of ephemeral runners

# Load environment variables
if [ -f .env ]; then
  source .env
fi

# Determine target (org/repo/enterprise)
if [ -n "${REPO:-}" ]; then
  TARGET_TYPE="repos/${REPO}"
elif [ -n "${ORG:-}" ]; then
  TARGET_TYPE="orgs/${ORG}"
elif [ -n "${ENTERPRISE:-}" ]; then
  TARGET_TYPE="enterprises/${ENTERPRISE}"
else
  echo "❌ Must set ORG, REPO, or ENTERPRISE in .env"
  exit 1
fi

# Determine runner name pattern (same logic as entrypoint.sh)
if [ -n "${RUNNER_NAME:-}" ]; then
  # If RUNNER_NAME is set, use it as the pattern
  RUNNER_PATTERN="${RUNNER_NAME}"
else
  # If not set, use the default pattern from entrypoint.sh
  RUNNER_PATTERN="ephemeral-runner-"
fi

current=$(docker ps \
  -f "label=com.docker.compose.project=$PROJECT" \
  -f "label=com.docker.compose.service=$SERVICE" \
  -f "status=running" -q | wc -l)

stopped=$(docker ps -a \
  -f "label=com.docker.compose.project=$PROJECT" \
  -f "label=com.docker.compose.service=$SERVICE" \
  -f "status=exited" -q)

# prune stopped containers
if [[ -n "$stopped" ]]; then
  echo "🧹 Removing stopped runner containers"
  docker ps -a -q -f "label=com.docker.compose.project=$PROJECT" \
    -f "label=com.docker.compose.service=$SERVICE" \
    -f "status=exited" | xargs -r docker rm
fi

# Clean up orphaned runners from GitHub
echo "🔍 Checking for orphaned runners in GitHub..."
if [ -n "${ACCESS_TOKEN:-}" ]; then
  # Get list of offline runners that match our naming pattern
  RUNNERS=$(curl -sS -H "Authorization: token ${ACCESS_TOKEN}" \
    "https://api.github.com/${TARGET_TYPE}/actions/runners" | \
    jq -r --arg pattern "$RUNNER_PATTERN" '.runners[] | select(.status == "offline" and (.name | startswith($pattern))) | .id')
  
  if [ -n "$RUNNERS" ]; then
    echo "🧹 Deregistering offline runners from GitHub..."
    for runner_id in $RUNNERS; do
      echo "  Removing runner $runner_id"
      # Use GitHub API to remove the runner directly
      curl -sS -X DELETE \
        -H "Authorization: token ${ACCESS_TOKEN}" \
        "https://api.github.com/${TARGET_TYPE}/actions/runners/${runner_id}" || \
        echo "  ⚠️  Failed to remove runner $runner_id"
    done
  else
    echo "✅ No offline runners found in GitHub"
  fi
else
  echo "⚠️  No ACCESS_TOKEN found, skipping GitHub cleanup"
fi

if (( current < TARGET )); then
  echo "🚀 Current runners: $current, target $TARGET — scaling up"
  docker compose up -d --scale ${SERVICE}=${TARGET}
else
  echo "✅ $current runners active (target $TARGET)"
fi