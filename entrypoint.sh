#!/bin/bash
set -euo pipefail

# --- Define safe defaults up front -------------------------------------
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-/runners/_work}
LABELS=${LABELS:-self-hosted}
RUNNER_ROOT=${RUNNER_ROOT:-/runners}

RUNNER_DIR="${RUNNER_ROOT}/${RUNNER_NAME}"
CONFIG_PATH="${CONFIG_PATH:-${RUNNER_DIR}/.runner}"
# -----------------------------------------------------------------------

echo "🛠 Preparing filesystem permissions..."
# Ensure folders exist and are writable for the 'runner' user
mkdir -p "${RUNNER_WORKDIR}" "${RUNNER_DIR}"
chown -R runner:runner "${RUNNER_WORKDIR}" "${RUNNER_DIR}" || true
chmod -R 777 "${RUNNER_WORKDIR}"

cd "${RUNNER_DIR}"

# --- Determine registration target -------------------------------------
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

# --- Register runner (only if not already configured) ------------------
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

# --- Graceful deregistration on shutdown -------------------------------
cleanup() {
  echo "🧹 Deregistering ${RUNNER_NAME}..."
  REMOVE_TOKEN=$(curl -sS -X POST \
    -H "Authorization: token ${ACCESS_TOKEN}" \
    "https://api.github.com/${TARGET}/actions/runners/remove-token" \
    | jq -er .token)
  /home/runner/config.sh remove --token "${REMOVE_TOKEN}" || true
}
trap 'cleanup; exit 130' INT TERM

# --- Start runner service ----------------------------------------------
echo "✅ Runner ${RUNNER_NAME} ready – listening for jobs"
exec /home/runner/run.sh