#!/bin/bash
set -euo pipefail

RUNNER_NAME=${RUNNER_NAME:-ephemeral-runner-$(cat /proc/sys/kernel/random/uuid | tr -d '-' | cut -c1-8)}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-/tmp/_work}
LABELS=${LABELS:-self-hosted,ephemeral}

echo "➡️  Starting ephemeral runner ${RUNNER_NAME}"

if [ -n "${REPO:-}" ]; then
  TARGET="repos/${REPO}"
  URL="https://github.com/${REPO}"
elif [ -n "${ORG:-}" ]; then
  TARGET="orgs/${ORG}"
  URL="https://github.com/${ORG}"
elif [ -n "${ENTERPRISE:-}" ]; then
  TARGET="enterprises/${ENTERPRISE}"
  URL="https://github.com/enterprises/${ENTERPRISE}"
else
  echo "❌ Must set ORG, REPO, or ENTERPRISE"
  exit 1
fi

echo "➡️  Requesting registration token..."
REG_TOKEN=$(curl -sS -X POST \
  -H "Authorization: token ${ACCESS_TOKEN}" \
  "https://api.github.com/${TARGET}/actions/runners/registration-token" \
  | jq -er .token)

mkdir -p "${RUNNER_WORKDIR}"

echo "➡️  Configuring ephemeral runner..."
/home/runner/config.sh \
  --url "${URL}" \
  --token "${REG_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --work "${RUNNER_WORKDIR}" \
  --labels "${LABELS}" \
  --unattended \
  --ephemeral

echo "✅ Runner configured (ephemeral). Waiting for a job..."
exec /home/runner/run.sh