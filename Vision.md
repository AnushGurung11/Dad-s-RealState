# Build Prompt — Rental Tracker (offline Flutter app)

Paste this whole prompt into your coding agent (Claude Code, etc.) as a single instruction.

---

Build a Flutter Android app called **"renttrack"** (or your chosen name) — an
offline rental/bed occupancy + payment tracker for a landlord who rents out
individual beds across multiple flats to working professionals.

**NO backend. 100% offline.** All data persisted to local JSON files in the
app's documents directory. This is an MVP — favor simplicity and correctness
over features.

## 1. Domain rules (encode these, they're the whole point of the app)

- A **Flat** has many **Beds**.
- A **Bed** belongs to exactly one Flat, and has **at most one active Tenant**
  at a time.
- A **Person** (tenant) can hold **at most one active Bed** at a time.
- A **PaymentRecord** belongs to one Person + Bed + Flat, for a given
  month/year, with `amountDue`, `amountPaid`, and a derived `status`
  (`paid` | `partial` | `unpaid`).
- Unassigning a tenant from a bed does not delete their payment history.

## 2. Project structure

```
app/
  pubspec.yaml            — deps: path_provider, package_info_plus, shared_preferences
                             dev_deps: flutter_test, integration_test, flutter_lints
                             No state-management package — StatefulWidget/setState only.
  lib/
    main.dart              — MaterialApp (Material 3), bottom NavigationBar shell,
                              IndexedStack tabs: Dashboard | Flats | Tenants | Payments.
                              Constructor-injectable JsonStore so widget tests can
                              pass a fake store.
    config.dart             — app name, JSON file names, schema version constant.
    models/
      flat.dart              — id, name, address, createdAt. fromJson/toJson.
      bed.dart                — id, flatId, label, monthlyRent, tenantId (nullable).
      person.dart              — id, name, phone, bedId (nullable), moveInDate.
      payment.dart              — id, personId, bedId, flatId, month (YYYY-MM),
                                    amountDue, amountPaid, status (computed getter).
      All plain Dart classes, ISO-8601 dates, double amounts, immutable with
      copyWith().
    services/
      json_store.dart          — storage core. Repository over dart:io +
                                   path_provider. Reads/writes flats.json, beds.json,
                                   people.json, payments.json to
                                   getApplicationDocumentsDirectory(). Atomic writes
                                   (write .tmp, then rename). Debounced save.
                                   schemaVersion field + migration hook. ALL reads/
                                   writes go through this one class — no screen
                                   touches files directly.
      assignment_service.dart   — pure logic: assignTenant(bedId, personId) throws
                                    if bed occupied or person already assigned
                                    elsewhere; unassignTenant(bedId) clears the link
                                    without touching payment history.
      payment_service.dart      — pure functions: duesForBed(), duesForFlat(),
                                    overdueTenants(), monthlyTotals(), markPaid(),
                                    markPartial(). No I/O — operate on in-memory
                                    lists, unit-testable with fixture data.
    screens/
      dashboard_screen.dart     — summary cards (total flats, total beds occupied/
                                    vacant, total overdue amount) + "who owes what"
                                    list, tap-through to a person's payment history.
      flats_screen.dart          — list of flats → tap into a flat to see/add/edit/
                                    delete its beds inline.
      tenants_screen.dart         — list of people, add/edit/delete, assign/
                                    unassign bed via a picker (only shows vacant
                                    beds).
      payments_screen.dart        — list filtered by month + status, mark paid/
                                    partial/unpaid, add a new payment record.
    widgets/                      — shared: StatusBadge (paid/partial/unpaid pill),
                                     EmptyState, ConfirmDeleteDialog, SummaryCard.
  test/
    unit/
      json_store_test.dart         — write→read round-trip, atomic write survives
                                       a simulated crash mid-write, schema migration
                                       hook fires on version mismatch.
      assignment_service_test.dart  — assign to vacant bed succeeds; assign to
                                        occupied bed throws; assign a person already
                                        assigned elsewhere throws; unassign clears
                                        bed.tenantId but leaves payments untouched.
      payment_service_test.dart      — duesForBed sums correctly; overdueTenants
                                         returns only unpaid/partial; markPaid sets
                                         status correctly; monthlyTotals sums across
                                         flats; empty-data edge cases return zero/
                                         empty, not null/crash.
    widget/
      dashboard_screen_test.dart      — renders summary cards from a fake store;
                                         shows empty state with zero flats.
      flats_screen_test.dart           — add/edit/delete a flat updates the list;
                                          add/delete a bed nested under a flat.
      tenants_screen_test.dart          — add a tenant; assign picker only lists
                                           vacant beds; assigning an occupied bed
                                           is disabled/hidden, not just rejected
                                           silently.
      payments_screen_test.dart          — filter by month/status; marking a
                                            record paid updates its badge
                                            immediately.
    integration_test/
      full_flow_test.dart                 — boot app → add flat → add bed → add
                                              tenant → assign bed → add payment →
                                              mark paid → verify dashboard reflects
                                              it, all against a temp directory.

  .github/workflows/
    ci.yml       — on push/PR to main: checkout, subosito/flutter-action (pin
                    version, cache: true), flutter pub get, flutter analyze,
                    flutter test, flutter build apk --debug, upload-artifact.
    release.yml  — on push of tag v* (+ manual dispatch with version input):
                    write signing keystore from ANDROID_KEYSTORE_BASE64 secret,
                    extract version+code from pubspec.yaml, flutter build apk
                    --release, rename to renttrack-<name>+<code>.apk, publish
                    GitHub Release via softprops/action-gh-release@v2
                    (generate_release_notes: true). Secrets referenced only via
                    job-level env vars, never directly in `if:` conditions.

REQUIRED GITHUB SECRETS: ANDROID_KEYSTORE_BASE64, ANDROID_STORE_PASSWORD,
ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS.
```

