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
- **Assigning** a person to a bed requires a **deposit** (any positive amount).
- At assignment the app captures `joinDate` and `plannedStayMonths` and
  auto-computes `leaveDate = joinDate + plannedStayMonths`. `leaveDate` is
  editable afterwards to reflect the actual move-out date.
- **Tenure balance** per person:
  `totalRentOwed = monthlyRent × plannedStayMonths`
  `remainingBalance = totalRentOwed − deposit − sum(rent payments)`
  Both recalculate when the planned stay or leave date changes.
- **Deposit counts as income** at the moment it is collected — the deposit is
  recorded in the payments ledger (type `deposit`) while also reducing the
  tenant's remaining balance.
- **Unassigning** a person (move-out) clears the bed link but keeps the person
  and their full payment/deposit history.
- **Financial report per flat, for a period (month):**
  `income = rent payments + deposits collected in the period`
  `expenses = expense records in the period`
  `net = income − expenses` (may be negative; shown as a plain signed number
  like `Rs. -2,400`).

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

Data is stored as five JSON files in the app's **documents directory** on the
device (plus `schema.json` holding the schema version):

| File | Contents |
|------|----------|
| `flats.json` | Flats |
| `beds.json` | Beds |
| `people.json` | Tenants (incl. join/leave dates, planned stay, deposit) |
| `payments.json` | Rent + deposit payment records |
| `expenses.json` | Expense records per flat |

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

## Project structure

```
lib/
  main.dart                 Material 3 app shell, bottom NavigationBar, IndexedStack tabs
  config.dart               App name, JSON file names, schema version
  models/                   flat, bed, person, payment, expense (plain immutable classes)
  services/
    json_store.dart         Storage core: atomic writes, debounced saves, migration hook
    bed_capacity_service.dart  Pure 5–20 beds rule (create/add/delete)
    assignment_service.dart    Pure bed<->tenant assignment rules + deposit capture
    tenure_service.dart        Pure tenure math (totalRentOwed, remainingBalance)
    payment_service.dart       Pure payment math (dues, totals, overdue, mark paid/partial/unpaid)
    report_service.dart        Pure per-flat income/expenses/net + dashboard totals
  screens/                  Dashboard, Flats, Tenants, Reports (+ flat detail, person history)
  widgets/                  StatusBadge, NetAmountLabel, BedCapacityHint, EmptyState,
                            ConfirmDeleteDialog, SummaryCard
test/
  unit/                     Store + service tests with fixtures
  widget/                   Per-screen widget tests with an in-memory fake store
integration_test/
  full_flow_test.dart       End-to-end flow against a temp directory
```

## CI/CD

- **CI** (`.github/workflows/ci.yml`) — on push/PR to `main`: `flutter analyze`,
  `flutter test`, debug APK build, artifact upload.
- **Release** (`.github/workflows/release.yml`) — on tag `v*`: signed release
  APK + GitHub Release.