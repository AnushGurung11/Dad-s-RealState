#!/usr/bin/env bash
# Uploads a built APK to Google Drive (service account) and posts the public
# download link to a Discord channel via webhook.
#
# Usage: upload_drive.sh [ref]
#   ref        optional tag/branch name for the notification message
#
# Environment:
#   SA_JSON    service-account JSON key (raw or base64) - REQUIRED
#   FOLDER_ID  Drive folder (shared with the service account) - REQUIRED
#   DISCORD_WEBHOOK_URL  Discord webhook URL - OPTIONAL (skips Discord message)
#
# Expects exactly one APK in apk/ (the release workflow renames it to
# LUCK-<version>+<build>.apk before uploading it as an artifact).

set -euo pipefail

REF="${1:-unknown}"

APK_FILE=$(find apk -maxdepth 1 -type f -name '*.apk' -print -quit)
if [ -z "$APK_FILE" ]; then
  echo "::error::No APK found in apk/. Contents:"
  ls -la apk || true
  exit 1
fi
VERSION=$(basename "$APK_FILE" .apk | sed 's/^LUCK-//')
echo "Uploading $APK_FILE (version $VERSION, ref $REF)."

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

if [ -z "$FILE_ID" ] || [ "$FILE_ID" = "null" ]; then
  echo "::error::Drive upload did not return a file id"
  exit 1
fi
echo "Uploaded to Drive (file id: $FILE_ID)."

# --- Make the file readable by anyone with the link.
curl -fsS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"reader","type":"anyone"}' \
  "https://www.googleapis.com/drive/v3/files/$FILE_ID/permissions" > /dev/null
LINK="https://drive.google.com/file/d/$FILE_ID/view?usp=sharing"
echo "Public link: $LINK"

# --- Optional Discord notification.
if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
  curl -fsS -X POST -H "Content-Type: application/json" \
    -d "$(jq -n --arg ref "$REF" --arg ver "$VERSION" --arg link "$LINK" \
      '{content: ("LUCKY " + $ver + " is ready (" + $ref + "): " + $link)}')" \
    "$DISCORD_WEBHOOK_URL" > /dev/null
  echo "Posted to Discord."
else
  echo "DISCORD_WEBHOOK_URL not set; skipping Discord notification."
fi
