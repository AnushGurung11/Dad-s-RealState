# renttrack

Offline rental/bed-occupancy + financial tracker for landlords who rent out
individual beds across multiple flats to working professionals.

**100% offline. No backend.** All data is persisted to local JSON files in the
app's documents directory.

## Domain rules

- A **Flat** must have **between 5 and 20 Beds**, always. The app enforces this
  at creation (the form asks for the bed count and rejects anything outside
  5–20) and during management (add bed is blocked at 20, delete bed is blocked
  at 5, with an on-screen explanation).
- A **Bed** belongs to one Flat and holds at most one active Person.
- A **Person** can hold at most one active Bed at a time.
- **Assigning** a person to a bed happens in one step from the bed: tap a
  vacant bed and fill the assign form (name, contact/workplace, others, join
  date, planned stay, monthly rent — pre-filled from the bed's default rent —
  and deposit). One save creates the person and assigns them atomically.
- At assignment the app captures `joinDate` and `plannedStayMonths` and
  auto-computes `vacatedDate = joinDate + plannedStayMonths`. `vacatedDate` is
  editable afterwards to reflect the actual move-out date.
- **Tenure balance** per person:
  `totalRentOwed = monthlyRent × plannedStayMonths`
  `remainingBalance = totalRentOwed − deposit − sum(rent payments)`
  Both recalculate when the planned stay or the vacated date changes.
- **Deposit counts as income** at the moment it is collected — the deposit is
  recorded in the payments ledger (type `deposit`) while also reducing the
  tenant's remaining balance.
- **Unassigning** a person (move-out) clears the bed link but keeps the person
  and their full payment/deposit history.
- **Financial report per flat, for a period (month):**
  `income = rent payments + deposits collected in the period`
  `expenses = expense records in the period`
  `net = income − expenses` (may be negative; shown as a plain signed number
  like `AED -2,400`).
- **All amounts are in AED**, centralized in `lib/config.dart` (`currencySymbol`)
  so no screen hardcodes a currency.
- **Lease cheques**: every flat has a recurring cheque to its owner. Each flat
  gets a `LeaseChequeSetting` on creation (due 2 months out, amount 0, owner
  blank). Entering a flat's **yearly rent** auto-fills the cheque amount as
  `yearlyRent ÷ 6`. Marking a cheque **paid** on the Dashboard archives an
  immutable `LeaseChequeRecord` (queryable by month) and advances the next due
  date by the interval (default 2 months). A local notification fires 3 days
  before the due date at 09:00 when notifications are enabled, and reschedules
  automatically when the due date changes. A flat's current cheque and cheque
  payment history are shown under its **Lease info** tab.

## Run locally

```sh
cd app
flutter pub get
flutter run          # requires a connected Android device or emulator
```

Run all checks locally:

```sh
flutter analyze
flutter test
```

## Where data lives & how to back it up

Data is stored as seven JSON files in the app's **documents directory** on the
device (plus `schema.json` holding the schema version):

| File | Contents |
|------|----------|
| `flats.json` | Flats (incl. contract date/person, yearly rent) |
| `beds.json` | Beds (incl. default monthly rent) |
| `people.json` | Tenants (incl. join/vacated dates, planned stay, monthly rent, deposit, notes) |
| `payments.json` | Rent + deposit payment records |
| `expenses.json` | Expense records per flat |
| `lease_check_settings.json` | Per-flat lease cheque config (owner, amount, next due date, interval, notify) — on-disk name kept for data compatibility |
| `lease_check_records.json` | Immutable archive of cheques marked paid (by month/flat) |

To back up or inspect data manually, copy the app's documents directory off the
device, e.g.:

```sh
adb shell run-as com.renttrack.renttrack ls files
adb exec-out run-as com.renttrack.renttrack cat files/flats.json > flats.json
```

Writes are atomic (`*.json.tmp` + rename) and debounced, so it is safe to copy
the files at any time. A leftover `.tmp` file from a crash mid-write never
corrupts the real data.

## Release process

