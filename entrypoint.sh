#!/bin/bash
set -euo pipefail

# --- Define safe defaults up front -----------------------------------
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-_work}
LABELS=${LABELS:-self-hosted}
RUNNER_ROOT=${RUNNER_ROOT:-/runners}

RUNNER_DIR="${RUNNER_ROOT}/${RUNNER_NAME}"
CONFIG_PATH="${CONFIG_PATH:-${RUNNER_DIR}/.runner}"

mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

# --- Determine registration target -----------------------------------
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

# --- Register runner (if needed) -------------------------------------
if [ ! -f "${CONFIG_PATH}" ]; then
  echo "➡️  Registering runner ${RUNNER_NAME}..."
  REG_TOKEN=$(curl -sS -X POST \
    -H "Authorization: token ${ACCESS_TOKEN}" \
    "https://api.github.com/${TARGET}/actions/runners/registration-token" \
    | jq -er .token)

  /home/runner/config.sh \
    --url "${URL}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --work "${RUNNER_WORKDIR}" \
    --labels "${LABELS}" \
    --unattended \
    --replace
else
  echo "ℹ️  ${RUNNER_NAME} already configured, skipping registration."
fi

# --- Clean deregistration on stop ------------------------------------
cleanup() {
  echo "🧹 Deregistering ${RUNNER_NAME}..."
  REMOVE_TOKEN=$(curl -sS -X POST \
    -H "Authorization: token ${ACCESS_TOKEN}" \
    "https://api.github.com/${TARGET}/actions/runners/remove-token" \
    | jq -er .token)
  /home/runner/config.sh remove --token "${REMOVE_TOKEN}" || true
}
trap 'cleanup; exit 130' INT TERM

echo "✅ Runner ${RUNNER_NAME} ready – listening for jobs"
exec /home/runner/run.sh