#!/usr/bin/env bash
set -euo pipefail

# ArkForge Trust Proof — GitHub Action entrypoint
# Generates a cryptographic timestamp proof via ArkForge Trust Layer

API_BASE="https://trust.arkforge.tech"
MAX_RETRIES=3
RETRY_DELAY=5
CURL_TIMEOUT=30

# --- Validate inputs ---
if [ -z "${INPUT_API_KEY:-}" ]; then
  echo "::error::api-key input is required. Get a free key: curl -X POST ${API_BASE}/v1/keys/free-signup -H 'Content-Type: application/json' -d '{\"email\":\"you@example.com\"}'"
  exit 1
fi

if [ -n "${INPUT_FILE:-}" ] && [ -n "${INPUT_HASH:-}" ]; then
  echo "::error::Provide either 'file' or 'hash', not both."
  exit 1
fi

if [ -z "${INPUT_FILE:-}" ] && [ -z "${INPUT_HASH:-}" ]; then
  echo "::error::Provide either 'file' (path to hash) or 'hash' (precomputed SHA-256)."
  exit 1
fi

# --- Compute hash ---
FILE_HASH=""
if [ -n "${INPUT_FILE:-}" ]; then
  if [ ! -f "${INPUT_FILE}" ]; then
    echo "::error::File not found: ${INPUT_FILE}"
    exit 1
  fi
  FILE_HASH=$(sha256sum "${INPUT_FILE}" | cut -d' ' -f1)
  echo "File SHA-256: ${FILE_HASH}"
else
  FILE_HASH="${INPUT_HASH}"
  echo "Using provided hash: ${FILE_HASH}"
fi

# --- Build description ---
DESC="${INPUT_DESCRIPTION:-}"
if [ -z "${DESC}" ]; then
  DESC="GitHub Action proof"
fi
DESC="${DESC} | repo:${GITHUB_REPOSITORY:-unknown} commit:${GITHUB_SHA:-unknown} file_hash:sha256:${FILE_HASH}"

# --- Generate proof via Trust Layer proxy (with retry) ---
echo "Generating timestamp proof..."

ATTEMPT=0
BODY=""
HTTP_CODE=""
while [ "${ATTEMPT}" -lt "${MAX_RETRIES}" ]; do
  ATTEMPT=$((ATTEMPT + 1))

  RESPONSE=$(curl -s --max-time "${CURL_TIMEOUT}" -w "\n%{http_code}" -X POST "${API_BASE}/v1/proxy" \
    -H "X-Api-Key: ${INPUT_API_KEY}" \
    -H "X-Agent-Identity: arkforge-trust-proof-action" \
    -H "X-Agent-Version: 1.0.0" \
    -H "Content-Type: application/json" \
    -d "$(cat <<EOF
{
  "target": "${API_BASE}/v1/health",
  "payload": {},
  "method": "GET",
  "description": "${DESC}"
}
EOF
)" 2>/dev/null) || true

  HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
  BODY=$(echo "${RESPONSE}" | sed '$d')

  # Success or client error (4xx) — don't retry
  if [ -n "${HTTP_CODE}" ] && [ "${HTTP_CODE}" -ge 200 ] && [ "${HTTP_CODE}" -lt 500 ]; then
    break
  fi

  # Server error or network failure — retry
  if [ "${ATTEMPT}" -lt "${MAX_RETRIES}" ]; then
    echo "::warning::Attempt ${ATTEMPT}/${MAX_RETRIES} failed (HTTP ${HTTP_CODE:-timeout}). Retrying in ${RETRY_DELAY}s..."
    sleep "${RETRY_DELAY}"
  fi
done

if [ -z "${HTTP_CODE}" ] || [ "${HTTP_CODE}" -ge 400 ]; then
  echo "::error::Trust Layer returned HTTP ${HTTP_CODE:-timeout} after ${MAX_RETRIES} attempts: ${BODY}"
  exit 1
fi

# --- Extract proof fields ---
PROOF_ID=$(echo "${BODY}" | jq -r '.proof.proof_id // empty')
if [ -z "${PROOF_ID}" ]; then
  echo "::error::No proof_id in response. Full response: ${BODY}"
  exit 1
fi

CHAIN_HASH=$(echo "${BODY}" | jq -r '.proof.hashes.chain // "n/a"')
TIMESTAMP=$(echo "${BODY}" | jq -r '.proof.timestamp // "n/a"')
SIGNATURE=$(echo "${BODY}" | jq -r '.proof.arkforge_signature // "n/a"')
PROOF_URL="${API_BASE}/v1/proof/${PROOF_ID}"

# --- Set outputs ---
echo "proof_id=${PROOF_ID}" >> "${GITHUB_OUTPUT}"
echo "proof_url=${PROOF_URL}" >> "${GITHUB_OUTPUT}"
echo "chain_hash=${CHAIN_HASH}" >> "${GITHUB_OUTPUT}"
echo "timestamp=${TIMESTAMP}" >> "${GITHUB_OUTPUT}"
echo "file_hash=${FILE_HASH}" >> "${GITHUB_OUTPUT}"
echo "badge=[![Trust Proof](https://img.shields.io/badge/Trust_Proof-verified-8b5cf6?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNiIgaGVpZ2h0PSIxNiIgdmlld0JveD0iMCAwIDE2IDE2Ij48Y2lyY2xlIGN4PSI4IiBjeT0iOCIgcj0iNyIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIxLjUiLz48cGF0aCBkPSJNNSA4bDIgMiA0LTQiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iMS41Ii8+PC9zdmc+)](${PROOF_URL})" >> "${GITHUB_OUTPUT}"

# --- Summary ---
echo ""
echo "=== Trust Proof Generated ==="
echo "  Proof ID:   ${PROOF_ID}"
echo "  Timestamp:  ${TIMESTAMP}"
echo "  File Hash:  sha256:${FILE_HASH}"
echo "  Chain Hash: ${CHAIN_HASH}"
echo "  Signature:  ${SIGNATURE}"
echo "  Verify:     ${PROOF_URL}"
echo "============================="

# --- GitHub Step Summary ---
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat >> "${GITHUB_STEP_SUMMARY}" <<SUMMARY

### Trust Proof

| Field | Value |
|-------|-------|
| Proof ID | [\`${PROOF_ID}\`](${PROOF_URL}) |
| Timestamp | ${TIMESTAMP} |
| File Hash | \`sha256:${FILE_HASH}\` |
| Chain Hash | \`${CHAIN_HASH}\` |
| Signature | \`${SIGNATURE:0:32}...\` |

[View full proof](${PROOF_URL})
SUMMARY
fi
