# Excel Import & Export Fix — Design Document

## Part 1: Export Format Fix

### Problem

Currently, the export skips dates/periods with zero transactions:
- **Daily sheet**: Has 3 gaps (Apr 26, May 8, May 21 missing in the [example file](file:///Users/tinnapatplangsri/Code/side_project/expense_app/docs/example_excel_file/ProjectPET_Export_1780145520552.xlsx))
- **All Transactions sheet**: Only contains rows for actual transactions — no indication of which dates had zero activity
- **Summary sheets** (Weekly, Fortnightly, Monthly, Yearly): Only show periods containing transactions

### Proposed Fix

#### 1a. All Transactions Sheet — Empty Date Rows

Add rows for dates within the export range that have no transactions. These rows will have:

| Column | Value for empty date rows |
|---|---|
| Date | The missing date (YYYY-MM-DD) |
| Type | `no_transaction` |
| Description | *(empty)* |
| Category | *(empty)* |
| Original Amount | `0` |
| Original Currency | *(empty)* |
| Base Amount | `0` |
| Exchange Rate | `0` |
| Rate Source | *(empty)* |
| UUID | *(empty)* |

> [!NOTE]
> Using `no_transaction` as the type makes it easy to filter out these rows during import. They are clearly distinguishable from real transaction data.

**Where they appear**: Interleaved in chronological order among real transactions. If April 26 has no transactions, a single `no_transaction` row appears between the Apr 25 and Apr 27 entries.

#### 1b. Period Summary Sheets — Zero-Transaction Rows

All period summary sheets (Daily, Weekly, Fortnightly, Monthly, Yearly) will generate **every period in the date range**, regardless of whether transactions exist.

- **Daily**: Every calendar day from start to end date
- **Weekly**: Every Monday-to-Sunday week
- **Fortnightly**: Every 14-day period
- **Monthly**: Every calendar month
- **Yearly**: Every year

Zero-transaction periods show `0` for all numeric columns and `0` for transaction count.

#### Files Changed

| File | Change |
|---|---|
| [export_provider.dart](file:///Users/tinnapatplangsri/Code/side_project/expense_app/apps/mobile/lib/features/export/providers/export_provider.dart) | Add empty date rows in `_buildAllTransactionsSheet`; modify `_buildPeriodSummarySheet` to generate all periods |
| [export.service.ts](file:///Users/tinnapatplangsri/Code/side_project/expense_app/apps/api/src/export/export.service.ts) | Add empty date rows in `buildAllTransactionsSheet`; period sheets already generate all dates (using formulas) — verify & fix gaps |

---

## Part 2: Excel Import Feature

### 2a. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        User Flow                             │
│                                                              │
│  Settings → Import → Pick .xlsx → Parse → Preview → Confirm │
└───────────────────────┬──────────────────────┬───────────────┘
                        │                      │
              ┌─────────▼─────────┐  ┌─────────▼─────────┐
              │   Mobile (Dart)   │  │   Web (Next.js)    │
              │                   │  │                    │
              │ Parse locally     │  │ Parse in browser   │
              │ Validate locally  │  │ Validate locally   │
              │ Preview screen    │  │ Preview modal      │
              │ Insert to Drift   │  │ POST /import/txns  │
              │ sync_status=pend. │  │ Server validates   │
              │ Sync via existing │  │ Insert to Postgres │
              │ sync_queue        │  │                    │
              └───────────────────┘  └───────────────────┘
```

### 2b. Schema Change — `is_aggregate` Flag

Add a new boolean column to the `transactions` table:

| Field | Type | Default | Notes |
|---|---|---|---|
| `is_aggregate` | BOOLEAN | `false` | When `true`, this transaction represents a period-level aggregate (e.g., "this week = 300 AUD total") rather than a single transaction |

**Drift (mobile)**:
```dart
BoolColumn get isAggregate =>
    boolean().named('is_aggregate').withDefault(const Constant(false))();
```

**Prisma (backend)**:
```prisma
isAggregate Boolean @default(false) @map("is_aggregate")
```

> [!IMPORTANT]
> This requires a database migration on both mobile (Drift migration step) and backend (Prisma migration).

### 2c. Sheets Read & Column Mapping

The import reads **three raw data sheets** from the Excel file:

#### Sheet: "All Transactions"

| Excel Column | Maps To | Required | Validation |
|---|---|---|---|
| Date | `transaction_date` | Yes | Valid date (YYYY-MM-DD) |
| Type | `transaction_type` | Yes | Must be: `expense`, `currency_income`, `currency_exchange_out`, `currency_exchange_in` |
| Description | `note` | No | Max 200 chars |
| Category | `category_id` (resolved by name) | Yes for expenses | Must match existing category name |
| Original Amount | `original_amount` | Yes | Numeric, > 0 |
| Original Currency | `original_currency` | Yes | Valid ISO 4217 from supported list |
| Base Amount | `amount_base` | No | If missing, calculated from exchange rate |
| Exchange Rate | `exchange_rate` | No | If missing, defaults to 1.0 (same currency) or fetched |
| Rate Source | `rate_source` | No | Defaults to `import` |
| UUID | `id` | No | If present and exists in DB → duplicate check. If missing → auto-generate |

**Rows with Type = `no_transaction` are skipped** (these are the empty date rows from the export fix).

#### Sheet: "Currency Income"

| Excel Column | Maps To | Required |
|---|---|---|
| Date | `transaction_date` | Yes |
| Currency | `original_currency` | Yes |
| Amount | `original_amount` | Yes |
| Source | `source_label` | No |
| Base Currency Equivalent | `amount_base` | No |
| UUID | `id` | No |

> [!NOTE]
> Currency Income rows from this sheet are **cross-referenced** against "All Transactions" by UUID to avoid duplication. If a currency_income row exists in both sheets with the same UUID, it is imported only once.

#### Sheet: "Currency Exchanges"

| Excel Column | Maps To | Required |
|---|---|---|
| Date | `transaction_date` | Yes |
| From Currency | exchange_out `original_currency` | Yes |
| From Amount | exchange_out `original_amount` | Yes |
| To Currency | exchange_in `original_currency` | Yes |
| To Amount | exchange_in `original_amount` | Yes |
| Rate | `exchange_rate` | No |
| Rate Source | `rate_source` | No |
| Note | `note` | No |
| UUID | `exchange_event_id` | No |

Each row creates **two linked records**: `currency_exchange_out` + `currency_exchange_in`, sharing the same `exchange_event_id`.

### 2d. Missing Date / Aggregate Support

When a user manually creates an Excel file with period-level data (e.g., "this week my expense is 300 AUD"):

**Expected format in the Excel**:
| Date | Type | Description | Category | Original Amount | Original Currency | ... |
|---|---|---|---|---|---|---|
| 2026-06-02 | expense | Weekly total | Food & dining | 300 | AUD | ... |

The user can add an extra column or use a specific pattern:

**Option 1 — Period indicator column (recommended)**:
Add an optional column called `Period` after the standard columns:

| Date | Type | ... | Period |
|---|---|---|---|
| 2026-06-02 | expense | ... | week |

Valid `Period` values: `day` (default/blank), `week`, `fortnight`, `month`, `year`

When `Period` is set to anything other than `day` or blank:
1. `is_aggregate` = `true`
2. `transaction_date` = the start of the period (Monday for week, 1st for month, etc.)
3. The transaction is treated as a single aggregate record in reports

**Option 2 — Description prefix convention**:
If the Description starts with `[WEEK]`, `[MONTH]`, `[FORTNIGHT]`, or `[YEAR]`:
1. `is_aggregate` = `true`
2. The prefix is stripped from the note
3. `transaction_date` = first day of the period containing the Date value

> [!TIP]
> Both options are supported. The `Period` column takes precedence when present. The description prefix is a fallback for users who don't want to add extra columns.

### 2e. Duplicate Detection

**Match criteria**: `transaction_date` + `original_amount` + `category_id` (resolved by name)

**Algorithm**:
1. For each row being imported, query existing transactions matching all three criteria
2. If a match is found → mark the row as "⚠️ Probable duplicate" in the preview
3. User sees the duplicate warning and can toggle import/skip per row
4. UUID-based dedup: If the UUID column is present and matches an existing record, it's marked as "🔄 Existing (will update)" — user can choose to update or skip

**Preview states per row**:
| Status | Icon | Meaning |
|---|---|---|
| Ready | ✅ | No issues, will be imported |
| Duplicate | ⚠️ | Matches existing record by date+amount+category |
| Update | 🔄 | UUID matches existing record (will overwrite) |
| Error | ❌ | Validation failed (stops import, must fix) |

### 2f. Preview & Validation UI

#### Mobile (Flutter) — Import Preview Screen

```
┌────────────────────────────────────┐
│  ← Import Preview                  │
│                                    │
│  📄 ProjectPET_Export_2026.xlsx     │
│  119 rows found · 3 sheets parsed  │
│                                    │
│  ┌────────────────────────────────┐│
│  │ Summary                        ││
│  │  ✅ 115 ready to import       ││
│  │  ⚠️  3 probable duplicates    ││
│  │  ❌  1 validation error       ││
│  └────────────────────────────────┘│
│                                    │
│  ❌ Row 45: Missing amount         │
│  ─────────────────────────────────│
│  Import stops at first error.      │
│  Fix row 45 in Excel and retry.    │
│                                    │
│  [Cancel]                          │
│                                    │
│  ─── OR (when no errors) ────      │
│                                    │
│  ┌──── Transactions────────────┐  │
│  │ ☑ ✅ 2026-04-21 | Expense  │  │
│  │      380.00 AUD | Rent     │  │
│  │ ☑ ✅ 2026-04-21 | Expense  │  │
│  │      57.15 AUD | Subs.     │  │
│  │ ☐ ⚠️ 2026-04-22 | Expense │  │
│  │      2.50 AUD | Personal   │  │
│  │      ⚠️ Probable duplicate  │  │
│  │ ...                         │  │
│  └─────────────────────────────┘  │
│                                    │
│  [Cancel]    [Import 115 records]  │
└────────────────────────────────────┘
```

**Key behaviors**:
- All rows checked by default **except** duplicates (unchecked)
- User can toggle any row on/off
- Error rows stop the import — user must fix the Excel and re-upload
- Scrollable list with row details
- "Import N records" button shows the count of checked rows

#### Web (Next.js) — Import Modal

Same layout adapted to a modal dialog. Uses a table view for the preview with sortable columns and checkboxes.

### 2g. Error Handling

**On validation error**: Import **stops entirely**. The preview shows:
- Which row number failed
- What the error is (e.g., "Row 45: Missing required field 'Original Amount'")
- Instruction: "Fix the error in your Excel file and try again"

**Validation rules** (per row):
1. `Date` must be a valid date string or Excel date serial
2. `Type` must be one of the valid transaction types (or `no_transaction` to skip)
3. `Original Amount` must be numeric and > 0 (for non-`no_transaction` rows)
4. `Original Currency` must be in the supported currency list
5. `Category` must match an existing category name (for expenses)
6. `Description/Note` must be ≤ 200 characters

**Sheet presence**: If any of the 3 raw data sheets is missing, it's silently skipped (only the sheets found are processed).

### 2h. Import Entry Point

**Settings → Import section** (below Export):

```
Export & Import
─────────────────────────────
📤 Export as Excel (.xlsx)
   [Export]

📥 Import from Excel (.xlsx)
   Import transactions from an Excel file.
   Supports exported files or manually created files.
   [Choose File]
─────────────────────────────
```

### 2i. File Changes — Import Feature

#### Mobile (Flutter)

| File | Change |
|---|---|
| [NEW] `features/import/` | New feature directory |
| [NEW] `features/import/providers/import_provider.dart` | Import service: parse xlsx, validate, detect duplicates, insert to Drift |
| [NEW] `features/import/screens/import_preview_screen.dart` | Preview screen with validation summary and row list |
| [NEW] `features/import/models/import_row.dart` | Data class for parsed row with validation state |
| [MODIFY] `features/settings/` | Add "Import from Excel" button to Settings screen |
| [MODIFY] `core/database/tables.dart` | Add `is_aggregate` column to Transactions table |
| [MODIFY] `core/database/database.dart` | Drift migration for `is_aggregate` column |

#### API (NestJS)

| File | Change |
|---|---|
| [NEW] `src/import/import.module.ts` | Import module |
| [NEW] `src/import/import.controller.ts` | `POST /import/transactions` endpoint |
| [NEW] `src/import/import.service.ts` | Validate, detect duplicates, insert transactions |
| [NEW] `src/import/dto/import-transaction.dto.ts` | DTOs for import payload |
| [MODIFY] `prisma/schema.prisma` | Add `isAggregate` field to Transaction model |

#### Web (Next.js)

| File | Change |
|---|---|
| [NEW] `src/components/import/ImportModal.tsx` | Import modal with preview table |
| [NEW] `src/lib/import-parser.ts` | Client-side xlsx parser (using SheetJS or exceljs) |
| [MODIFY] Settings page | Add import button and modal trigger |

---

## Part 3: Import Guideline Markdown

A new file `docs/import-guide.md` will be created with:

1. **Overview** — What the import feature does
2. **Supported formats** — File type (.xlsx), sheet names, column structure
3. **Using an exported file** — How to re-import an exported file (e.g., editing a few rows)
4. **Creating a manual file** — Template with required columns and example rows
5. **Missing date / aggregate entries** — How to use the Period column or [WEEK] prefix
6. **Duplicate handling** — How duplicates are detected and the preview workflow
7. **Troubleshooting** — Common errors and how to fix them
8. **Example** — Reference to the [example file](file:///Users/tinnapatplangsri/Code/side_project/expense_app/docs/example_excel_file/ProjectPET_Export_1780145520552.xlsx)

---

## Part 4: PRD Update

A new file `docs/prd-project-pet-v4.md` will be created as a **duplicate** of the existing PRD with:

1. All existing content preserved
2. Version bumped to 4.0
3. New section **25. Excel Import** appended at the end with:
   - Availability (all users, all platforms)
   - Trigger (Settings → Import)
   - Platform-specific behavior (mobile: local Drift; web: API endpoint)
   - Supported sheets and column mapping
   - Aggregate/missing-date support
   - Duplicate detection rules
   - Preview/validation workflow
   - Error handling
   - Acceptance criteria
4. Table of Contents updated with section 25
5. Section 17 (Excel Export) updated to mention the `no_transaction` empty date rows
6. Section 20 (Data Models) updated with `is_aggregate` field
7. Section 24 updated to remove "Bank or credit card import" from out-of-scope (since we now have Excel import)

---

## Part 5: Affected Existing Features

### Impact on Reports / Dashboard

Aggregate transactions (`is_aggregate = true`) should be:
- ✅ **Included** in spend totals and category breakdowns
- ✅ **Included** in period summaries
- ⚠️ **Flagged** visually in transaction lists with a small "Σ" badge or "(aggregate)" label
- ❌ **Excluded** from "transaction count" metrics (since one aggregate may represent multiple real transactions)

### Impact on Budgets

Aggregate transactions count toward budget spend calculations (since they represent real spending).

### Impact on Sync

Imported transactions on mobile get `sync_status = pending` and sync via the existing `sync_queue` — no special handling needed.

### Impact on Google Sheets

Imported transactions synced to the backend will trigger Google Sheets mirror writes via the existing sheets processor — no special handling needed.