## 3. UI / UX requirements (clean, minimal, MVP-appropriate)

- Material 3, light + dark theme support, one accent color used consistently
  for primary actions (add/save buttons, status "paid" badge).
- Bottom nav with 4 tabs, each with a clear icon + label. Dashboard is the
  default landing tab.
- Every list screen has an empty state (icon + one-line message + primary
  "Add ___" button) — never show a bare blank screen.
- Status is always shown as a colored pill/badge, not just text: green =
  paid, amber = partial, red = unpaid/overdue.
- Forms (add flat/bed/tenant/payment) are single-screen modals or bottom
  sheets, not multi-step wizards — this is an MVP, keep data entry to one
  screen per entity.
- Destructive actions (delete flat/bed/tenant) always go through a confirm
  dialog naming what will be affected (e.g. "This flat has 3 beds and 2
  active tenants — delete anyway?").
- No loading spinners for local JSON reads (should be near-instant) — but
  guard every store read/write with try/catch and show a plain error
  snackbar on failure, never a silent crash.

## 4. SDLC process to follow while building

1. **Models** — write all 4 models + fromJson/toJson, no logic.
2. **json_store.dart** + its unit tests — get storage rock-solid before
   anything depends on it.
3. **assignment_service.dart** + **payment_service.dart** + their unit tests
   — pure logic, test against fixtures, no UI yet.
4. Wire up `ci.yml` at this point — every following change is now tested
   automatically on push.
5. **Screens**, one at a time, each with its widget tests, in this order:
   Flats → Tenants → Payments → Dashboard (dashboard last since it reads
   from all the others).
6. **integration_test** for the full flow once all screens exist.
7. `release.yml` + signed build once the MVP flow passes end-to-end.

## 5. README.md must document

- Local run instructions (`flutter run`).
- Where data is stored on-device and how to back it up/inspect it manually.
- Version bump + tag release process (bump pubspec, tag `vX.Y.Z`, push).
- GitHub secrets setup for signing.
- `.gitignore`: `build/`, `.dart_tool/`, `key.properties`, `release.keystore`.

## 6. Explicitly do NOT add

Backend, login/auth, Firebase, SQL/NoSQL database, cloud sync, any package
not listed above — without asking first. This is a local-only MVP.