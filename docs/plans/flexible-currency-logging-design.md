# Flexible Currency Logging Design

## 1. Intent & Scope
Enable users to log expenses, income, and currency exchanges in any supported currency. The UI will prioritize a clean layout using a "Prefix Dropdown" embedded directly inside the amount input fields.

## 2. Architecture & UI Components

### 2.1 CurrencyPrefixDropdown Widget
*   A new stateless widget injected into the `prefixIcon` of the `TextField`.
*   Displays the selected `currencyCode` and a dropdown arrow (`AUD ▾`).
*   Tapping the prefix opens a Modal Bottom Sheet or a Dropdown Menu listing the 12 supported currencies from the `CurrencyCode` enum.

### 2.2 TransactionBottomSheet Adjustments
*   **State:** Replace hardcoded `_selectedCurrency` with `_fromCurrency` and introduce `_toCurrency`. Both default to the user's base currency.
*   **Expense/Income View:** A single amount field utilizing the `CurrencyPrefixDropdown` bound to `_fromCurrency`.
*   **Exchange View:** 
    *   "From Amount" field bound to `_fromCurrency`.
    *   "To Amount" field bound to `_toCurrency` via a secondary `CurrencyPrefixDropdown`.

## 3. Data Flow & Calculations (Option A)

When the user submits an **Exchange**:
*   **Outbound Transaction:**
    *   `originalCurrency`: `_fromCurrency`
    *   `originalAmount`: From Amount 
    *   `amountBase`: To Amount
    *   `exchangeRate`: `(To Amount) / (From Amount)`
*   **Inbound Transaction:**
    *   `originalCurrency`: `_toCurrency`
    *   `originalAmount`: To Amount
    *   `amountBase`: To Amount
    *   `exchangeRate`: `1.0`

When submitting an **Expense/Income**:
*   `originalCurrency`: `_fromCurrency`
*   `originalAmount`: Entered Amount
*   `exchangeRate`: Default to `1.0` (Pending background sync resolution).

## 4. Edge Cases & Validations
*   **Same Currency Prevention:** If `_fromCurrency == _toCurrency` in the Exchange tab, form submission is blocked.
*   **Dynamic Balance Warnings:** The negative balance warning text will dynamically cross-reference the `currencyBalancesProvider` specifically matching the currently selected `_fromCurrency`, rather than a global total.
*   **State Persistence:** Selected currencies are maintained in state when flipping between the Expense, Income, and Exchange tabs.