1. Bump the version in `app/pubspec.yaml`, e.g. `version: 1.2.0+5`.
2. Commit and push:
   ```sh
   git add app/pubspec.yaml
   git commit -m "release: v1.2.0"
   git push
   ```
3. Tag and push:
   ```sh
   git tag v1.2.0
   git push origin v1.2.0
   ```
   The `Release` workflow builds a signed APK, renames it to
   `renttrack-<version>+<code>.apk` and publishes a GitHub Release with auto
   generated release notes. A manual run with a version override is also
   available under **Actions → Release → Run workflow**.

## GitHub secrets for signing

The release workflow needs four repository secrets:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the signing keystore: `base64 -w 0 release.keystore` |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias |

Secrets are only ever referenced through job-level environment variables, never
directly in `if:` conditions.

To sign locally instead, create `app/android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=release.keystore
```

and place `release.keystore` in `app/android/`.

## Automatic Drive upload + Discord notification (optional)

After each release the `upload` job (`release.yml`) uploads the built APK to a
Google Drive folder with a public link and posts that link to a Discord
channel. Configure three more secrets (the job is skipped until
`GDRIVE_SERVICE_ACCOUNT_JSON` and `GDRIVE_FOLDER_ID` are set):

| Secret | Value |
|--------|-------|
| `GDRIVE_SERVICE_ACCOUNT_JSON` | Google Cloud service-account JSON key (raw or base64) with the **Drive API** enabled |
| `GDRIVE_FOLDER_ID` | ID of a Drive folder **shared with the service account email** (Editor) |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL; omit to skip Discord messages |

Steps once:

1. Create a service account in Google Cloud (`console.cloud.google.com` →
   IAM → Service accounts), enable **Google Drive API** for the project, and
   download its JSON key → `GDRIVE_SERVICE_ACCOUNT_JSON`.
2. In your Drive, create a folder, share it with the service account email
   (Editor), and copy the folder ID from the URL → `GDRIVE_FOLDER_ID`.
3. In Discord, open your server → channel → **Settings → Integrations →
   Webhooks → New Webhook** → copy the URL → `DISCORD_WEBHOOK_URL`.

The upload logic lives in `.github/scripts/upload_drive.sh` (JWT auth →
multipart upload → "anyone with link" permission → Discord message).

## Project structure

```
lib/
  main.dart                 Material 3 app shell, bottom NavigationBar, IndexedStack tabs
  config.dart               App name, JSON file names, schema version
  models/                   flat, bed, person, payment, expense, lease cheque
                            setting/record (plain immutable classes)
  services/
    json_store.dart         Storage core: atomic writes, debounced saves, migration hook
    bed_capacity_service.dart  Pure 5–20 beds rule (create/add/delete)
    assignment_service.dart    Pure bed<->tenant assignment rules + deposit capture
    tenure_service.dart        Pure tenure math (totalRentOwed, remainingBalance)
    payment_service.dart       Pure payment math (dues, totals, overdue, mark paid/partial/unpaid)
    report_service.dart        Pure per-flat income/expenses/net + dashboard totals
    cheque_service.dart        Pure lease-cheque math (due months, mark paid)
    notification_service.dart  Local reminder scheduling (3 days before due)
  screens/                  Dashboard, Flats, Tenants, Lease Setup, Reports
                            (+ flat detail with Beds/Lease info tabs, assign form,
                            person history)
  widgets/                  StatusBadge, NetAmountLabel, BedCapacityHint, EmptyState,
                            ConfirmDeleteDialog, SummaryCard, ChequeEditor
test/
  unit/                     Store + service tests with fixtures
  widget/                   Per-screen widget tests with an in-memory fake store
                            (incl. assign-from-bed flow)
integration_test/
  full_flow_test.dart       End-to-end flow against a temp directory
  cheques_flow_test.dart    Lease-cheque flow against a temp directory
```

## CI/CD

- **CI** (`.github/workflows/ci.yml`) — on push/PR to `main`: `flutter analyze`,
  `flutter test`, debug APK build, artifact upload.
- **Release** (`.github/workflows/release.yml`) — on tag `v*`: signed release
  APK + GitHub Release.