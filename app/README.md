# renttrack

Offline rental/bed-occupancy + payment tracker for landlords who rent out
individual beds across multiple flats to working professionals.

**100% offline. No backend.** All data is persisted to local JSON files in the
app's documents directory.

## Domain rules

- A **Flat** has many **Beds**.
- A **Bed** belongs to one Flat and has at most one active Tenant at a time.
- A **Person** (tenant) can hold at most one active Bed at a time.
- A **PaymentRecord** belongs to one Person + Bed + Flat for a given month/year,
  with `amountDue`, `amountPaid` and a derived `status`
  (`paid` | `partial` | `unpaid`).
- Unassigning a tenant from a bed never deletes their payment history.

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

Data is stored as four JSON files in the app's **documents directory** on the
device (plus `schema.json` holding the schema version):

| File | Contents |
|------|----------|
| `flats.json` | Flats |
| `beds.json` | Beds |
| `people.json` | Tenants |
| `payments.json` | Payment records |

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
  models/                   flat, bed, person, payment (plain immutable classes)
  services/
    json_store.dart         Storage core: atomic writes, debounced saves, migration hook
    assignment_service.dart Pure bed<->tenant assignment rules
    payment_service.dart    Pure payment math (dues, totals, overdue, mark paid/partial/unpaid)
  screens/                  Dashboard, Flats, Tenants, Payments (+ flat detail, person history)
  widgets/                  StatusBadge, EmptyState, ConfirmDeleteDialog, SummaryCard
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