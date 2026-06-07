# Bug Report: Import Exchange Transactions Duplicate

## Description
When importing transactions using the Excel import feature, `currency_exchange_out`, `currency_exchange_in`, and `currency_income` type transactions were being duplicated in the wallet.

## Root Cause
The export feature writes ALL transactions to the "All Transactions" sheet as a complete ledger, and also writes them to their dedicated specialized sheets ("Currency Exchanges", "Currency Income").
During the import process, the mobile app's `import_provider.dart` was parsing ALL rows from the "All Transactions" sheet and creating `ImportRowType.transaction` items for them. It then parsed the dedicated sheets and generated separate `ImportRowType.exchange` and `ImportRowType.income` items. Because the specialized sheets use different UUIDs (`exchangeEventId` instead of the individual transaction `id`s exported to "All Transactions"), the duplicated UUID checks did not catch them. This resulted in the same exchange transaction being generated twice (once as two independent transactions and once as a linked exchange pair).

## Fix Implemented
Updated `parseExcel` in `import_provider.dart` to skip processing specialized transaction types (`currency_exchange_out`, `currency_exchange_in`, `currency_income`) from the "All Transactions" sheet **if** their corresponding dedicated sheets exist in the Excel file. This delegates the processing of these types to their dedicated sheets, which correctly captures all required context (e.g. `exchangeEventId`, `source`) without causing duplication.

## Files Modified
- `apps/mobile/lib/features/import/providers/import_provider.dart`
