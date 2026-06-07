# Project PET — Excel Import Guideline

This guide explains how to import transaction data into the Project PET system using Excel files (`.xlsx`). You can either modify a file you previously exported from the system or construct a new file from scratch.

---

## 1. Supported File Format & Sheet Names

The importer accepts standard Excel files (`.xlsx`) and reads up to **three raw data sheets** if they are present. Any other sheets (such as period summaries) are ignored during import.

The sheets must be named exactly:
1. **`All Transactions`**: Raw transaction data (expenses, income, exchanges).
2. **`Currency Income`**: Raw income transaction data.
3. **`Currency Exchanges`**: Raw currency exchange pairs.

If a sheet is missing from the Excel file, it is skipped (e.g. you can import a file containing only the `All Transactions` sheet).

---

## 2. Sheet Specifications & Columns

### Sheet A: `All Transactions`
This is the primary sheet for raw transactions.

| Column Header | Required | Valid Values / Description |
|---|---|---|
| **Date** | **Yes** | Valid date in `YYYY-MM-DD` format or Excel date serial. |
| **Type** | **Yes** | Must be one of: `expense`, `currency_income`, `currency_exchange_out`, `currency_exchange_in`. Rows with type `no_transaction` are skipped. |
| **Description** | No | Any text (max 200 characters). Can include period prefixes (e.g., `[WEEK]`). |
| **Category** | **Yes*** | Required **only** for `expense` type. Must match a category name in your app (case-insensitive, e.g. `Groceries`, `Food & dining`). |
| **Original Amount** | **Yes** | Positive decimal number (e.g. `24.50`). |
| **Original Currency** | **Yes** | 3-letter ISO currency code (e.g. `AUD`, `USD`, `THB`). |
| **Base Amount** | No | Base currency equivalent. If left blank, it is calculated from the exchange rate. |
| **Exchange Rate** | No | Conversion rate. If blank, the app will search the exchange rate cache. |
| **Rate Source** | No | Label for rate source (e.g. `frankfurter`, `custom`, `import`). |
| **UUID** | No | Unique transaction identifier. Used to overwrite existing records instead of creating duplicates. |
| **Period** | No | Optional period indicator for aggregate/missing-date entries: `day` (or blank), `week`, `fortnight`, `month`, `year`. |

### Sheet B: `Currency Income`
Used to import income records exclusively.

| Column Header | Required | Valid Values / Description |
|---|---|---|
| **Date** | **Yes** | Valid date in `YYYY-MM-DD` format or Excel date serial. |
| **Currency** | **Yes** | 3-letter ISO currency code (e.g. `AUD`, `USD`). |
| **Amount** | **Yes** | Positive decimal number. |
| **Source** | No | Source/label of the income (e.g. `Salary`, `Dividends`). |
| **Base Currency Equivalent** | No | Equivalent value in base currency. |
| **UUID** | No | Unique transaction ID. If an income row shares a UUID with a row on the `All Transactions` sheet, it is imported only once. |

### Sheet C: `Currency Exchanges`
Each row in this sheet represents an exchange pair, and will create **two linked records** (`currency_exchange_out` and `currency_exchange_in`) in the system.

| Column Header | Required | Valid Values / Description |
|---|---|---|
| **Date** | **Yes** | Valid date in `YYYY-MM-DD` format or Excel date serial. |
| **From Currency** | **Yes** | 3-letter ISO code of the currency you exchanged from (e.g. `USD`). |
| **From Amount** | **Yes** | Positive decimal number. |
| **To Currency** | **Yes** | 3-letter ISO code of the currency you exchanged to (e.g. `AUD`). Must be different from `From Currency`. |
| **To Amount** | **Yes** | Positive decimal number. |
| **Rate** | No | Exchange rate (how many `From Currency` per 1 `To Currency`). Calculated if left blank. |
| **Rate Source** | No | Label for rate source (e.g. `custom`, `import`). |
| **Note** | No | Description/note for the exchange (max 200 characters). |
| **UUID** | No | Shared exchange event ID. If present, existing exchange entries with this ID will be overwritten. |

---

## 3. Advanced Features

### Aggregate / Missing-Date Support (Period totals)
If you have period-level aggregate data (e.g. "this week my total food expense was 300 AUD") instead of individual day-level transactions, you can import them in one of two ways:

1. **`Period` Column**: On the `All Transactions` sheet, add a `Period` column (index 10 or header name "Period") and set the value to `week`, `fortnight`, `month`, or `year`.
2. **Description Prefix**: Add a bracketed prefix to your description note, e.g., `[WEEK] Weekly food spend` or `[MONTH] May Rent`.

When either of these is detected:
- The transaction is flagged as an **aggregate** record (`is_aggregate = true`).
- The date of the transaction is automatically adjusted to the **start of that period** (e.g., Monday for a week, 1st for a month, Jan 1st for a year).
- In reports, these are treated as aggregate entries and are excluded from transaction count calculations to maintain accuracy, but are fully included in spending sums and budget evaluations.

## 4. Interactive Missing Category Mapping

When the Excel file contains category names not found in your database, the import preview will pause and display a **"Map New Categories"** section. You can resolve these categories before importing:

- **Top-Level Category**: Create it as a brand-new primary category. You can choose a custom color and icon.
- **Subcategory**: Map it as a subcategory underneath an *existing* top-level category, or underneath another *new* top-level category from the file. 
  - *Note:* Subcategories cannot have their own subcategories (maximum 1 level deep).
  - *Visuals:* Subcategories automatically inherit both the color and icon from their chosen parent category.

Categories are only saved to your database once you confirm and click "Import".

---

## 5. Duplicate Detection & Overwrite Rules

When a file is loaded, Project PET runs validation and duplicate checks:

- **Updates (🔄)**: Checked by default. A row is automatically treated as an update (overwriting the existing record) based purely on its values — no UUID needed:
  - **Expenses:** `Date + Original Amount + Category` match an existing expense.
  - **Income:** `Date + Amount + Currency` match an existing income.
  - **Exchanges:** `Date + From Amount + From Currency + To Amount` match an existing exchange pair.
- **Probable Duplicates (⚠️)**: This status is no longer used — all value-matched rows are now automatically treated as updates.
- **Ready (✅)**: New transactions with no match in the database. Checked by default.
- **Error (❌)**: Rows failing basic validations. These **block the import** entirely until fixed.

---

## 6. Troubleshooting & Common Errors

If the preview displays an error (❌), the import button is disabled. You must open your Excel file, fix the row, and upload it again.

Common validation errors include:
- **`Missing or invalid Date`**: Ensure the Date column contains valid values in `YYYY-MM-DD` or `YYYY-MM-DD HH:MM:SS` format.
- **`Category is required for expenses`**: All rows with type `expense` must have a non-empty value in the `Category` column.
- **`From and To currencies must be different`**: On the `Currency Exchanges` sheet, `From Currency` and `To Currency` columns must be different.
- **`Duplicate UUID found in the file`**: Two rows in the Excel file share the same UUID. Ensure all UUIDs are unique or left blank.

---

## 7. Template & Examples

Refer to the included example exported file in the project workspace for a structured reference:
[example_excel_file/ProjectPET_Export_1780145520552.xlsx](file:///Users/tinnapatplangsri/Code/side_project/expense_app/docs/example_excel_file/ProjectPET_Export_1780145520552.xlsx)
