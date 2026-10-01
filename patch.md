# LUCKY — Complete Project Specification & Rebuild Guide

> **Purpose of this document.** This is the authoritative, self-contained
> specification for the LUCKY rental/bed-occupancy/finance tracker. It is
> written so that the entire application could be recreated from scratch using
> only this file: every entity, every field, every calculation, every business
> rule, every screen, every UI decision and every release step is described.
>
> **Status:** v2.1.0 (`version: 2.1.0+21`) — month history is now reachable
> from every financial screen, and paid lease cheques are bucketed by the month
> they were **paid** rather than the month they were **due**.

---

## Table of contents

1. [Product overview](#1-product-overview)
2. [Non-goals and hard constraints](#2-non-goals-and-hard-constraints)
3. [Tech stack, toolchain and repo layout](#3-tech-stack-toolchain-and-repo-layout)
4. [Architecture](#4-architecture)
5. [Navigation model](#5-navigation-model)
6. [Data model — entities and JSON schemas](#6-data-model--entities-and-json-schemas)
7. [Persistence layer](#7-persistence-layer)
8. [Business logic and calculations](#8-business-logic-and-calculations)
9. [The month-selection system (v2.1.0)](#9-the-month-selection-system-v210)
10. [Screen-by-screen specification](#10-screen-by-screen-specification)
11. [UI conventions and theming](#11-ui-conventions-and-theming)
12. [Sample data](#12-sample-data)
13. [Backup, restore and Excel export](#13-backup-restore-and-excel-export)
14. [Testing](#14-testing)
15. [Release process](#15-release-process)
16. [Data safety: how upgrades preserve user data](#16-data-safety-how-upgrades-preserve-user-data)
17. [Known issues and historical notes](#17-known-issues-and-historical-notes)

---

## 1. Product overview

**LUCKY** is a fully **offline**, single-user Flutter app for a landlord who
runs a small residential rental portfolio (flats divided into beds/rooms) and
needs to know, per month, who paid, what it cost, and what the properties net.

### Core capabilities

| Area | What it does |
| --- | --- |
| **Flats** | Register properties, lease terms (landlord, yearly rent, payment frequency), contact/Wi-Fi details, and beds inside each flat. |
| **Beds** | Each bed is a rentable unit with a default monthly rent and an optional occupying tenant. |
| **Tenants** | Assign a person to a bed with join date, planned stay length, deposit and their own rent. Track renewals, early termination, absconding and auto-archival. |
| **Income** | Record tenant rent (including multi-month prepayments) and landlord-to-tenant lease cheque receipts, in one ledger. |
| **Expenses** | Categorised per-flat expenses (electricity, water, gas, internet, maintenance, …) with date, amount, note and payment method. |
| **Reporting** | Month-scoped profit, trailing-12-month trends, yearly rollups, per-flat breakdowns, outstanding dues and a merged transaction ledger. |
| **Data safety** | In-app zip backup, validated restore, one-way Excel export, and direct access to the on-device data folder. |

### Design philosophy

- **Ledger-first.** Rent and deposits are rows in one `payments` ledger
  distinguished by `type`; there is no separate "rent table".
- **Never store a derived number that can drift.** Balances, profit and
  expense totals are recomputed from records on read (see §8). The only
  persisted derived value is the lease-cheque month bucket, and even that is
  re-derived on load.
- **History is never destroyed by lifecycle events.** Archiving, terminating
  or absconding a tenant changes status flags and frees the bed; it never
  deletes or edits a payment record.
- **Financial deletion is history-aware.** A flat with financial history can
  only be archived, never hard-deleted (§8.6).

---

## 2. Non-goals and hard constraints

- **No backend, no accounts, no sync, no analytics.** Everything is local.
- **No network permission required for core use.** Excel/zip output uses the
  OS share/save sheet.
- **Currency is single-sourced.** All amounts are formatted through
  `AppConfig.currencySymbol` (`AED`); no screen may hardcode a currency string.
- **Records are append-only where money is concerned.** `Payment` rows are
  never mutated by termination; refunds are stored on a separate record.
- **Testability.** All money/date math lives in `abstract final class` /
  `static`-only services with no I/O, so it is unit-testable with fixtures.

---

## 3. Tech stack, toolchain and repo layout

### Stack

- **Flutter** / **Dart** `^3.12.2`, Material 3.
- **State management:** plain `ChangeNotifier` + `InheritedNotifier` + a
  singleton `JsonStore`. No external state package.
- **Persistence:** plain JSON files via `dart:io` +
  `path_provider`. No SQLite/Drift/Hive.
- **Archive:** `archive` package for the backup zip.
- **Spreadsheet export:** `excel` package (write-only).
- **IDs:** time+random based (see §6.9).
- **Intl-free date formatting** in the app layer; `intl` is used only inside
  the Excel exporter for date cells.

### Commands

```powershell
# Flutter lives outside PATH in this environment
& "C:\src\Flutter\flutter\bin\flutter.bat" pub get
& "C:\src\Flutter\flutter\bin\flutter.bat" analyze
& "C:\src\Flutter\flutter\bin\flutter.bat" test
& "C:\src\Flutter\flutter\bin\flutter.bat" build apk --debug
```

`rg` is **not** available; use PowerShell `Select-String` or the grep tool.

### Repo layout

```
DadsRealState/                  <- git repo root, remote origin on GitHub
├── .github/workflows/
│   ├── ci.yml                  <- analyze + test + debug APK on PR/push
│   └── release.yml             <- tag-triggered signed release
├── patch.md                    <- this document
└── app/                        <- the Flutter project
    ├── pubspec.yaml            <- version: 2.1.0+21
    ├── android/
    │   ├── app/build.gradle.kts <- applicationId com.renttrack.renttrack
    │   └── key.properties      <- LOCAL ONLY, gitignored, often absent
    ├── lib/
    │   ├── main.dart           <- bootstrap, MonthScope, boot-time archive sweep
    │   ├── config.dart         <- app name, currency, filenames, monthKey()
    │   ├── models/             <- 10 plain data classes
    │   ├── services/           <- store, math, backup, export, demo data
    │   ├── screens/            <- 27 screens
    │   ├── widgets/            <- reusable UI pieces
    │   ├── navigation/         <- bottom nav + route name constants
    │   ├── theme/              <- light/dark themes, flat colour palette
    │   ├── icons/              <- custom IconData glyphs
    │   └── utils/              <- formatting, duration, ids
    ├── test/                   <- 64 test files, ~9,500 lines
    └── integration_test/
```

Scale: **88 `lib` files / ~17,230 lines**, **64 test files / ~9,500 lines**.

---

## 4. Architecture

```
runApp(LuckyApp)
 └── LuckyApp (StatefulWidget)
      ├── ChangeNotifierProvider-like: creates JsonStore + MonthSelection
      └── MaterialApp
           └── StoreScope          (InheritedNotifier<JsonStore>)
                └── MonthScope     (InheritedNotifier<MonthSelection>)   <-- mounted ABOVE Navigator
                     └── Navigator / bottom-nav shell
                          └── screens
                               ├── read JsonStore via StoreScope.of/maybeOf
                               └── read month via MonthScope.monthOf
```

Two inherited notifiers, both mounted **above** the `Navigator` so every route
and dialog sees the same instances.

### `StoreScope` (22 lines)

- `static JsonStore of(context)` — throws if unmounted.
- `static JsonStore? maybeOf(context)` — returns `null` if unmounted.
  **Used by widgets that can be pumped standalone in tests** (e.g. the month
  picker bar and flat pickers) so they degrade gracefully instead of throwing.

### `MonthScope` (see §9)

- `static MonthSelection? maybeOf(context)`
- `static String monthOf(context)` → selected month, or **current month** when
  unmounted, so widget tests that pump a screen alone keep working.

### Service layering

| Kind | Location | Rule |
| --- | --- | --- |
| **Pure math** | `report_service`, `expense_aggregation_service`, `tenure_service`, `termination_service` (calculation half), `archive_service`, `flat_deletion_service`, `cheque_service`, `assignment_service`, `bed_capacity_service` | `static`/`abstract final class`, zero I/O. |
| **Store-mutating** | `tenant_rent_payment_service`, `termination_service.terminate`, `absconded_service`, `renewal_service`, `payment_service`, `expense_service`, `transaction_edit_service`, `flat_creation_service`, `tenant_deletion_service` | Take a `JsonStore`, write through `upsert*`, wrap multi-record changes in `store.runBatched`. |
| **I/O / export** | `backup_service`, `excel_export_service`, `prefs`, `tenant_photo_picker` | File/network-free except zip + share. |

**Exceptions:** domain services raise dedicated exceptions
(`PaymentException`, `TerminationException`, `AbscondedException`,
`RenewalException`) that extend `Exception` and expose a `message` string, so
screens can show the exact reason in a snackbar.

---

## 5. Navigation model

### Bottom navigation — 5 tabs

| Index | Label | Route prefix |
| --- | --- | --- |
| 0 | **Overview** | `/` |
| 1 | **Flats** | `/flats` |
| 2 | **Tenants** | `/tenants` |
| 3 | **Finance** | `/finance`, `/payments`, `/history`, `/expenses`, `/report` |
| 4 | **More** | settings & archives |

`_indexFor(route)` maps a route back to a tab by prefix. If the resolved index
is `> 4` the shell falls back to `0` so the bar is never in an invalid state.

### The Finance tab is a hub, not a screen

`FinanceScreen` is a `DefaultTabController(length: 4)` with a scrollable
`TabBar` and a `TabBarView`:

1. **Cheque** → `ChequePaymentFlatScreen` (landlord → tenant lease cheques)
2. **Rent** → `TenantRentPaymentScreen` (tenant rent collection)
3. **Expenses** → `ExpensesScreen` (per-flat expense entry + category totals)
4. **History** → `PaymentHistoryScreen` (payment/expense browsing)

### Route name constants (`navigation/routes.dart`)

`dashboard /`, `flats`, `flatDetail`, `tenants`, `tenantsAdd`,
`tenantsAssign`, `tenantsDetail`, `tenantsEdit`, `tenantsTerminate`,
`payments`, `paymentsFlatLease`, `paymentsTenantRent`, `paymentHistory`,
`historyFlatLease`, `historyTenantRent`, `expenses`, `settings`,
`settingsArchive`, `archiveTenants`, `archiveFlats`, `financialReport`,
`finance`, `financialActivity`, `vacantBeds`.

> **Known wart:** `Routes.financialActivity` (`/financial-activity`) is
> pre-existing dead code — `FinancialActivityScreen` is reachable via a tab or
> in-app link, not via this named route. Left as-is to avoid churn.

---

## 6. Data model — entities and JSON schemas

Every model is an **immutable** class with `const` constructor, `copyWith`
(with explicit `clearX` booleans for nullable fields), `fromJson` and
`toJson`. Every on-disk file is `{"schemaVersion": 1, "items": [...]}`.

### 6.1 `Flat` (`flats.json`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | String | |
| `name` | String | |
| `address` | String | |
| `createdAt` | DateTime | |
| `registeredDate` | DateTime? | |
| `contractPerson` | String? | landlord/owner |
| `yearlyRent` | double? | landlord's rent **to the tenant** |
| `archived` | bool | **default false** |
| `archivedAt` | DateTime? | |
| `leasePaidThroughDate` | DateTime? | how far the lease is prepaid |
| `frequencyMonths` | int | cheque payment cadence (e.g. 6 = twice a year) |
| `landlineNumber`, `landlineRegisteredName`, `esewaNumber` | String? | utility contact details |
| `wifiName`, `wifiPassword` | String? | shown to tenants |

`archived` is a plain bool on `Flat` (distinct from `Person.status`).

### 6.2 `Bed` (`beds.json`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | String | |
| `flatId` | String | |
| `label` | String | e.g. "Bed 3" |
| `defaultMonthlyRent` | double | seeded into `Person.monthlyRent` on assign |
| `tenantId` | String? | `null` ⇒ vacant |

`bool get isOccupied => tenantId != null`.

### 6.3 `Person` (`people.json`)

The tenant record. Fields: `id`, `name`, `contact`, `workplaceOrInfo`,
`country`, `bedId`, `flatId`, `joinDate`, `plannedStayMonths`, `vacatedDate`,
`depositAmount`, `monthlyRent`, `others`, `renewalHistory` (`List<DateTime>`),
`status`, `photoPath`, `statusNote`, `statusDate`.

- **`flatId` is denormalized** onto the person at assign/unassign time so
  screens can group tenants by flat without joining through beds.
- **`vacatedDate`** is auto-computed at assignment as
  `joinDate + plannedStayMonths`, and is later editable to reflect reality.
- **`renewalHistory`** is the discriminator that separates "let the stay lapse"
  from "actively renewed" (§8.4).
- **`photoPath`** is a path *inside the app documents directory* (copied at pick
  time), never the OS picker's transient URI.

**`PersonStatus` enum:** `active`, `archived`, `absconded`.

```
bool get isActiveTenant => bedId != null && joinDate != null && plannedStayMonths != null;
bool get isArchived     => status != PersonStatus.active;
bool get isAbsconded    => status == PersonStatus.absconded;
```

**Legacy migration in `fromJson`:** older builds stored `archived: bool` +
`archivedAt`. `fromJson` prefers `status`, falls back to
`legacyArchived ? archived : active`, and reads `vacatedDate ?? leaveDate` and
`statusDate ?? archivedAt`. **Old installs load transparently.**

### 6.4 `Payment` (`payments.json`) — the single income ledger

| Field | Type | Notes |
| --- | --- | --- |
| `id` | String | |
| `personId`, `bedId`, `flatId` | String | denormalized for grouping |
| `month` | String | **`YYYY-MM`** — the bucket |
| `amountDue` | double | |
| `amountPaid` | double | |
| `type` | `PaymentType` | `rent` \| `deposit` |
| `description`, `paymentMethod` | String? | |

**`PaymentStatus` is derived, never stored:**

```
amountPaid <= 0        -> unpaid
amountPaid >= amountDue-> paid
otherwise              -> partial
```

Both types count as income; **only `rent` reduces the tenure balance.**

### 6.5 `Expense` (`expenses.json`)

`id`, `flatId`, `category` (`ExpenseCategory`), `amount`, `date`, `note`,
`description`, `paymentMethod`.

**`ExpenseCategory`:** `electricity`, `water`, `gas`, `internet`, `maintenance`
(plus further values in the enum, each with a human `label` getter).

Expenses are bucketed by **`monthKey(e.date)`** — the entry date, not the due
date.

### 6.6 `LeaseChequeSetting` (`lease_check_settings.json`)

Recurring landlord→tenant lease obligation: `flatId`, `amount`,
`nextDueDate`, `frequencyMonths`. The Dashboard "Next Lease Due" card picks the
earliest `nextDueDate` across active flats.

### 6.7 `LeaseChequeRecord` (`lease_check_records.json`) — **changed in v2.1.0**

| Field | Type | Notes |
| --- | --- | --- |
| `id`, `flatId`, `ownerName` | String | |
| `amount` | double | |
| `dueDate` | DateTime | the date the cheque was **due** |
| `paidDate` | DateTime | the date it was **paid** |
| `month` | String | `YYYY-MM` — **derived getter, not a constructor parameter** |
| `description`, `paymentMethod` | String? | |

**The v2.1.0 change.** Previously the month bucket was passed into the
constructor from the **due date**, so a cheque paid on 28 Sep for a 5 Oct due
date landed in **October** — making September look short and October look
inflated. Now:

```dart
String get month => monthKey(paidDate);
```

and `fromJson` simply **does not read the stored `month`** — it is re-derived
from `paidDate` on load. `toJson` still writes `month` for human readability and
for forward compatibility, with a comment saying so.

**This means existing installs self-repair with no migration step:** the stored
stale value is ignored on read and the corrected value is written on the next
save. This was verified on a real device — an injected old-format record with
`"month": "2026-10"` and `paidDate: 2026-09-28` was rewritten to
`"month": "2026-09"` and appeared in September's totals, while October's total
was unchanged.

### 6.8 `LeaseTerminationRecord` (`terminations.json`)

`id`, `personId`, `bedId`, `flatId`, `terminationDate`, `reason`
(`TerminationReason`: `financial`, `workplaceChange`, `roommateIssue`,
`facilityLacking`, `other`), `reasonNote`, `totalPaidAcrossPrepaidMonths`,
`daysStayedFinalMonth`, `earnedFinalMonth`, `refundAmount`.

Stores the **refund breakdown**; the original payments remain untouched.

### 6.9 `AuditLogEntry` (`audit_log.json`)

`id`, `action`, `entityType`, `entityId`, `summary`, `timestamp`. Appended on
mutations for traceability and included in backups.

### 6.10 IDs

`utils/ids.dart` — `newId()` from timestamp + randomness. Sortable by creation
time, which is why month lists can rely on lexicographic `YYYY-MM` ordering.

---

## 7. Persistence layer

### 7.1 Location

`LocalJsonStore` resolves `getApplicationDocumentsDirectory()` and stores under
a `LUCKY` subdirectory (`AppConfig.appName`):

```
/data/data/com.renttrack.renttrack/app_flutter/LUCKY/
├── schema.json              (meta: schemaVersion, lastBackup info)
├── flats.json
├── beds.json
├── people.json
├── payments.json
├── expenses.json
├── lease_check_settings.json
├── lease_check_records.json
├── terminations.json
└── audit_log.json
```

On Android this is **internal app storage**: private to the app, not visible in
the normal file manager, preserved across **app updates**, destroyed on
**uninstall**. See §16.

### 7.2 Write strategy

- **In-memory authoritative state.** `load()` reads everything once; getters
  return `List.unmodifiable` views.
- **Coalesced async saves.** `upsert*`/`delete*` mutate memory then call
  `_scheduleSave()` (debounced microtask), so a burst of edits coalesces into
  one write pass.
- **Atomic per-file writes.** `_atomicWrite` writes to a temp file then renames,
  so a crash mid-write cannot truncate a file.
- **`runBatched(action)`** bumps a `_batchDepth` counter, runs the action, and
  defers the save until the outermost batch completes. This is how
  multi-record operations (multi-month payment, termination, absconding,
  archive sweep) become **one** write instead of N.
- **`flush()`** forces pending writes — awaited before risky operations.
- **`onWriteError` hook** lets the UI surface persistence failures instead of
  failing silently.

### 7.3 Schema versioning

`AppConfig.schemaVersion = 1`. `schema.json` stores the version;
`JsonStore.migrate(fromVersion, toVersion)` is the hook for future upgrades.
Migration philosophy so far has been **tolerant `fromJson` repair over batch
migrations** (see the `Person` legacy fields and the lease `month`).

---

## 8. Business logic and calculations

All figures are `double`. All money funnels through `utils/format.dart`
(`formatMoney`, `formatMoneyShort`) and never a per-screen format string.

### 8.1 Month keys

`monthKey(DateTime)` → `'YYYY-MM'`, zero-padded. Because the format is
lexicographically ordered, sorting month keys as strings sorts chronologically —
used pervasively.

### 8.2 Expense aggregation — one source of truth

`ExpenseAggregationService` exists so Dashboard, Profit Overview and Financial
Report can never disagree:

```dart
totalExpensesForFlat(flatId, month, expenses, leaseChequeRecords)
  = Σ Expense.amount        where e.flatId == flatId && monthKey(e.date) == month
  + Σ LeaseChequeRecord.amount where r.flatId == flatId && r.month   == month

totalExpensesForMonth(month, expenses, leaseChequeRecords)
  = Σ Expense.amount        where monthKey(e.date) == month
  + Σ LeaseChequeRecord.amount where r.month == month
```

**Both categorised expenses *and* paid lease cheques are expenses.** (Rent from
tenants is income; the landlord's lease cheque to the tenant is an expense.)

### 8.3 Income and profit — `ReportService`

```dart
flatIncome(flatId, month)   = Σ Payment.amountPaid where flatId matches && month matches
flatExpenses(flatId, month) = ExpenseAggregationService.totalExpensesForFlat(...)
flatNet                      = flatIncome - flatExpenses        // may be negative
flatSummary                   = (income, expenses, net)

dashboardTotals(month)       = (Σ all payments in month,
                               totalExpensesForMonth,
                               income - expenses)

monthlyIncome(flatId)        = Map<YYYY-MM, double> rollup per month
trailing12Months(flatId?)    // 12 entries, oldest → newest, ending on `now`
yearlyTotals(year, flatId?)  // (income, expense, net, monthly[12])
```

Deposits **are** counted as income (`PaymentType.deposit`) wherever income is
summed.

### 8.4 Tenure — `TenureService`

```dart
computedLeaveDate(joinDate, plannedStayMonths)
    = DateTime(join.year, join.month + plannedStayMonths, join.day)
      // Dart normalises month overflow, so +13 months rolls the year correctly

effectiveStayMonths(person)
    planned = person.plannedStayMonths ?? 1
    leave   = person.vacatedDate ?? computedLeaveDate(join, planned)
    if leave == plannedLeave: return planned            // untouched plan
    months = (leave.year - join.year) * 12 + (leave.month - join.month)
    if leave.day > join.day: months += 1                // round up on partial month
    return max(months, 1)

totalRentOwed(person, monthlyRent) = monthlyRent * effectiveStayMonths(person)

remainingBalance(person, monthlyRent, payments)
    = totalRentOwed
    - (person.depositAmount ?? 0)
    - Σ Payment.amountPaid where personId matches && type == rent      // deposit does NOT reduce
```

**Balances are never stored** — they are recomputed from the ledger on every
read, so a corrected payment instantly fixes the balance everywhere.

### 8.5 Auto-archival — `ArchiveService`

A tenant is auto-archived when their stay **lapsed**:

```
shouldArchive(person, today):
  if person.vacatedDate == null or person.isArchived: false     // idempotent
  if !person.vacatedDate.isBefore(today):        false         // not yet due
  if person.renewalHistory.isEmpty:              true          // never renewed
  return person.renewalHistory.last.isBefore(person.vacatedDate)
                                                    // last renewal predates the leave date
```

Only the **most recent** renewal counts — a renewal from an earlier stay does
not rescue a later lapsed cycle.

`checkAndArchive(persons, beds, today)` returns new lists (inputs are not
mutated; untouched entries come back as the same instances), flipping matching
people to `archived` and clearing `tenantId` on their beds. The archived person
**keeps** `bedId`/`flatId` so the Archive screen can show the former flat/bed.

This sweep runs **once at boot** in `main.dart` and persists via
`JsonStore`. It never deletes records.

### 8.6 Lifecycle actions

**Renewal (`RenewalService.renew`)** — requires `isActiveTenant` and not
archived; rejects `< 1` month. Adds to `plannedStayMonths`, recomputes
`vacatedDate`, and **appends a timestamp to `renewalHistory`**.

**Early termination (`TerminationService`)** — prorated by days lived:

```
terminationMonth = monthKey(terminationDate)
prepaid = rent payments where p.month == terminationMonth OR p.month > terminationMonth
totalPaidAcrossPrepaidMonths = Σ prepaid.amountPaid
paidForFinalMonth           = Σ prepaid.where(month == terminationMonth).amountPaid
daysStayedFinalMonth        = terminationDate.day.clamp(1, daysInMonth)
earnedFinalMonth            = daysStayed / daysInMonth * monthlyRent
refundFinalMonth            = paidForFinalMonth - earnedFinalMonth   // NOT floored alone
refundFutureMonths          = Σ prepaid.where(month > terminationMonth).amountPaid  // 100% unearned
refundAmount                = max(refundFinalMonth + refundFutureMonths, 0)
```

The floor is applied **only to the total**, so an *underpaid* tenant owes
nothing — the flow returns overpayment, never bills for it.

`terminate()` (inside one `runBatched`):
1. writes the `LeaseTerminationRecord` (carrying the whole breakdown),
2. sets the person to `archived` with `statusDate = vacatedDate = date`,
3. clears `tenantId` on their bed.

**Payment records are byte-identical afterwards.** Throws if the reason is
`other` without a note, or if the tenant is not `active`.

**Absconding (`AbscondedService`)** — a manual "flag and move on" action,
*distinct* from lapse auto-archival and *distinct* from termination:

- requires a non-empty `statusNote` ("why/what happened"),
- refuses to re-process a non-active tenant (idempotency guard),
- sets `status = absconded`, `statusDate`, `statusNote`, frees the bed,
- **no refund is calculated** (that is the termination flow),
- preserves every payment.

**Flat deletion (`FlatDeletionService`)** — history decides:

```
hasFinancialHistory(flatId) = any Expense.flatId   == flatId
                           || any LeaseChequeRecord.flatId == flatId
                           || any Payment.flatId    == flatId

getOutstandingLeaseDue(flatId) = setting.amount when no LeaseChequeRecord matches
                                 setting.nextDueDate (y/m/d), else null

resolveDelete(flat, ...):
  hasHistory -> FlatDeleteDecision.archive[WithOutstandingDue]
  else       -> FlatDeleteDecision.hardDelete[WithOutstandingDue]
```

`FlatDeleteDecision` supplies plain-language confirm-dialog copy and an
outstanding-due warning. **A flat with any money attached can only be archived.**

### 8.7 Rent collection — `TenantRentPaymentService`

`payablePeople()` = tenants where `isActiveTenant && status == active`, sorted
by name.

`hasPaidForMonth(payments, personId, month)` drives the Paid/Unpaid badge:
true when any `rent` payment exists in that month with `amountPaid > 0`.

**Multi-month prepayment** (`planMonths` + `recordMultiMonthPayment`):

- month 0 → the **entered** `firstDate` and `firstAmount` (back-dating is allowed
  and the payment's `month` comes from that date),
- months 1..n-1 → the **1st of each following calendar month**, each defaulting
  to `person.monthlyRent` and **individually editable** via `futureAmounts`.

Validation: `monthsPaying >= 1`, `firstAmount > 0`, and every future month
`> 0`. All n records are written in **one `runBatched`** ⇒ one atomic store
write. `amountDue` is `firstAmountDue ?? monthlyRent` for month 0 and the
planned amount thereafter. Descriptions attach to month 0 only.

> **Deliberate design:** nothing is silently locked to the default rent — every
> future amount is previewed and editable before saving.

### 8.8 Lease cheques — `ChequeService` / flat lease payment

`frequencyMonths` on the flat plus `LeaseChequeSetting.nextDueDate` drive the
next due date; paying a cheque creates a `LeaseChequeRecord` whose `paidDate` is
what buckets it (§6.7). `flat_lease_payment_service.dart` covers the atomic
record + setting-advance behaviour.

### 8.9 Dashboard — `DashboardService.build`

Produces `DashboardSummary`:

- **flatsCount** = flats where `!archived`; **all other aggregation is
  restricted to those active flat ids** (beds, lease settings, people, payments,
  expenses). This is why archiving a flat removes it from the Dashboard.
- `bedsOccupied` / `bedsVacant` from active flats' beds by `tenantId != null`.
- `activePeople` = `isActiveTenant && status == active && flatId ∈ activeFlats`.
- `monthExpense` = Σ `totalExpensesForFlat` over active flats (includes lease
  cheques via the shared aggregator).
- `monthIncome` = Σ payments in month with type `rent` **or** `deposit`, in
  active flats.
- `monthProfit` = `monthIncome - monthExpense`.
- `paidThisMonthCount` = active tenants with a `rent` payment in the month.
- `nextLeasePayment` = active lease setting with the earliest `nextDueDate`.

### 8.10 Editing ledger rows — `TransactionEditService`

Edits/deletes of payments, expenses and cheque records so that derived totals
stay consistent, including when a record's **date/month is changed** (which
moves it between buckets). Audit entries are appended.

---

## 9. The month-selection system (v2.1.0)

### The bug this fixes

Every financial figure is bucketed by `YYYY-MM`, but there was **no way to
select which month you were looking at**. A user who scrolled past October
literally could not get back to September. Combined with the due-date-vs-paid-date
lease bug (§6.7), past months appeared to be missing entirely — it looked like
the data had been deleted. It had not.

### `MonthSelection` (`services/month_selection.dart`)

```dart
class MonthSelection extends ChangeNotifier {
  String get month;                 // 'YYYY-MM'
  bool   get isCurrentMonth;
  static String   label(String m);  // 'Sep 2026'
  static DateTime parse(String m);  // DateTime pinned to the 1st, never throws
  static String   normalize(String m);   // arbitrary input -> canonical 'YYYY-MM'
  void select(String m);            // no-op if unchanged
  void step(int delta);
  void previous();  void next();
  void reset();                      // back to the live month
  static List<String> monthsWithData(JsonStore store);  // newest first
}
```

Design decisions:

- **In memory only.** Every launch opens on the live calendar month rather than
  a stale one from a previous session — no persisted "last viewed month" to go
  wrong. `AppConfig.prefKeyCurrentMonth` exists but is not used for this.
- **`parse` never throws.** Malformed input falls back to the current month, so
  a corrupt value can never crash a screen.
- **`step` uses `DateTime(y, m + delta, 1)`**, so month arithmetic rolls the
  year correctly (Jan − 1 ⇒ Dec of the previous year).
- **`monthsWithData`** unions the months of all payments, all expenses and all
  lease-cheque records, **always includes the current month**, dedupes, and sorts
  descending. This powers the jump menu so nobody has to step backwards one
  month at a time hunting for old data.

### `MonthScope`

`InheritedNotifier<MonthSelection>` mounted in `main.dart` **above the
`Navigator`**, mirroring `StoreScope`:

```dart
static MonthSelection? maybeOf(BuildContext c);
static String monthOf(BuildContext c) => maybeOf(c)?.month ?? monthKey(DateTime.now());
```

The fallback in `monthOf` is what keeps standalone widget tests working — a
screen pumped without a `MonthScope` renders the current month instead of
throwing.

### `MonthPickerBar` (153 lines)

The reusable control, pinned under the app bar on month-scoped screens:

- `‹  Sep 2026  ›` with semantic labels **"Previous month"** / **"Next month"**
  (these labels are asserted by tests and drive the device-verification script),
- a **"Jump to month"** popup menu listing `monthsWithData`, and
- **"This month"**, disabled/highlighted when already on the live month.

It tolerates a missing store by using `StoreScope.maybeOf` and hiding
month-scoped affordances.

### Which screens are month-scoped

| Screen | Behaviour |
| --- | --- |
| Dashboard (Overview) | Profit, expenses, paid count, next-lease card all for the selected month. |
| Profit Overview | Income/expense split and per-flat breakdown for the selected month. |
| Financial Activity | Summary + income/expense sections for the month; the "all transactions" ledger stays **all-time by design**. |
| Financial Report | Monthly view follows the selection; yearly view is driven by its own year picker. |
| Tenants | Paid/Unpaid badges per month. |

> **Intentional non-scoping:** the "Recent Transactions" list on the Dashboard
> and the "All Transactions" ledger in Financial Activity intentionally span
> **all** months — they are activity feeds, not month reports. Only the summary
> cards are month-scoped. Changing this is a future decision, not a bug.

---

## 10. Screen-by-screen specification

27 screens. Each entry: purpose, key UI, rules it enforces.

### Overview

- **`dashboard_screen.dart` (652)** — Flats count · Occupancy (`9/13`, `9
  occupied / 4 vacant`) · **NET PROFIT** + `Total Expenses:` sub-label ·
  **Outstanding** ("N tenants unpaid for <Month Year>") · **Next Lease Due** with
  days remaining. Month-scoped. Below: "Recent Transactions" feed (all-time).
- **`financial_activity_screen.dart` (223)** — month summary plus
  income/expense sections and the all-time ledger.
- **`profit_overview_screen.dart` (490)** — month income vs expenses and
  per-flat breakdown, month-scoped.

### Flats

- **`flats_screen.dart` (1101)** — list of active flats with rent/occupancy
  chips; add flat; archive entry point; per-flat capacity hints.
- **`flat_detail_screen.dart` (438)** — lease terms, contact/Wi-Fi details, bed
  list, per-flat finances, delete/archive action driven by
  `FlatDeletionService`.
- **`assign_screen.dart` (561)** — bed assignment: pick tenant, join date,
  planned stay, deposit, rent (defaults from `Bed.defaultMonthlyRent`), photo.
  Runs `AssignmentService`, sets `joinDate`/`vacatedDate`/`flatId`, creates the
  deposit row when applicable.
- **`flat_lease_payment_screen.dart` (233)** — record a lease cheque for a flat,
  advance `nextDueDate` by `frequencyMonths`.
- **`flat_lease_history_screen.dart` (89)** — that flat's cheque history.
- **`archive_flats_screen.dart` (288)** — archived flats, restorable.
- **`vacant_beds_screen.dart` (81)** — every vacant bed across active flats.

### Tenants

- **`tenants_screen.dart` (384)** — active tenants; **month-scoped Paid/Unpaid
  badges**; grouped by flat.
- **`add_tenant_screen.dart` (209)** / **`edit_tenant_screen.dart` (272)** —
  create/edit details and photo.
- **`person_detail_screen.dart` (501)** — tenure, balance (recomputed),
  deposit, renewal history, payments, and the lifecycle actions (renew,
  terminate, abscond).
- **`tenant_rent_payment_screen.dart` (327)** — record rent; multi-month
  prepayment with the editable per-month plan preview (§8.7).
- **`tenant_rent_history_screen.dart` (216)** — that tenant's rent ledger.
- **`termination_flow_screen.dart` (226)** — early-termination wizard showing
  the live prorated breakdown (§8.6) before confirming.
- **`archive_tenants_screen.dart` (172)** — archived **and** absconded tenants
  with their badges/notes.

### Finance

- **`finance_screen.dart` (48)** — 4-tab hub (§5).
- **`cheque_payment_flat_screen.dart` (861)** — per-flat lease cheque status,
  payment, history.
- **`expenses_screen.dart` (633)** — add/edit/delete expenses, category totals
  per flat, includes **all** flats (active *and* archived) so historical
  expenses remain editable.
- **`payment_history_screen.dart` (87)** / **`payments_screen.dart` (89)** —
  browsing and filtering.
- **`financial_report_screen.dart` (568)** — monthly and yearly reports, per
  flat or all flats, using `ReportService`.

### Settings

- **`settings_screen.dart` (676)** — Archived Tenants · Archived Flats ·
  **Create backup** · **Restore from backup** (marked destructive) · **Export
  to Excel** (one-way, 7 sheets) · **Open data folder** · **Load sample data**
  · **Reset all data** (red, permanent). Busy states per action. After a
  backup the user chooses **Save to device** or **Share**.

---

## 11. UI conventions and theming

- **Material 3**, light + dark themes in `theme/app_theme.dart` (338 lines),
  switched by `ThemeController`. The system bar colour follows the scaffold
  background.
- **`FlatColor` palette** (`theme/flat_color.dart`) — deterministic per-flat
  accent so a flat keeps the same colour everywhere.
- **`AppIcons`** — custom `IconData` glyphs so the app does not depend on the
  Material icon set.
- **Money:** `formatMoney` / `formatMoneyShort` + `AppConfig.currencySymbol`.
  Negative net profit renders in the error colour.
- **Duration:** `utils/duration_format.dart` renders remaining stay as
  `"5 months 14 days"`.
- **StatusBadge** (paid/partial/unpaid, active/archived/absconded) and
  **SummaryCard** are shared; **PersonAvatar** falls back to initials.
- **EmptyState** for empty lists; **ScreenCaption** for section subtitles.
- **Accessories:** `BedCapacityHint`, `ConfirmDeleteDialog`, `GroupedTenantList`,
  `TenantPickerList`, `ChequeEditor`, `LuckyWordmark`, `NetAmountLabel`.
- **Accessibility:** every icon-only control carries a semantics label (e.g.
  `"Previous month"`), which the tests and the device verification rely on.

---

## 12. Sample data

`services/demo_data_service.dart` (497 lines), exposed as **Settings → Load
sample data**.

Contents: **3 flats**, **13 beds**, tenants across **3 months** (Aug/Sep/Oct of
the current year, relative to today), rent + deposit payments, categorised
expenses, lease cheque records, one **partial** payment, and one **archived**
tenant — enough to prove every month shows distinct figures.

**Guardrail:** the action **refuses to seed when the store already holds data**
(flats, people or payments present) so it can never contaminate a real
portfolio. It reports why instead of silently doing nothing.

> **Lesson recorded:** the first dataset produced past-dated lease settings
> during live emulator testing, which was corrected by deriving future due
> dates from `DateTime.now()` rather than hardcoding. Sample data must always
> be generated relative to the current date.

---

## 13. Backup, restore and Excel export

### `BackupService` (534 lines)

- **`createBackup()` → `File`** — writes all nine JSON files **plus tenant
  photos** into a zip in a temp location, then the caller offers *Save to
  device* or *Share*.
- **`validateBackup(zip) → `RestoreValidation``** — checks the archive opens,
  the meta file is present and the version is compatible **before** any
  destructive step; failures surface as an "Invalid Backup" dialog.
- **`restoreBackup(zip)`** — replaces the dataset atomically
  (`_atomicReplaceAll`), so a failed restore cannot leave a half-written store.
- **`BackupData.fromJson`** shapes the embedded manifest.

### `ExcelExportService` (522 lines)

**One-way, 7 sheets**, for viewing only — there is no re-import path. Sheets
cover flats, beds, people, payments, expenses, lease cheques and terminations.

### "Open data folder"

Opens the `LUCKY` documents directory in the OS file manager so the raw JSON
can be copied to a PC or cloud drive.

> On Android this path is internal app storage, so most file managers will not
> show it. **The zip backup is the portable, user-facing mechanism**; use that
> for moving data between devices.

---

## 14. Testing

**349 tests passing.** Structure:

| Layer | Location | Style |
| --- | --- | --- |
| Models / JSON round-trip & legacy repair | `test/unit/` | fixtures |
| Pure math services | `test/unit/` | table + edge cases |
| Services with a fake store | `test/unit/` | `InMemoryJsonStore` |
| Screens / navigation / month pickers | `test/widget/` | `pumpWidget`, semantics |
| End-to-end month flow | `test/integration_test/month_rollover_flow_test.dart` | `flutter test integration_test` |

v2.1.0 additions: `month_selection_test.dart` (19) · demo-data tests (16) ·
month-picker and navigation widget tests (7) · month rollover integration (4).

### Commands

```powershell
& "C:\src\Flutter\flutter\bin\flutter.bat" test                                  # 349 pass
& "C:\src\Flutter\flutter\bin\flutter.bat" test test/unit/month_selection_test.dart
& "C:\src\Flutter\flutter\bin\flutter.bat" test test/integration_test
```

### Lint baseline

`flutter analyze` reports **no errors**. Five pre-existing infos/warnings remain
(two `value:`→`initialValue:` deprecations and a `prefer_spread_collections`
hint in `cheque_payment_flat_screen.dart`, an unused local in
`person_detail_screen.dart`, and a needless string interpolation in
`profit_overview_screen.dart`). None are introduced by v2.1.0; they are tracked,
not blocking.

### Device verification

Beyond the automated suite, changes are verified on `Medium_Phone_API_36`
(`emulator-5554`) with `com.renttrack.renttrack` installed, driving the UI via
an accessibility-label script in the temp directory. For v2.1.0 this confirmed
distinct per-month totals, the jump menu, "This month", month-scoped tenant
badges, future-dated lease settings, and the old-format lease record repair.

---

## 15. Release process

### Versioning

`pubspec.yaml` is the single source of truth:

```yaml
version: 2.1.0+21     # name+build  ->  Android versionName 2.1.0 / versionCode 21
```

- `versionName` is the human label, `versionCode` the Android monotonic integer.
- **Bumping only the Git tag is a bug** — `release.yml` extracts the version
  from `pubspec.yaml` to name the artifact, so the two must agree.
- Tags historically reached `v2.0.1` while pubspec still said `1.14.3+20`
  (released APKs were all "1.14.3+20"). v2.1.0 fixes this inconsistency.

### GitHub Actions

**`ci.yml`** — on push/PR: `flutter pub get` → `analyze` → `test` → debug APK.

**`release.yml`** — triggered by **pushing a `v*` tag**:

1. checks out the tag,
2. reconstructs the **release keystore** from repository **secrets** and writes
   `android/key.properties`,
3. reads the version from `pubspec.yaml`,
4. builds the **signed release APK**,
5. publishes a **GitHub Release** with the APK attached,
6. (fan-out) uploads the APK to Drive and announces it on Discord.

**Because the workflow is tag-triggered and self-sufficient, pushing the tag is
all that is needed — the GitHub CLI is not required.**

### Steps to cut a release

```powershell
# 1. bump pubspec.yaml
# 2. verify
& "C:\src\Flutter\flutter\bin\flutter.bat" pub get
& "C:\src\Flutter\flutter\bin\flutter.bat" analyze
& "C:\src\Flutter\flutter\bin\flutter.bat" test
# 3. commit + tag + push (the push is what triggers the release)
git add -A
git commit -m "..."
git tag -a v2.1.0 -m "v2.1.0 - month history + paid-month lease cheques"
git push origin main
git push origin v2.1.0
```

### Signing rules

- `android/key.properties` and `*.jks` are **gitignored**; the local copy is
  often absent, and `build.gradle.kts` then falls back to the **debug key**.
- A debug-key APK **cannot update** a production installation — Android rejects
  the signature mismatch. **Never distribute a locally built APK as an update.**
- Always verify the keystore secrets are configured in the repository settings
  before tagging.

---

## 16. Data safety: how upgrades preserve user data

### Where the data lives

Internal app storage under
`/data/data/com.renttrack.renttrack/app_flutter/LUCKY/*.json` plus a photos
folder. Android guarantees this survives an **update** (install over the top)
and destroys it only on **uninstall** or **clear data**.

### The three conditions for a safe upgrade

1. **`applicationId` unchanged.** It is `com.renttrack.renttrack` and must
   stay that way — changing it creates a *different* app, and the old data
   becomes invisible.
2. **Same signing key.** The CI release uses the keystore from repository
   secrets; if that key is rotated, the new APK will not install over the old
   one. (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`.)
3. **No uninstall, no clear data.** This is the only user action that can lose
   data during an upgrade.

### Schema changes in v2.1.0

**None that require migration, and nothing destructive.** The only change is
`LeaseChequeRecord.month`, which is re-derived from `paidDate` on read
(§6.7) — old files self-repair and are corrected on the next save. Verified on
a device; see §6.7.

**First launch after upgrading** runs the §8.5 archive sweep, which may mark
tenants whose `vacatedDate` has passed as `archived` and free their beds. That
is intended behaviour, not data loss — nothing is deleted.

### Recommended upgrade procedure (for the user)

1. **Open the current app → Settings → Create backup.** Choose *Save to device*
   or *Share* and confirm the zip exists.
2. *(Optional extra insurance: Settings → Create backup → Share → upload the
   zip to cloud storage.)*
3. **Download the new APK** from the GitHub Release.
4. **Install over the existing app.** Do **not** uninstall first and do not use
   "Clear storage" in Android settings.
5. If Android prompts about installing over an existing app, accept — that
   prompt is Android confirming it will preserve your data.
6. **Launch once and verify** your flats, tenants and payments are intact.
7. **Create a second backup** as the new restore point.

### Recovery

Settings → **Restore from backup** validates the zip and replaces the dataset
atomically.

---

## 17. Known issues and historical notes

- **`Routes.financialActivity` is dead code.** `FinancialActivityScreen` is
  reachable from the UI but not through this named route.
- **Five pre-existing analyzer infos/warnings** (§14). Non-blocking.
- **Recent Transactions / All Transactions are intentionally all-time**, while
  their summary cards are month-scoped (§9).
- **Archived flats are excluded from Dashboard aggregation** but included in
  `ExpensesScreen`. This split is deliberate and is asserted by
  `test/unit/dashboard_service_test.dart`.
- **`AppConfig.prefKeyCurrentMonth` is unused** — `MonthSelection` is
  deliberately in-memory so every launch starts on the live month.
- **Original bug report this document replaced** (preserved for history):
  > *"I added expense and when I checked for it in the over view page it showed.
  > But when I deleted that expense payment detail the payment was deleted but
  > the expense amount was not updated."*

  This is a stale-summary class of defect: a derived total not recomputing
  after a ledger edit. The v2.1.0 work in §8.10 (`TransactionEditService`) and
  the month-scoped rebuilds are the structural response — **worth re-verifying
  explicitly**, since a reproducible stale total after a delete/edit is the
  one issue here that is not yet covered by a dedicated regression test.
