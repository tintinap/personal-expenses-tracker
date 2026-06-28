# Bug Report: Missing Exchange Rate API Fallback

**Date**: 2026-06-12
**Symptom**: 
When switching the "View Currency" or "Base Currency" to a currency that has never been used in the local database (e.g. THB), the calculated display amounts did not update (behaved as a 1:1 conversion).

**Root Cause**: 
The `ExchangeRateDao.getMostRecent()` method queried the local SQLite database for the exchange rate. If no rate was found, the calling providers silently caught the `null` and fell back to `1.0`. There was no mechanism to fetch the missing rate from the live API.

**Fix Applied**: 
1. Added a centralized method `getMostRecentOrFetch(from, to)` to `ExchangeRateDao`.
2. This new method queries the local DB first. If the rate is missing or `0`, it uses `Dio` to fetch the live rate from `api.frankfurter.app/latest`.
3. The fetched rate is cached in the DB for future offline use.
4. Updated all vulnerable callsites to use `getMostRecentOrFetch`:
   - `shared_providers.dart`: `viewCurrencyRateProvider`
   - `shared_providers.dart`: `changeBaseCurrency`
   - `wallet_providers.dart`: `portfolioProvider`
   - `import_provider.dart`: CSV import parser

**Regression Test Location**: 
`/apps/mobile/test/features/shared/providers/shared_providers_test.dart`
