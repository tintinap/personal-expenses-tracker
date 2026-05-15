# Execution Plan: Remaining Tasks (Mobile & Backend)

**Status:** Active  
**Created:** 2026-05-16  

## Overview
Implement all remaining features, fix bugs, and clean up tech debt identified from the PRD v3.1 gap analysis. Covers navigation restructure (Settings → gear icon, Reports → bottom tab), missing screens (Reports, Transaction Detail), auth wiring, sync fixes, backend API gaps, and orphan code removal.

## Tasks

### [ ] Phase 1: Nav Restructure + Cleanup (no dependencies)
- [ ] **T1: Move Settings to AppBar gear icon**
  - Update `ScaffoldWithNavBar` in `app_router.dart` — remove Settings tab from bottom nav
  - Add gear icon (`Icons.settings_outlined`) to AppBar `actions` (shared across all shell tabs)
  - Update `_calculateSelectedIndex` to remove settings index
- [ ] **T2: Add Reports tab + screen**
  - Create `features/reports/screens/reports_screen.dart`
  - Add `/reports` route to `ShellRoute` in `app_router.dart` at tab index 3
  - Add Reports `_NavBarItem` where Settings used to be
  - Implement period selector (reuse `PeriodSelector` widget)
  - Implement donut chart (spend by category) — extract from Home
  - Implement bar chart (daily spend within period) using `fl_chart`
  - Implement line chart (rolling spend trend) using `fl_chart`
  - Implement period comparison card (this vs previous: absolute + %)
  - Implement category list with spend amount and % of total
- [ ] **T3: Remove orphan files**
  - Delete `core/providers/database_provider.dart` (duplicate, zero imports)
  - Delete `data/models/expense.dart` (legacy, zero imports)
  - Delete `data/models/category.dart` (legacy, zero imports)
  - Delete `data/database/database_service.dart` (legacy, zero imports)
  - Delete `services/export_helper_stub.dart` (zero imports)
  - Delete `services/export_helper_web.dart` (zero imports)
  - Delete `services/export_helper_native.dart` (zero imports)
  - Delete `features/budgets/utils/mock_data.dart` (zero imports)
  - Remove empty `data/` and `services/` directories
  - Remove `_PlaceholderScreen` class from `app_router.dart`
- [ ] **T4: Remove unused OptionalAuthGuard** (backend)
  - Either wire it to appropriate endpoints or remove the dead code from `guards/`

### [ ] Phase 2: Core Bug Fixes (unblocks auth & sync)
- [ ] **T5: Fix secure storage key mismatch**
  - `AuthNotifier` uses `jwt_access_token`/`jwt_refresh_token`; `AuthInterceptor` reads `access_token`/`refresh_token`
  - Align both to use `access_token`/`refresh_token`
  - Update `signOut()` to delete the correct keys
- [ ] **T6: Mount sync provider**
  - `syncProvider` is never watched — sync worker never starts
  - Add `ref.watch(syncProvider)` in `DailySpendApp.build()`
  - Add sync status indicator to Settings screen (last synced, pending count)
- [ ] **T7: Dio base URL from environment**
  - Read base URL from `.env` via `flutter_dotenv` instead of hardcoded `localhost:3000`
- [ ] **T8: Categories REST — add parentId + iconCodePoint** (backend)
  - Add `parentId` (optional UUID) and `iconCodePoint` (optional int) to `CreateCategoryDto`/`UpdateCategoryDto`
  - Add 1-level depth validation (reject if referenced parent already has a `parentId`)
  - Add `GET /categories/:id` endpoint
- [ ] **T9: Sync push — update CurrencyBalance** (backend)
  - `SyncService.syncTransaction` does NOT update `CurrencyBalance` (REST path does)
  - Extract balance logic into shared method callable from both sync and REST paths
- [ ] **T10: Budget alerts after REST transaction creates** (backend)
  - `BudgetAlertsService.evaluateUserBudgets` only runs after sync push
  - Call it after REST `POST /transactions` and `PATCH /transactions/:id`
- [ ] **T11: Strengthen sync conflict logging** (backend)
  - Add proper typing for conflict records (currently `any[]`)
  - Ensure losing version JSON is written to `conflict_log` table

### [ ] Phase 3: Auth (mobile + backend must align)
- [ ] **T12: Server-side OAuth token validation** (backend)
  - Validate Google ID token server-side (Passport strategy or tokeninfo API)
  - Validate Apple identity token via Apple's public keys
  - Remove TODOs from `auth.controller.ts`
- [ ] **T13: Wire real Google Sign-In**
  - Add `google_sign_in` package to `pubspec.yaml`
  - Implement actual Google OAuth flow in `AuthNotifier`
  - Exchange ID token with backend (`POST /auth/google`), store JWT
  - On first sign-in: upload all local records to backend (initial sync)
- [ ] **T14: Wire real Apple Sign-In**
  - Add `sign_in_with_apple` package to `pubspec.yaml`
  - Implement actual Apple Sign-In flow in `AuthNotifier`
  - Exchange identity token with backend (`POST /auth/apple`), store JWT
  - On first sign-in: upload all local records to backend (initial sync)

### [ ] Phase 4: Feature Completion
- [ ] **T15: Transaction Detail bottom sheet**
  - Create `TransactionDetailSheet` widget
  - Show all fields, sync status badge, estimated rate label
  - For exchange transactions: show both linked sides
  - Edit/Delete action buttons; wire tap handler in `TransactionListTile`
  - Remove `/expenses/:id` placeholder route
- [ ] **T16: Base currency change re-conversion**
  - Add `changeBaseCurrency()` method to a provider/service
  - Re-convert all `amount_base` values from `original_amount` + `original_currency`
  - Show progress dialog during re-conversion
- [ ] **T17: View currency display conversion**
  - Create a `viewCurrencyAmount` utility function
  - Apply conversion in Home summary cards, transaction list, Reports charts, Wallets total
- [ ] **T18: Account deletion flow**
  - Add `DELETE /auth/account` endpoint (backend, JWT-protected)
  - Delete all user data from PostgreSQL
  - Add "Delete Account" button in Settings with confirmation dialog
  - Clear auth state, return to local mode

### [ ] Phase 5: Integrations (can defer past v1 MVP)
- [ ] **T19: Real Google Sheets API** (backend)
  - Integrate `googleapis` (Google Sheets API v4) with OAuth2 client
  - Implement real `setupSheet()`, `syncTransactionsToSheet()`, row CRUD by UUID
  - Add `Currency Income` and `Currency Exchanges` tabs
  - Add queue processor for async writes with retry
- [ ] **T20: Real FCM push notifications** (backend)
  - Add `firebase-admin` package, initialize with service account
  - Implement real `sendPushNotification()` using `admin.messaging().send()`
  - Add FCM token registration endpoint
- [ ] **T21: Google Sheets UI in Settings**
  - Wire "Connect"/"Disconnect" buttons to backend Sheets endpoints
  - Display linked sheet name; show upsell banner for Apple Sign-In users
- [ ] **T22: Recurring expenses auto-logging**
  - Build recurrence evaluation logic (check on app launch / period change)
  - Auto-insert copies at the start of each new cycle
  - UI to mark expense as recurring and to pause/delete recurrence
