# Lucky — app runbook

The root [README](../README.md) covers the product, architecture, domain rules, and test
strategy. This file is the operational detail: where data lives, how to run and release the
app, and which secrets CI needs.

The Dart package is still named `lucky` (application ID `com.renttrack.renttrack`); the
product name is **LUCKY** and the legacy `renttrack` identifier is kept for data and install
compatibility.

## Run locally

```bash
flutter pub get
flutter run          # requires a connected Android device or emulator
```

Full local gate:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Where data lives and how to back it up

Data is stored as eleven JSON collections plus `schema.json` (which records the schema
version) in the app's **documents directory** on the device:

| File | Contents |
|------|----------|
| `flats.json` | Flats (contract date/person, yearly rent) |
| `beds.json` | Beds (default monthly rent) |
| `people.json` | Tenants (join/vacated dates, planned stay, monthly rent, deposit, notes) |
| `payments.json` | Rent and deposit payment records |
| `expenses.json` | Expense records per flat |
| `lease_check_settings.json` | Per-flat cheque config (owner, amount, next due date, interval); on-disk name kept for compatibility |
| `lease_check_records.json` | Immutable archive of cheques marked paid |
| `terminations.json` | Termination and abscond records |
| `legal_documents.json` | Per-flat legal document metadata |
| `audit_log.json` | Before/after snapshots for rent and expense edits |
| `schema.json` | Schema version and metadata |
| `legal_docs/` | Document images copied into private app storage |

Writes are atomic (`*.json.tmp` + rename) and debounced, so copying the files at any time is
safe. A leftover `.tmp` from a crash mid-write never corrupts real data.

To inspect data manually:

```bash
adb shell run-as com.renttrack.renttrack ls files
adb exec-out run-as com.renttrack.renttrack cat files/flats.json > flats.json
```

Backups (More → Data → Create backup) produce a zip of every collection plus legal-document
images, and are validated before a restore replaces anything.

## Release process

1. Bump `version:` in `app/pubspec.yaml`, e.g. `version: 2.3.0+24`.
2. Commit and push.
3. Tag and push:
   ```bash
   git tag v2.3.0
   git push origin v2.3.0
   ```
4. The **Release** workflow builds a signed APK, renames it to
   `LUCK-<version>+<build>.apk`, publishes a GitHub Release with generated notes, then runs
   the optional Drive upload and Discord notification.

A manual run with a version override is available under **Actions → Release → Run workflow**.

## GitHub secrets for signing

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the signing keystore: `base64 -w 0 release.keystore` |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias |

Secrets are referenced through job-level environment variables, never directly in `if:`
conditions.

To sign locally instead, create `app/android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=release.keystore
```

and place `release.keystore` in `app/android/`.

## Optional Drive upload and Discord notification

The `upload` job in `release.yml` downloads the APK artifact, uploads it to a Google Drive
folder, makes the file link-readable, and posts the link to Discord. It is skipped unless the
first two secrets exist.

| Secret | Value |
|--------|-------|
| `GDRIVE_SERVICE_ACCOUNT_JSON` | Google Cloud service-account JSON key (raw or base64) with the **Drive API** enabled |
| `GDRIVE_FOLDER_ID` | ID of a Drive folder shared with the service account email (Editor) |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL; omit to skip Discord messages |

Setup:

1. Google Cloud → IAM → Service accounts → create one, enable **Google Drive API**, download
   its JSON key → `GDRIVE_SERVICE_ACCOUNT_JSON`.
2. Create a Drive folder, share it with the service-account email (Editor), copy the folder ID
   from the URL → `GDRIVE_FOLDER_ID`.
3. Discord → channel → Settings → Integrations → Webhooks → New Webhook → copy URL →
   `DISCORD_WEBHOOK_URL`.

The upload logic lives in [`../.github/scripts/upload_drive.sh`](../.github/scripts/upload_drive.sh)
(JWT auth → multipart upload → public link → Discord message). It accepts any `.apk` in the
artifact directory, so renaming the build output does not break it again.

## CI/CD

- **CI** (`.github/workflows/ci.yml`) — push/PR to `main`: `flutter analyze`, `flutter test`,
  debug APK build, artifact upload.
- **Release** (`.github/workflows/release.yml`) — tag `v*`: signed release APK, GitHub
  Release, optional Drive + Discord.
