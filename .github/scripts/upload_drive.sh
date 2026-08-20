#!/usr/bin/env bash
# Uploads a built APK to Google Drive (service account) and posts the public
# download link to a Google Chat webhook.
#
# Usage: upload_drive.sh [ref]
#   ref        optional tag/branch name for the notification message
#
# Environment:
#   SA_JSON    service-account JSON key (raw or base64) — REQUIRED
#   FOLDER_ID  Drive folder (shared with the service account) — REQUIRED
#   WEBHOOK_URL  Google Chat webhook URL — OPTIONAL (skips Chat message)
#
# Expects exactly one APK at app/../apk/renttrack-*.apk (download-artifact path).

set -euo pipefail

REF="${1:-unknown}"

APK_FILE=$(ls apk/renttrack-*.apk | head -1)
VERSION=$(basename "$APK_FILE" | sed 's/renttrack-//; s/\.apk$//')

if [ -z "${SA_JSON:-}" ] || [ -z "${FOLDER_ID:-}" ]; then
  echo "::error::GDRIVE_SERVICE_ACCOUNT_JSON and GDRIVE_FOLDER_ID secrets are required"
  exit 1
fi

# Accept the service-account key either base64-encoded or as raw JSON.
if printf '%s' "$SA_JSON" | base64 -d 2>/dev/null | jq -e .client_email >/dev/null 2>&1; then
  printf '%s' "$SA_JSON" | base64 -d > /tmp/sa.json
else
  printf '%s' "$SA_JSON" > /tmp/sa.json
fi
jq -r .private_key /tmp/sa.json > /tmp/sa.pem
CLIENT_EMAIL=$(jq -r .client_email /tmp/sa.json)

# --- Exchange the service-account JWT for an access token (RS256).
NOW=$(date +%s)
JWT_HEADER=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' |
  openssl base64 -A | tr '+/' '-_' | tr -d '=')
JWT_CLAIMS=$(printf '%s' "{\"iss\":\"$CLIENT_EMAIL\",\"scope\":\"https://www.googleapis.com/auth/drive.file\",\"aud\":\"https://oauth2.googleapis.com/token\",\"iat\":$NOW,\"exp\":$((NOW + 3600))}" |
  openssl base64 -A | tr '+/' '-_' | tr -d '=')
SIGNING_INPUT="$JWT_HEADER.$JWT_CLAIMS"
JWT_SIG=$(printf '%s' "$SIGNING_INPUT" |
  openssl dgst -sha256 -sign /tmp/sa.pem |
  openssl base64 -A | tr '+/' '-_' | tr -d '=')
JWT="$SIGNING_INPUT.$JWT_SIG"

TOKEN=$(curl -fsS -X POST "https://oauth2.googleapis.com/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$JWT" |
  jq -r .access_token)
echo "Obtained Drive access token."

# --- Upload the APK into the shared folder.
FILE_ID=$(curl -fsS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "metadata={\"name\":\"$VERSION.apk\",\"parents\":[\"$FOLDER_ID\"]};type=application/json;charset=UTF-8" \
  -F "file=@$APK_FILE;type=application/vnd.android.package-archive" \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart" |
  jq -r .id)
echo "Uploaded to Drive (file id: $FILE_ID)."

# --- Make it downloadable by anyone with the link.
curl -fsS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"reader","type":"anyone"}' \
  "https://www.googleapis.com/drive/v3/files/$FILE_ID/permissions" >/dev/null

LINK=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://www.googleapis.com/drive/v3/files/$FILE_ID?fields=webContentLink" |
  jq -r .webContentLink)
echo "Public link: $LINK"
echo "drive_link=$LINK" >> "$GITHUB_OUTPUT"

# --- Notify the Google Chat space (optional).
if [ -n "${WEBHOOK_URL:-}" ]; then
  MESSAGE="New renttrack release **$VERSION** is ready.
Download APK (Google Drive): $LINK"
  PAYLOAD=$(jq -n --arg t "$MESSAGE" '{text: $t}')
  curl -fsS -X POST -H "Content-Type: application/json" \
    -d "$PAYLOAD" "$WEBHOOK_URL" >/dev/null
  echo "Posted link to Google Chat."
fi
