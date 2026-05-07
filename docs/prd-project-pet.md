# Product Requirements Document
## Project PET — Personal Expense Tracker (Monorepo)

**Version:** 3.1
**Last updated:** April 2026
**Status:** Ready for codegen

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals & success metrics](#2-goals--success-metrics)
3. [Target users](#3-target-users)
4. [Platform & tech stack](#4-platform--tech-stack)
5. [App architecture overview](#5-app-architecture-overview)
6. [Screen map & navigation](#6-screen-map--navigation)
7. [Authentication & account model](#7-authentication--account-model)
8. [Expense entry & management](#8-expense-entry--management)
9. [Categories](#9-categories)
10. [Currency handling](#10-currency-handling)
11. [Currency income & exchange events](#11-currency-income--exchange-events)
12. [Time period views](#12-time-period-views)
13. [Budget alerts](#13-budget-alerts)
14. [Visualisation dashboard](#14-visualisation-dashboard)
15. [Offline-first sync architecture](#15-offline-first-sync-architecture)
16. [Google Sheets integration](#16-google-sheets-integration)
17. [Excel export](#17-excel-export)
18. [Theming (light & dark mode)](#18-theming-light--dark-mode)
19. [Error states & edge cases](#19-error-states--edge-cases)
20. [Data models](#20-data-models)
21. [Riverpod providers](#21-riverpod-providers)
22. [User stories & acceptance criteria](#22-user-stories--acceptance-criteria)
23. [Non-functional requirements](#23-non-functional-requirements)
24. [Out of scope (v1)](#24-out-of-scope-v1)

---

## 1. Overview

Project PET is a personal expense tracking application built as a **monorepo** with three apps:

- **Flutter mobile app** (iOS & Android) — offline-first with local SQLite storage
- **Next.js web app** — online-only, same feature set and visual style as mobile
- **NestJS backend API** — cloud source of truth, handles sync, auth, and Google Sheets integration

Users can log, categorise, and analyse daily spending across multiple currencies. The mobile app is **offline-first**: SQLite (via Drift) is the primary write target on device. When online and signed in, the mobile app syncs to the NestJS backend. The Next.js web app talks directly to the NestJS API (online only).

The **base currency** is user-configurable (default: **AUD**). All stored amounts are converted to the user's base currency. Original currency and amount are also stored for auditability. Changing the base currency re-converts all stored `amount_base` values using the latest exchange rates.

---

## 2. Goals & success metrics

### Goals

- Log an expense in under 10 seconds
- Work fully offline on mobile; sync seamlessly when connectivity returns
- Alert users before they overspend, not after
- Mirror expense data to Google Sheets automatically (via backend)
- Give users clear spending insight across flexible time periods
- Maintain consistent UI/UX between mobile and web

### Success metrics

| Metric | Target |
|---|---|
| Time to log one expense | < 10 seconds |
| Offline entry → sync on reconnect | 100% of pending records synced |
| Budget alert delivery | Fires once at 80%, once at 100% per period |
| Google Sheet write latency (online) | < 5 seconds after sync to backend |
| App cold start (mobile) | < 2 seconds on mid-range device |
| Web page load (initial) | < 3 seconds |
| Crash rate | < 0.5% of sessions |

---

## 3. Target users

**Primary:** Individual users tracking personal daily expenses with occasional multi-currency spending (e.g. travel abroad, online purchases in foreign currencies). The app supports any base currency, making it suitable for users worldwide. Default base currency is AUD.

**Key use cases:**
- Logging coffee, groceries, transport on the go (mobile, offline)
- Reviewing weekly/monthly spend trends on a laptop (web)
- Checking exchange-rate-adjusted totals when travelling
- Sharing or auditing expenses via Google Sheets

---

## 4. Platform & tech stack

### Monorepo structure

| App | Technology | Location |
|---|---|---|
| Mobile | Flutter (iOS & Android) | `apps/mobile/` |
| Web | Next.js 16 (App Router, Tailwind, i18n: EN + TH) | `apps/web/` |
| Backend API | NestJS 11 (TypeScript) | `apps/api/` |

### Mobile app stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | Flutter | iOS & Android from one codebase |
| Local database | **SQLite via `drift`** | Source of truth on device; offline-first |
| State management | **Riverpod** | `flutter_riverpod` + `riverpod_annotation` |
| Navigation | **`go_router`** | Declarative routing with `ShellRoute` for bottom nav |
| HTTP | **`dio`** | With interceptors for auth (JWT) + retry |
| Secure storage | `flutter_secure_storage` | JWT tokens only |
| Exchange rates | Frankfurter API (`api.frankfurter.app`) | Free, ECB-backed, no API key required |

### Backend API stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | NestJS 11 | TypeScript, modular |
| ORM | **Prisma 6** | PostgreSQL schema management + migrations |
| Database | **PostgreSQL 16** | Cloud source of truth |
| Auth | **Passport.js + JWT** | `@nestjs/passport` + `@nestjs/jwt` |
| OAuth providers | Google OAuth 2.0 + Apple Sign-In | Via Passport strategies |
| Google Sheets | Google Sheets API v4 | Server-side mirror; backend writes to Sheet on sync |
| Push notifications | Firebase Cloud Messaging (FCM) | Budget alerts (mobile only, v1) |

### Web app stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | Next.js 16 | App Router, server components |
| Styling | Tailwind CSS | Same design tokens as mobile |
| i18n | `next-intl` | EN + TH locales |
| HTTP | Fetch API | Calls NestJS API directly |
| Auth | JWT (stored in httpOnly cookies) | Received from NestJS after OAuth |

### Infrastructure

| Layer | Choice | Notes |
|---|---|---|
| Containerisation | Docker Compose | PostgreSQL + NestJS + Next.js |
| Toolchain | MISE | `mise run setup`, `mise run dev` |

### Dependency decisions (closed)

- **NestJS backend over Supabase direct**: Full control over business logic, validation, conflict resolution, and Google Sheets writes. Single API for both web and mobile clients
- **Drift (mobile) + Prisma (server)**: Drift provides offline-first SQLite on mobile; Prisma manages the server-side PostgreSQL schema. Both share the same logical data model
- **Riverpod over Provider**: Better async state handling (`AsyncValue`), compile-safe references, `family` modifiers for parameterised providers (exchange rates, budget progress), no `BuildContext` dependency
- **go_router over Navigator**: Declarative routing, `ShellRoute` for bottom nav, type-safe parameters, auth redirect guards
- **Passport.js over Supabase Auth**: Keeps auth in the NestJS stack, no external auth dependency, well-proven NestJS pattern

---

## 5. App architecture overview

### Monorepo layout

```
expense_app/
├── .mise.toml                    # Tool versions + task runner
├── docker-compose.yml
├── scripts/
│   ├── setup.sh                  # First-time setup
│   └── dev.sh                    # Start all services
│
├── apps/
│   ├── mobile/                   # Flutter (iOS & Android)
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── app.dart          # MaterialApp + GoRouter setup
│   │       ├── core/
│   │       │   ├── database/     # Drift DB, DAOs, migrations
│   │       │   ├── sync/         # SyncService, SyncQueue worker
│   │       │   ├── network/      # Dio client, Frankfurter service
│   │       │   ├── notifications/# FCM setup, budget alert service
│   │       │   └── theme/        # AppTheme (light + dark)
│   │       ├── features/
│   │       │   ├── auth/         # Google + Apple Sign-In
│   │       │   ├── expenses/     # Expense CRUD, add/edit sheets
│   │       │   ├── categories/   # Category management
│   │       │   ├── budgets/      # Budget CRUD, alert logic
│   │       │   ├── dashboard/    # Home screen, charts
│   │       │   ├── reports/      # Period views, comparisons
│   │       │   ├── export/       # Excel export
│   │       │   └── settings/     # App settings, account
│   │       └── shared/
│   │           ├── widgets/      # Reusable UI components
│   │           └── utils/        # Formatters, date helpers
│   │
│   ├── web/                      # Next.js (web frontend)
│   │   ├── messages/             # i18n (en.json, th.json)
│   │   └── src/
│   │       ├── app/[locale]/     # Locale routes (/en, /th)
│   │       │   ├── dashboard/
│   │       │   ├── reports/
│   │       │   ├── budgets/
│   │       │   └── settings/
│   │       ├── components/       # Shared UI components
│   │       ├── lib/              # API client, auth utils
│   │       └── i18n/             # next-intl config
│   │
│   └── api/                      # NestJS (backend)
│       ├── prisma/
│       │   └── schema.prisma     # DB schema (source of truth)
│       └── src/
│           ├── auth/             # Passport.js strategies, JWT guard
│           ├── transactions/     # Transaction CRUD + sync endpoints
│           ├── categories/       # Category CRUD
│           ├── budgets/          # Budget CRUD + alert logic
│           ├── exchange-rates/   # Frankfurter proxy + caching
│           ├── sheets/           # Google Sheets mirror service
│           ├── sync/             # Sync controller (push/pull)
│           └── prisma/           # PrismaService
│
└── docs/                         # PRD, architecture docs
```

### Data flow

```
┌──────────────────────────────┐
│       Flutter Mobile         │
│                              │
│  ┌────────────────────┐      │         ┌──────────────────────────┐
│  │  SQLite (Drift)    │      │  sync   │       NestJS API         │
│  │  = offline source  │◄────────────►  │                          │
│  │    of truth        │      │  HTTP   │  PostgreSQL (Prisma)     │
│  └────────────────────┘      │  (Dio)  │  = cloud source of truth │
│                              │         │                          │
└──────────────────────────────┘         │  ┌──────────────────┐   │
                                         │  │ Google Sheets     │   │
┌──────────────────────────────┐         │  │ (server-side      │   │
│       Next.js Web            │         │  │  mirror writes)   │   │
│                              │  HTTP   │  └──────────────────┘   │
│  (online only, no local DB)  │◄───────►│                          │
│                              │         └──────────────────────────┘
└──────────────────────────────┘
```

### Layer rules

- **Mobile**: Feature folders own their screens, providers, and repositories. Providers call repositories; repositories call DAOs (Drift) or remote services (Dio). No feature imports another feature directly — shared state goes in `core/` or `shared/`
- **API**: Follows NestJS module pattern — Controller → Service → Repository (Prisma). Each module is self-contained
- **Web**: Next.js App Router with server components where possible. Shared UI components in `components/`. API calls via a typed client in `lib/`
- **Cross-app consistency**: Mobile and web share the same visual design language, colour tokens, and UX patterns. Both consume the same NestJS API

---

## 6. Screen map & navigation

### Navigation structure (mobile — go_router)

Bottom navigation bar with 5 tabs using `ShellRoute`. Persists across the app. Hidden only when add/edit sheets are open.

| Tab index | Label | Icon | Route |
|---|---|---|---|
| 0 | Home | `home_outlined` | `/` |
| 1 | Wallets | `account_balance_wallet_outlined` | `/wallets` |
| 2 | Reports | `bar_chart` | `/reports` |
| 3 | Budgets | `savings_outlined` | `/budgets` |
| 4 | Settings | `settings_outlined` | `/settings` |

A floating `+` FAB overlays all five tabs and opens the Add Expense bottom sheet.

### Navigation structure (web — Next.js App Router)

Sidebar navigation (desktop) / hamburger menu (mobile viewport). Same four sections as mobile.

| Section | Route |
|---|---|
| Dashboard (Home) | `/[locale]/dashboard` |
| Wallets | `/[locale]/wallets` |
| Reports | `/[locale]/reports` |
| Budgets | `/[locale]/budgets` |
| Settings | `/[locale]/settings` |

### Screen inventory

#### Home (`/`)
- Period selector (segmented control: Daily / Weekly / Fortnightly / Monthly / Yearly)
- Period navigation (← label →, tap label to date-pick)
- Summary cards: total spent, top category, budget remaining, transaction count
- Currency balance bar: horizontal scrollable chips showing each currency balance (tappable → opens Currency Wallets screen)
- Expense list for selected period (grouped by date)
- Each expense row: category colour dot, category name, note (truncated), amount in view currency
- Swipe-left on row: delete (with confirmation); swipe-right: edit

#### Add/Edit Expense (bottom sheet on mobile, modal on web)
- Auto-focuses amount field on open
- Fields: Amount, Currency (picker, defaults to last used), Date (defaults to today), Category (picker), Note (optional, max 200 chars)
- "Save" button — disabled until Amount and Category are filled
- Shows converted base currency equivalent below amount field in real time

#### Expense Detail (`/expenses/:id`)
- Read-only view of all expense fields
- Edit and Delete buttons
- Shows sync status badge (`pending` / `synced`) — mobile only
- Shows whether exchange rate was estimated (offline)

#### Reports (`/reports`)
- Same period selector as Home
- Donut chart: spend by category
- Bar chart: daily spend within period
- Line chart: rolling spend trend
- Period comparison card: this period vs previous (absolute + %)
- List of categories with spend amount and % of total

#### Budgets (`/budgets`)
- List of active budgets (global first, then per-category)
- Each card: name, period type, progress bar (green/amber/red), amount used / limit
- "+ Add budget" button → Add Budget sheet
- Tap card → Budget Detail

#### Budget Detail (`/budgets/:id`)
- Budget config (editable inline or via edit sheet)
- Full progress breakdown
- History of alerts fired this cycle

#### Settings (`/settings`)
- Account section: sign-in status (Google or Apple), sign out, delete account
- Google Sheets section: connect/disconnect (only available for Google accounts), linked sheet name
- Export section: "Export as Excel (.xlsx)" button — available to all signed-in users and local-mode users
- Preferences: base currency picker (default: AUD, changeable to any supported currency), view currency toggle, dark mode toggle
- Categories: manage default + custom categories
- Sync status: last synced timestamp, manual sync trigger (mobile only)
- About: version, licenses

#### Currency Wallets (`/wallets`)
- Overview card: **total portfolio value** — sum of all currency balances converted to base currency using today's rate
- List of currency cards, one per currency with non-zero balance (or all tracked currencies)
- Each currency card shows:
  - Currency flag + ISO code (e.g. 🇹🇭 THB)
  - **Current balance** in that currency (e.g. `4,500 THB`)
  - **Base currency equivalent** using today's rate (e.g. `≈ A$191.25`)
  - Mini sparkline or delta showing balance trend (last 30 days)
  - Breakdown summary: total income, total spent, total exchanged
- Tap a currency card → **Currency Detail** screen
- Currencies with zero balance shown at bottom in a collapsed "Empty" section
- Manual balance adjustment button (for correcting discrepancies — adds a `balance_adjustment` note)

#### Currency Detail (`/wallets/:currency`)
- Full transaction history filtered to that currency only
- Summary stats at top:
  - Total received (income events)
  - Total spent (expenses in this currency)
  - Total exchanged out / in
  - Current balance
- Transaction list grouped by date (same visual style as Home, but filtered to one currency)
- Each row shows: transaction type icon, amount, note, date

#### Category Management (`/settings/categories`)
- List of all categories (default + custom), grouped hierarchically: parent categories with their sub-categories indented below
- Toggle visibility (hide/show)
- Tap to edit (rename, change colour, or assign/change parent category)
- "+ Add category" at bottom (unlimited) — can create a top-level category or a sub-category under an existing parent
- Sub-categories are limited to **1 level deep** — a sub-category cannot have its own children
- Cannot delete a parent category that has sub-categories — must reassign or delete children first
- Cannot delete a category with associated expenses — must reassign first
- Hidden categories do not appear in the add/edit expense picker

---

## 7. Authentication & account model

### Auth architecture

Authentication is handled entirely by the **NestJS backend** using Passport.js strategies. The backend issues JWTs after successful OAuth.

```
┌─────────────────┐     OAuth      ┌──────────────────┐     Verify     ┌──────────┐
│  Flutter/Web    │──────────────► │   NestJS API     │◄──────────────│ Google / │
│  (client)       │  redirect      │   Passport.js    │   token        │ Apple    │
│                 │◄──────────────│   + JWT issuer   │               └──────────┘
│  Stores JWT     │   JWT pair     │                  │
│  (secure stor.) │  (access +     │  Stores user in  │
│                 │   refresh)     │  PostgreSQL      │
└─────────────────┘               └──────────────────┘
```

**JWT flow:**
1. Client initiates OAuth (Google or Apple) → redirected to provider
2. Provider callback hits NestJS endpoint (`/auth/google/callback` or `/auth/apple/callback`)
3. NestJS validates the OAuth token, creates/finds user in PostgreSQL
4. NestJS issues JWT pair (access token: 15min, refresh token: 7 days)
5. Mobile: stores tokens in `flutter_secure_storage`
6. Web: stores tokens in httpOnly cookies
7. All subsequent API calls include the access token in `Authorization: Bearer` header
8. Dio interceptor (mobile) / fetch wrapper (web) handles automatic token refresh

### Modes

**Local mode (no account) — mobile only**
- Full app functionality, zero sign-in friction
- All data in local SQLite only
- No cross-device sync
- Google Sheets integration unavailable
- Excel export available (generated on device)
- Sign-in prompt shown once on first launch as a dismissible banner (not a blocking gate)

**Signed-in mode — Google account**
- Sign in via Google OAuth through NestJS backend
- Mobile: local SQLite remains the primary write target; syncs to backend when online
- Web: reads/writes directly to NestJS API (online only)
- Google Sheets integration available (handled server-side)
- Excel export available
- On first sign-in (mobile): all existing local records are uploaded to NestJS and marked `synced`
- On sign-out: local data retained (mobile); cloud data remains; writes stop

**Signed-in mode — Apple account**
- Sign in via Apple Sign-In through NestJS backend
- Same sync behaviour as Google account
- Google Sheets integration **unavailable** — requires a linked Google account
- Excel export available (on-demand replacement for Sheets)
- On first sign-in (mobile): all existing local records are uploaded to NestJS and marked `synced`
- On sign-out: local data retained (mobile); cloud data remains

### Feature matrix by account type

| Feature | Local mode (mobile) | Apple Sign-In | Google Sign-In |
|---|---|---|---|
| Expense logging | ✅ | ✅ | ✅ |
| Offline-first (mobile) | ✅ | ✅ | ✅ |
| Cloud sync (NestJS) | ❌ | ✅ | ✅ |
| Cross-device sync | ❌ | ✅ | ✅ |
| Web app access | ❌ | ✅ | ✅ |
| Google Sheets mirror | ❌ | ❌ | ✅ |
| Excel export | ✅ | ✅ | ✅ |
| Budget alerts (FCM) | ✅ | ✅ | ✅ |

### Auth flow

```
App launch (mobile)
  └── Show Home (local mode)
        └── Sign-in banner (dismissible, shown once)
              └── User taps "Sign in"
                    ├── "Continue with Google" → Google OAuth via NestJS
                    │     ├── Success → Receive JWT → Upload local records → Enable sync + Sheets
                    │     └── Cancel → Dismiss, continue local mode
                    └── "Continue with Apple" → Apple Sign-In via NestJS
                          ├── Success → Receive JWT → Upload local records → Enable sync (no Sheets)
                          └── Cancel → Dismiss, continue local mode

Web launch
  └── Show login page
        ├── "Continue with Google" → Google OAuth via NestJS → JWT in cookie → Dashboard
        └── "Continue with Apple" → Apple Sign-In via NestJS → JWT in cookie → Dashboard
```

### NestJS auth modules

```
src/auth/
├── auth.module.ts
├── auth.controller.ts         # /auth/google, /auth/apple, /auth/refresh, /auth/logout
├── auth.service.ts            # JWT issuance, user creation/lookup
├── strategies/
│   ├── google.strategy.ts     # PassportStrategy(Strategy, 'google')
│   ├── apple.strategy.ts      # PassportStrategy(Strategy, 'apple')
│   └── jwt.strategy.ts        # PassportStrategy(Strategy, 'jwt')
├── guards/
│   ├── jwt-auth.guard.ts      # Protects authenticated routes
│   └── optional-auth.guard.ts # Allows unauthenticated access (for local mode data on web)
└── dto/
    └── auth-response.dto.ts   # { accessToken, refreshToken, user }
```

### Google Sheets upsell for Apple users

When an Apple Sign-In user navigates to Settings → Google Sheets, show an informational banner:
> "Google Sheets sync requires a Google account. Sign in with Google to enable automatic mirroring, or use Excel export below."

No blocking gate — the export buttons are immediately below the banner.

### Acceptance criteria

- [ ] App is fully usable without signing in (mobile — local mode)
- [ ] Web app requires sign-in (redirects to login page)
- [ ] Sign-in prompt (mobile) offers both "Continue with Google" and "Continue with Apple" options
- [ ] Sign-in prompt is a dismissible banner, not a blocking screen
- [ ] On first sign-in (mobile), all local records are uploaded to NestJS and marked `synced`
- [ ] Google Sign-In users have access to Google Sheets integration
- [ ] Apple Sign-In users do not see Google Sheets connect option; see export-only UI instead
- [ ] Sign-out retains local data (mobile); sync stops; Sheet (if connected) remains intact
- [ ] User can delete account — all PostgreSQL data deleted; local data optionally deleted (confirmation dialog)
- [ ] JWT access tokens expire after 15 minutes; refresh tokens after 7 days
- [ ] Mobile: JWT tokens stored in `flutter_secure_storage`; never in plain text
- [ ] Web: JWT stored in httpOnly secure cookies
- [ ] Dio interceptor automatically refreshes expired access tokens

---

## 8. Expense entry & management

### Add expense fields

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| Amount | Decimal input | Yes | Empty | Auto-focused on sheet open |
| Currency | Picker | Yes | Last used (or base currency) | Shows ISO code + flag |
| Date | Date picker | Yes | Today | Can be backdated |
| Category | Picker | Yes | Last used | From active categories |
| Note | Text field | No | Empty | Max 200 chars |

### Entry behaviour

1. User taps FAB → bottom sheet opens (mobile) / modal opens (web), amount field auto-focused
2. User enters amount → base currency equivalent shown below field in real time (uses cached rate)
3. If currency = base currency, equivalent line is hidden
4. User fills required fields → "Save" button enables
5. On save:
   - Exchange rate fetched (or loaded from cache) for the selected date
   - **Mobile**: Expense written to local SQLite (Drift) with `sync_status = pending`. If online and signed in: sync worker pushes to NestJS backend
   - **Web**: Expense sent directly to NestJS API via POST request
   - Sheet/modal closes; expense appears at top of list

### Exchange rate at save time

- If expense date = today → use today's cached rate (or fetch if not cached)
- If expense date = past → fetch Frankfurter historical rate for that date
- If offline (mobile) → use last known cached rate; set `rate_estimated = true`; show "estimated rate" label on the expense

### Edit behaviour

- All fields editable
- Changing amount or currency re-fetches/recalculates exchange rate
- Changing date re-fetches historical rate for new date
- Save overwrites existing record; `updated_at` refreshed; `sync_status = pending` (mobile)

### Delete behaviour

- Confirmation dialog: "Delete this expense? This cannot be undone."
- **Mobile**: On confirm: soft-delete locally (set `deleted_at`), add delete operation to `sync_queue`; when synced: hard-delete from PostgreSQL
- **Web**: On confirm: DELETE request to NestJS API; removed from PostgreSQL immediately
- Backend removes corresponding row from Google Sheet by UUID (if Sheets connected)

### Recurring expenses (stretch goal, v1)

- User can mark expense as recurring: weekly, fortnightly, or monthly
- App auto-logs a copy at the start of each new cycle
- Recurring expenses can be paused or deleted

### Acceptance criteria

- [ ] Expense can be saved in under 10 seconds
- [ ] Amount in foreign currency is converted to user's base currency and both stored
- [ ] Backdated expense uses Frankfurter historical rate for that date
- [ ] Offline entry (mobile) uses last cached rate and shows "estimated" label
- [ ] Base currency equivalent updates in real time as user types the amount
- [ ] All fields of an existing expense can be edited
- [ ] Delete prompts confirmation and removes from local DB (mobile), PostgreSQL, and Google Sheet
- [ ] Web expense save sends POST directly to NestJS API

---

## 9. Categories

### Default categories

| Category | Colour hex |
|---|---|
| Food & dining | `#378ADD` |
| Groceries | `#4CAF50` |
| Transport | `#FF7043` |
| Health & medical | `#E91E8C` |
| Shopping & retail | `#9C27B0` |
| Bills & utilities | `#009688` |
| Entertainment | `#FFC107` |
| Travel | `#FF8F00` |
| Subscriptions | `#F44336` |
| Education | `#455A64` |
| Personal care | `#4FC3F7` |
| Other / uncategorised | `#9E9E9E` |

### Customisation rules

- Users can rename any default or custom category — renames propagate to all historical expenses
- Users can change a category's colour at any time
- Users can create custom categories with any name and colour — **no limit on count**
- Users can create **sub-categories** under any top-level (parent) category — limited to **1 level deep**
- Transactions can be assigned to either a parent category or a sub-category
- Sub-category expenses are **aggregated under the parent** in charts and dashboard summaries
- The transaction entry dropdown shows the hierarchy clearly (e.g. parent in bold, sub-categories indented with "— " prefix)
- Users can hide categories (removed from pickers, still shown in reports/history)
- A parent category **cannot be deleted** if it has active sub-categories — user must reassign or delete children first
- Categories with associated expenses **cannot be deleted** — user must reassign expenses to another category first
- A parent category **cannot be demoted** to a sub-category while it has children
- Hidden categories do not appear in the add/edit expense picker

### Acceptance criteria

- [ ] All 12 default categories present on first launch
- [ ] User can create a custom category with name and colour
- [ ] User can create a sub-category under any top-level parent category
- [ ] Sub-category depth is enforced to 1 level (cannot nest sub-sub-categories)
- [ ] Transaction entry dropdown shows hierarchical labels (parent bold, children indented)
- [ ] Donut chart and dashboard summary aggregate sub-category expenses under their parent
- [ ] Renaming a category updates all historical expenses retroactively
- [ ] Hiding a category removes it from pickers but not from reports
- [ ] Attempting to delete a category with expenses shows a "reassign first" dialog
- [ ] Attempting to delete a parent with sub-categories shows a "remove children first" dialog
- [ ] A parent category cannot be made a sub-category while it has children
- [ ] Categories (including parentId) sync between mobile and web via NestJS API
- [ ] Backend validates parentId references and enforces 1-level depth on sync

---

## 10. Currency handling

### Design principle

All expenses are **stored in the user's base currency** (default: AUD). The base currency is configurable in Settings → Preferences. Original currency and original amount are also stored for auditability. Display currency is a view-layer concern only — stored data is never rewritten when exchange rates change.

**Changing base currency:** When the user changes their base currency (e.g. AUD → THB), all existing `amount_base` values are re-converted from `original_amount` + `original_currency` using the latest Frankfurter rate for each transaction's date. This is a background operation; a progress indicator is shown. The exchange rate cache is also updated for the new base currency.

### Exchange rate source

**Frankfurter API** (`https://api.frankfurter.app`) — free, no API key, ECB-backed

| Use case | Consumer | Endpoint |
|---|---|---|
| Today's rate | Mobile (direct) or NestJS (proxy) | `GET /latest?from={currency}&to={base_currency}` |
| Historical rate | Mobile (direct) or NestJS (proxy) | `GET /{YYYY-MM-DD}?from={currency}&to={base_currency}` |

**NestJS exchange rate module**: The backend also caches exchange rates in PostgreSQL. When the mobile app syncs a transaction with a rate, the backend stores it. The web app fetches rates from the NestJS API (which proxies/caches Frankfurter).

### Caching strategy

**Mobile (Drift/SQLite):**
1. On first use of a currency pair on a given date → fetch from Frankfurter → cache in local `exchange_rates` table
2. Same pair + same date → use cached rate (no API call)
3. New day → fetch fresh rate and cache
4. API timeout (5s) or offline → use last known cached rate → set `rate_estimated = true`

**Backend (Prisma/PostgreSQL):**
1. Exchange rates cached in `exchange_rates` table
2. Web app requests rates from NestJS → NestJS checks cache → fetches from Frankfurter if missing
3. Synced mobile transactions include their rate, which backend stores

### Supported currencies (v1)

AUD (default base), THB, USD, EUR, GBP, JPY, SGD

Any of these currencies can be set as the base currency. The remaining currencies are available as transaction currencies.

### View currency toggle

- User can toggle display currency at any time in Settings
- Persistent setting (not per-session)
- All dashboard totals, lists, and report amounts respect selected view currency
- Conversion for display uses today's cached rate (not the historical rate of each expense)
- Stored data is never modified

### Acceptance criteria

- [ ] THB expense stores base currency equivalent using rate at entry date
- [ ] Backdated expense uses Frankfurter historical rate for that date
- [ ] Same currency pair + same date → single API call (cache hit on repeat)
- [ ] Offline entry (mobile) uses last cached rate and shows "estimated" label
- [ ] View currency toggle updates all displayed amounts instantly without touching stored data
- [ ] API timeout falls back to cache within 5 seconds
- [ ] Web app fetches rates through NestJS proxy (not directly to Frankfurter)
- [ ] User can change base currency in Settings → Preferences
- [ ] Changing base currency re-converts all `amount_base` values using latest rates
- [ ] Base currency change shows a progress indicator during re-conversion

---
---

## 11. Currency income & exchange events

This section covers two new transaction types that sit alongside expenses in the ledger:

1. **Currency income** — user receives foreign cash (e.g. withdraws 20,000 THB from an ATM). Records that the user now holds that foreign currency but has not yet spent or exchanged it.
2. **Currency exchange** — user converts one currency to another at a money changer or bank (e.g. 20,000 THB → AUD). Records the conversion, the actual rate received, and auto-logs a base currency income entry when applicable.

### Why a separate transaction type (not an expense)

These events are not spending — they are balance movements. Treating them as expenses would inflate spending totals and distort budgets. They must be visually distinct but live in the **same chronological list** as expenses so the user has a single unified ledger view.

### Transaction type taxonomy

| Type | `transaction_type` value | Effect on ledger |
|---|---|---|
| Expense | `expense` | Reduces base currency balance |
| Currency income | `currency_income` | Records foreign currency received; no base currency spending impact |
| Currency exchange (out) | `currency_exchange_out` | Reduces source currency balance |
| Currency exchange (in) | `currency_exchange_in` | Increases target currency balance; auto-logged as base currency income when applicable |

---

### 11a. Currency income

#### What it represents
User received foreign currency cash. Example: just landed in Bangkok, withdrew 20,000 THB from ATM.

#### Entry fields

| Field | Type | Required | Notes |
|---|---|---|---|
| Amount | Decimal | Yes | Amount received in foreign currency |
| Currency | Picker | Yes | The currency received (e.g. THB) |
| Date | Date picker | Yes | Defaults to today |
| Source | Text | No | e.g. "ATM withdrawal", "Gift from friend" |
| Note | Text | No | Max 200 chars |

#### Storage
- **Mobile (Drift)**: Stored in local `transactions` table with `transaction_type = currency_income`
- **Backend (Prisma)**: Stored in PostgreSQL `transactions` table after sync
- `original_currency` = the received currency (e.g. THB)
- `original_amount` = the amount received
- `amount_base` = base currency equivalent at Frankfurter rate for the date (for reporting only — informational estimate, not a real conversion)
- `rate_estimated = true` if offline

#### Display in list
Distinct visual style: **green left border**, `↓ Income` label.
Example row:
```
↓ +20,000 THB            ATM withdrawal
              est. A$850.00             19 Apr 2026
```

#### Effect on running balance
Adds to the user's THB running balance. Informational only — does not block any actions.

---

### 11b. Currency exchange

#### What it represents
User physically exchanges currency at a money changer, bank, or airport booth.
Example: exchange 15,000 THB → AUD and receive A$620 at the counter.

#### Entry fields

| Field | Type | Required | Notes |
|---|---|---|---|
| From amount | Decimal | Yes | Amount given away (e.g. 15,000) |
| From currency | Picker | Yes | Source currency (e.g. THB) |
| To amount | Decimal | Yes | Amount received (e.g. 620) |
| To currency | Picker | Yes | Target currency (e.g. AUD) |
| Date | Date picker | Yes | Defaults to today |
| Exchange rate | Calculated / editable | Yes | Auto-filled as `to_amount ÷ from_amount`; always visible |
| Rate source | Toggle | Yes | "Custom (what I got)" or "Use Frankfurter rate" |
| Note | Text | No | e.g. "Superrich exchange booth" |

#### Rate logic

```
if rate_source == "custom":
    exchange_rate = to_amount / from_amount   // derived from the two amount fields
    rate_source_label = "custom"

if rate_source == "frankfurter":
    exchange_rate = Frankfurter rate for (from_currency → to_currency) on date
    to_amount = auto-calculated (editable override allowed)
    rate_estimated = (true if offline)
    rate_source_label = "frankfurter"
```

The rate field is always shown and editable before saving. Switching rate source recalculates the rate or `to_amount` accordingly.

#### What gets created on save

Saving a currency exchange atomically creates **two linked transaction records**:

| Record | `transaction_type` | Effect |
|---|---|---|
| Exchange out | `currency_exchange_out` | Reduces `from_currency` running balance (e.g. THB −15,000) |
| Exchange in (auto) | `currency_exchange_in` | Increases `to_currency` running balance (e.g. AUD +620); shown as income |

Both records share the same `exchange_event_id` UUID so they display together and delete together.

#### Base currency income auto-log
When `to_currency` = user's base currency (e.g. AUD):
- A `currency_exchange_in` record is automatically created
- It is **not** counted as an expense and does not affect budget calculations
- It increases the base currency running balance
- Displayed as: `↑ +A$620.00  |  Exchanged from THB  |  Rate: 0.0413`

#### Display in list
Both sides appear as a **single visual unit** with a blue-teal left border and `↕` icon:
```
↕ Currency exchange                          19 Apr 2026
  15,000 THB  →  A$620.00
  Rate: 0.0413 (custom)  ·  Superrich exchange booth
```

---

### 11c. Running balance & Currency Wallets

A `currency_balances` table tracks a per-currency running balance derived from all transactions. On mobile, this is computed from local Drift data. On the backend, it's maintained in PostgreSQL.

| Event | THB effect | AUD effect |
|---|---|---|
| Currency income (20,000 THB) | +20,000 | — |
| Expense (500 THB coffee) | −500 | −(AUD equiv.) |
| Exchange out (15,000 THB → AUD) | −15,000 | — |
| Exchange in (A$620) | — | +620 |

The running balance is **informational only** — it never blocks actions.

#### Home screen — balance chips
Displayed as horizontally scrollable balance chips on the Home screen (e.g. `🇹🇭 THB 4,500 · 🇦🇺 AUD 1,240`) for any currency with a non-zero balance. Tapping any chip or the "See all" arrow navigates to the **Currency Wallets** screen.

#### Currency Wallets screen (`/wallets`)

A dedicated screen showing the user's complete currency portfolio:

```
┌─────────────────────────────────────┐
│  💰 Total Portfolio Value           │
│     A$2,131.25                      │
│     (converted at today's rates)    │
├─────────────────────────────────────┤
│                                     │
│  🇹🇭 THB                            │
│  ┌─────────────────────────────┐   │
│  │  4,500.00 THB  ≈ A$191.25  │   │
│  │  ━━━━━━━━━▓▓░░░ sparkline  │   │
│  │  In: +20,000  Spent: -500  │   │
│  │  Exchanged: -15,000        │   │
│  └─────────────────────────────┘   │
│                                     │
│  🇦🇺 AUD                            │
│  ┌─────────────────────────────┐   │
│  │  1,240.00 AUD              │   │
│  │  ━━━━━━━━━━━━▓▓ sparkline  │   │
│  │  In: +620  Spent: -380     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ▼ Empty currencies (5)            │
└─────────────────────────────────────┘
```

Each currency card is tappable → navigates to **Currency Detail** (`/wallets/:currency`) showing the full transaction history for that currency.

#### Negative balance warning
If logging an expense in THB would cause the THB running balance to go negative:
- Show inline warning on the expense entry sheet: `⚠ This will put your THB balance at −X,XXX THB`
- User can still save — warning only, not a block
- Useful when user spent THB before logging the ATM withdrawal

---

### 11d. UI entry points

The existing FAB (mobile) / "Add" button (web) opens a bottom sheet / modal with a **transaction type selector** at the top:

```
[ Expense ]  [ Income ]  [ Exchange ]
```

Switching type changes the form fields shown below. Single trigger, one sheet/modal, three modes.

| Type | Trigger |
|---|---|
| Expense | Default; same as current behaviour |
| Income | Tap "Income" tab in sheet |
| Exchange | Tap "Exchange" tab in sheet |

---

### 11e. Google Sheets — additional tabs

Currency income and exchange events mirror to **dedicated tabs** (handled by NestJS backend), not the monthly expense tabs:

| Tab name | Contents |
|---|---|
| `Currency Income` | All currency income records |
| `Currency Exchanges` | All exchange events (one row per exchange pair) |

**Currency Income columns:** Date, Currency, Amount, Source, Base currency equivalent (estimated), UUID

**Currency Exchanges columns:** Date, From currency, From amount, To currency, To amount, Rate, Rate source, Note, UUID

---

### 11f. Acceptance criteria

- [ ] User can log a currency income event (e.g. 20,000 THB) via the Income tab in the add sheet
- [ ] Currency income appears in the main list with green left border and `↓ Income` label
- [ ] Currency income increases the THB running balance
- [ ] User can log a currency exchange (THB → AUD) with a custom rate
- [ ] User can log a currency exchange using the Frankfurter rate
- [ ] Rate field is always visible and editable before saving
- [ ] Switching between Custom and Frankfurter rate recalculates the rate or `to_amount` accordingly
- [ ] Saving a THB → AUD exchange atomically creates both `currency_exchange_out` and `currency_exchange_in` records
- [ ] Both sides of an exchange appear together as a single visual unit in the main list
- [ ] Exchange in/out records are NOT counted as expenses and do NOT affect budget totals
- [ ] Base currency running balance increases when base currency is the `to_currency` of an exchange
- [ ] Running balance chips shown on Home screen for currencies with non-zero balance
- [ ] Tapping a balance chip navigates to the Currency Wallets screen
- [ ] Currency Wallets screen shows total portfolio value converted to base currency
- [ ] Each currency card displays: balance, base currency equivalent, breakdown (income/spent/exchanged)
- [ ] Tapping a currency card opens Currency Detail with full transaction history for that currency
- [ ] Currencies with zero balance are collapsed in an "Empty" section at bottom
- [ ] Currency Wallets screen is accessible from the bottom navigation bar (Wallets tab)
- [ ] Logging a THB expense that would make THB balance negative shows a warning — save is still allowed
- [ ] Currency income and exchange events mirrored to their own Google Sheets tabs (via NestJS backend)
- [ ] Deleting an exchange event deletes both `out` and `in` records atomically
- [ ] All transaction types sync correctly between mobile (Drift) and backend (Prisma)

---

## 12. Time period views

### Available periods

| View | Date range | Step unit |
|---|---|---|
| Daily | Single day | 1 day |
| Weekly | Monday to Sunday | 1 week |
| Fortnightly | Monday to Sunday × 2 consecutive weeks | 2 weeks |
| Monthly | 1st to last day of calendar month | 1 month |
| Yearly | 1 Jan to 31 Dec | 1 year |

### Navigation controls

- Segmented control at top of Home and Reports screens (both mobile and web)
- Left arrow (`<`) and right arrow (`>`) step backward/forward by one period
- Tapping the period label (e.g. "April 2026") opens a date picker to jump to any period
- "Today" chip snaps back to the current period
- Right arrow is disabled when viewing the current period (no future navigation)

### Acceptance criteria

- [ ] All five period views display the correct start and end dates
- [ ] Stepping forward/back correctly increments by the period unit
- [ ] Expenses are filtered correctly to the selected period (currency income and exchange events shown but not counted in spend totals)
- [ ] Dashboard totals, charts, and budget progress all respond to period changes
- [ ] "Today" chip returns to the current period from any historical period
- [ ] Period views work identically on mobile and web

---

## 13. Budget alerts

### Period types

**Repeating cadence:**
- Weekly (Monday–Sunday)
- Fortnightly (Monday of week 1 to Sunday of week 2; aligned to calendar)
- Monthly (1st–last day of calendar month)
- Auto-resets at end of each cycle; notification flags cleared on reset

**Custom date range:**
- User picks start and end date
- One-off; does not repeat
- Deactivates automatically on end date (`is_active = false`)

### Budget scope

**Global budget:** single total spend limit across all categories. Displayed as a progress bar on the Home screen summary card.

**Per-category budget:** independent limit for a specific category. Shown on the category card and Budget Detail screen. Each category budget has its own period type.

One global budget maximum; one budget per category maximum.

**Important:** Currency income and exchange events are excluded from budget spend calculations. Only `transaction_type = expense` counts toward budgets.

### Alert thresholds

| State | Trigger | Progress bar colour | Push notification |
|---|---|---|---|
| On track | < 80% used | Green | None |
| Warning | 80–99% used | Amber | Once: "You've used 80% of your [X] budget" |
| Over budget | ≥ 100% used | Red | Once: "You've exceeded your [X] budget by $Y [base currency]" |

- Alerts fire **once per threshold per cycle** — `notified_80` and `notified_100` flags reset at cycle start
- Overspending does **not** block adding new expenses
- User can disable alerts per budget in Settings
- **Budget alert evaluation**: Performed on the NestJS backend after sync. Backend sends FCM push to mobile device

### Fortnightly alignment

Fortnightly periods are **calendar-aligned**: they always start on a Monday and end on the second Sunday. The year's fortnightly periods are anchored from the first Monday of January. Example: Mon 6 Jan–Sun 19 Jan, Mon 20 Jan–Sun 2 Feb, etc. Budget created mid-fortnight joins the current cycle.

### Acceptance criteria

- [ ] User can create a global budget with a repeating or custom period
- [ ] User can create a per-category budget with its own period type
- [ ] 80% alert fires exactly once per cycle when threshold is crossed
- [ ] 100% alert fires exactly once per cycle when threshold is crossed
- [ ] `notified_80` and `notified_100` reset at the start of each new cycle
- [ ] Custom date range budget sets `is_active = false` automatically after end date
- [ ] Editing a budget amount resets both notification flags
- [ ] Overspend does not prevent adding new expenses
- [ ] Currency income and exchange events do not count toward budget spend totals
- [ ] Budget alerts sent via FCM from NestJS backend to mobile devices

---

## 14. Visualisation dashboard

### Charts

| Chart | Type | Description | Period-aware |
|---|---|---|---|
| Spend breakdown | Donut / pie | Spend by category; segments colour-matched to category colours | Yes |
| Daily spend | Bar chart | One bar per day within the selected period | Yes |
| Spend trend | Line chart | Rolling total over time | Yes |
| Period comparison | Summary card | This period vs previous: total, delta (base currency + %) | Yes |

### Chart libraries

| Platform | Library |
|---|---|
| Mobile (Flutter) | `fl_chart` |
| Web (Next.js) | `recharts` or `chart.js` |

### Summary cards (Home screen)

| Card | Content |
|---|---|
| Total spent | Amount in base currency and view currency for selected period (expenses only) |
| Top category | Category with highest spend this period |
| Budget remaining | Global budget: remaining in base currency (or "No budget set") |
| Transactions | Count of expenses in selected period |
| Currency balances | Horizontally scrollable balance chips per currency (e.g. `🇹🇭 THB 4,500 · 🇦🇺 AUD 1,240`) — tappable → opens Currency Wallets screen. Shown only when non-zero |

### Acceptance criteria

- [ ] All charts update when period selector changes
- [ ] Donut chart segments match category colours
- [ ] Bar chart shows correct daily spend totals (expenses only) for the selected period
- [ ] Period comparison shows correct absolute and percentage delta
- [ ] Charts render correctly on mobile (single column) and web (responsive layout)
- [ ] Empty state shown when no expenses exist for the selected period
- [ ] Currency balance chips shown on Home screen for any currency with non-zero running balance
- [ ] Charts have the same visual style on mobile and web

---

## 15. Offline-first sync architecture

### Principle

On mobile, local SQLite (`drift`) is always the **primary write target**. Every create/edit/delete is written locally first, synchronously. Cloud sync is secondary, asynchronous, and eventual. The sync target is the **NestJS backend API** (not a direct database connection).

On web, there is no offline capability — all operations go directly to the NestJS API.

### Record identity

Every record has a UUID generated on device (mobile) or by the backend (web) at creation. This ensures offline-created records on mobile can be merged with cloud records without duplication or ID conflicts.

### Sync status (mobile only)

Every syncable record in the mobile Drift database carries `sync_status`:

| Value | Meaning |
|---|---|
| `pending` | Written locally; not yet pushed to NestJS backend |
| `synced` | Successfully pushed to and acknowledged by NestJS |
| `conflict` | Same record modified on two devices before sync |

### Conflict resolution (v1)

**Most recent `updated_at` timestamp wins.** If two versions of the same UUID exist, the one with the later `updated_at` is kept. The losing version is logged to a `conflict_log` table (backend) for debugging. No UI for conflict resolution in v1.

### Sync flows

**Mobile — offline add transaction:**
1. Write to Drift SQLite; `sync_status = pending`
2. Add insert operation to `sync_queue`
3. UI reflects immediately — no disruption

**Mobile — reconnects:**
1. `SyncWorker` detects connectivity (platform connectivity stream)
2. Processes `sync_queue` in order: insert → update → delete
3. For each operation: sends HTTP request to NestJS API
4. Each success: marks record `synced`, removes from queue
5. Each failure: increments `attempts`; retries with exponential backoff (max 5 attempts, then logs error)
6. Backend triggers Google Sheet updates after transaction sync completes

**Remote change arrives (from web or another mobile device):**
1. Mobile periodically polls NestJS API for changes since last sync (`GET /sync/pull?since={timestamp}`)
2. Pulls changed records; merges into local Drift SQLite
3. UUID deduplication prevents duplicates
4. Conflict check: compare `updated_at`; keep winner

**Web — direct API:**
1. Web creates/edits/deletes via NestJS API directly
2. No local queue — operations are synchronous with the server
3. Backend triggers Google Sheet updates immediately

### NestJS sync endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/sync/push` | `POST` | Mobile pushes batch of pending changes (insert/update/delete) |
| `/sync/pull` | `GET` | Mobile pulls all changes since a timestamp |
| `/sync/status` | `GET` | Returns last sync timestamp and pending conflict count |

**Push payload:**
```json
{
  "operations": [
    {
      "type": "insert",
      "table": "transactions",
      "record": { ... full record ... }
    },
    {
      "type": "update",
      "table": "categories",
      "record": { ... full record ... }
    },
    {
      "type": "delete",
      "table": "transactions",
      "recordId": "uuid-here"
    }
  ],
  "clientTimestamp": "2026-04-19T08:00:00Z"
}
```

**Pull response:**
```json
{
  "changes": {
    "transactions": [ ... changed records ... ],
    "categories": [ ... changed records ... ],
    "budgets": [ ... changed records ... ]
  },
  "serverTimestamp": "2026-04-19T08:00:05Z",
  "conflicts": []
}
```

### Sync queue table (mobile Drift only)

```
sync_queue
  id           UUID       PK
  record_type  TEXT       "transaction" | "budget" | "category"
  record_id    UUID       FK to relevant table
  operation    TEXT       "insert" | "update" | "delete"
  payload      JSON       Full record snapshot at time of queue
  created_at   TIMESTAMP
  attempts     INTEGER    Default 0
  last_error   TEXT       Nullable
```

### Acceptance criteria

- [ ] Transactions added offline on mobile save immediately with `sync_status = pending`
- [ ] All pending records sync to NestJS within 10 seconds of mobile reconnection
- [ ] UUID deduplication prevents duplicate records after sync
- [ ] Changes from web reflected on mobile within 10 seconds of mobile reconnection (via pull)
- [ ] Sync failures retried with exponential backoff; max 5 attempts
- [ ] After 5 failed attempts, error logged and user sees a sync warning indicator in Settings
- [ ] `updated_at` conflict resolution: later timestamp wins
- [ ] Web operations are synchronous — no local queue needed
- [ ] NestJS `/sync/push` and `/sync/pull` endpoints handle batch operations
- [ ] Backend triggers Google Sheet mirror writes after successful sync

---

## 16. Google Sheets integration

### Availability

Optional. Available only when signed in with a Google account. **Handled entirely by the NestJS backend** — neither the mobile app nor the web app writes to Google Sheets directly.

### Setup flow

1. Settings → Google Sheets → "Connect"
2. Client-side OAuth popup/redirect for Google Sheets scopes
3. User authorises
4. OAuth refresh token sent to NestJS backend and stored securely in PostgreSQL (encrypted at rest)
5. NestJS creates spreadsheet titled "Project PET — [Year]" in user's Drive
6. Spreadsheet ID stored in user settings (PostgreSQL)

### Sheet structure

The spreadsheet contains **multiple sheets** covering different time-period aggregations and transaction types. All summary/period sheets are driven by **formulas** referencing the raw data sheets, so they stay in sync automatically.

#### Raw data sheets (written to by backend)

| Sheet name | Contents | Write method |
|---|---|---|
| `All Transactions` | Every transaction (expenses, income, exchanges) in chronological order | Backend appends/updates/deletes rows |
| `Currency Income` | All currency income records | Backend appends/updates/deletes rows |
| `Currency Exchanges` | All exchange events (one row per exchange pair) | Backend appends/updates/deletes rows |

**`All Transactions` columns (Row 1 = frozen header):**

| Column | Header | Content |
|---|---|---|
| A | Date | `YYYY-MM-DD` |
| B | Type | `expense` / `currency_income` / `currency_exchange_out` / `currency_exchange_in` |
| C | Description | Note field |
| D | Category | Category name (expenses only) |
| E | Original Amount | Amount as entered |
| F | Original Currency | ISO 4217 code |
| G | Base Amount | Converted base currency value |
| H | Exchange Rate | Rate used at entry |
| I | Rate Source | `frankfurter` / `custom` / `estimated` |
| J | UUID | Record UUID (used for edit/delete lookup) |

**`Currency Income` columns:** Date, Currency, Amount, Source, Base currency equivalent (est.), UUID

**`Currency Exchanges` columns:** Date, From currency, From amount, To currency, To amount, Rate, Rate source, Note, UUID

#### Time-period summary sheets (formula-driven, auto-sync)

These sheets aggregate data from `All Transactions` using spreadsheet formulas (`SUMIFS`, `QUERY`, `FILTER`). They update automatically when raw data changes.

| Sheet name | Aggregation | Content |
|---|---|---|
| `Daily` | Per day | Date, total spent, breakdown by category, transaction count |
| `Weekly` | Monday–Sunday | Week start date, total spent, breakdown by category, comparison to previous week |
| `Fortnightly` | Mon–Sun × 2 weeks | Fortnight start date, total spent, breakdown by category |
| `Monthly` | Calendar month | Month, total spent, breakdown by category, comparison to previous month |
| `Yearly` | Calendar year | Year, total spent, breakdown by category |

Each summary sheet includes:
- Total expenses (base currency)
- Breakdown by category (amounts + percentages)
- Transaction count
- Period-over-period delta (amount + %)

#### Wallet sheet (formula-driven)

| Sheet name | Content |
|---|---|
| `Wallets` | Running balance per currency, derived from `All Transactions` via formulas. Shows: Currency, Total income, Total spent, Total exchanged in/out, Current balance, Base currency equivalent |

### Write behaviour (NestJS backend)

| Trigger | Sheet action |
|---|---|
| Transaction synced from mobile (via `/sync/push`) | Append/update/delete row in `All Transactions` |
| Transaction created from web (via API) | Append row to `All Transactions` |
| Transaction edited from web | Find row by UUID in column J; update in place |
| Transaction deleted from web | Find row by UUID; delete row |
| Currency income synced/created | Append row to both `All Transactions` and `Currency Income` |
| Currency exchange synced/created | Append row to `All Transactions` and `Currency Exchanges` |
| Exchange event deleted | Remove rows by shared `exchange_event_id` from all raw sheets |
| Sheet write failure | Retry with exponential backoff (max 5 attempts); failure does not affect data sync |

**Summary sheets and Wallets sheet are never written to by the backend** — they are pure formula sheets that auto-update when raw data rows change.

Sheet is **mirror only** — app never reads from the sheet.

### OAuth scopes (obtained from client, stored on server)

- `spreadsheets` — read/write to spreadsheet content
- `drive.file` — access only to files this app created (not full Drive)

### Sign-out behaviour

On sign-out: the spreadsheet **stays in the user's Drive** and writes stop. No data is deleted from the sheet.

### NestJS Sheets module

```
src/sheets/
├── sheets.module.ts
├── sheets.service.ts          # Google Sheets API v4 client
├── sheets.processor.ts        # Queue processor for async Sheet writes
└── dto/
    └── sheet-config.dto.ts    # { spreadsheetId, enabled, lastWriteAt }
```

### Acceptance criteria

- [ ] App creates correctly structured spreadsheet on first setup (via NestJS)
- [ ] Adding an expense appends a row to the correct month tab within 5 seconds (after sync/save)
- [ ] Editing an expense updates the correct row by UUID
- [ ] Deleting an expense removes the correct row by UUID
- [ ] Currency income events append to the `Currency Income` tab
- [ ] Currency exchange events append to the `Currency Exchanges` tab
- [ ] Sheet write failures do not block data sync or API operations
- [ ] Revoking Sheet access stops writes without data loss
- [ ] OAuth uses `drive.file` scope, not full Drive access
- [ ] Sign-out leaves Sheet intact in Drive; writes stop
- [ ] Google Sheets writes are handled entirely by NestJS backend — no client-side Sheet writes

---

## 17. Excel export

### Availability

Available to **all users** — local mode (mobile), Apple Sign-In, and Google Sign-In. This is the primary data export path for Apple users who cannot use Google Sheets, and a supplementary export for all other users.

### Trigger

On-demand only. User navigates to **Settings → Export** and taps "Export as Excel (.xlsx)".

No automatic or scheduled export.

### Platform-specific behaviour

| Platform | Generation | Delivery |
|---|---|---|
| Mobile (Flutter) | Generated on-device from local Drift data | OS share sheet |
| Web (Next.js) | Generated by NestJS backend, downloaded as file | Browser download |

### Export scope

User can choose the date range to export via a date range picker before generating the file. Default range is the current calendar year.

### File structure

The exported `.xlsx` file mirrors the same multi-sheet structure as Google Sheets, with raw data sheets and formula-driven summary sheets:

#### Raw data sheets

**`All Transactions` sheet:**

| Column | Content |
|---|---|
| Date | `YYYY-MM-DD` |
| Type | `expense` / `currency_income` / `currency_exchange_out` / `currency_exchange_in` |
| Description | Note field |
| Category | Category name |
| Original Amount | Amount as entered |
| Original Currency | ISO 4217 code |
| Base Amount | Converted base currency value |
| Exchange Rate | Rate used at entry |
| Rate Source | `frankfurter` / `custom` / `estimated` |
| UUID | Record UUID |

**`Currency Income` sheet** — same columns as Google Sheets `Currency Income` tab

**`Currency Exchanges` sheet** — same columns as Google Sheets `Currency Exchanges` tab

#### Summary sheets (formula-driven)

| Sheet | Content |
|---|---|
| `Daily` | Per-day totals, category breakdown |
| `Weekly` | Monday–Sunday totals, category breakdown |
| `Fortnightly` | 2-week totals (Mon–Sun × 2), category breakdown |
| `Monthly` | Calendar month totals, category breakdown |
| `Yearly` | Calendar year totals, category breakdown |
| `Wallets` | Running balance per currency with income/spent/exchanged breakdown |

All summary sheets use Excel formulas (`SUMIFS`, `COUNTIFS`) referencing `All Transactions`, so the exported file is a working spreadsheet — not just flat data.

### File naming

| Format | Filename |
|---|---|
| Excel | `project-pet-export-YYYY-MM-DD.xlsx` |

### Flutter packages (mobile export)

- Excel: `excel` package (`pub.dev/packages/excel`)
- Share sheet: `share_plus` package

### NestJS export endpoint (web export)

| Endpoint | Method | Response |
|---|---|---|
| `/export/excel` | `GET` | `.xlsx` file download |

Query params: `?from=YYYY-MM-DD&to=YYYY-MM-DD`

### Acceptance criteria

- [ ] "Export as Excel" button present in Settings for all users
- [ ] User can select a custom date range before exporting
- [ ] Excel export produces a single `.xlsx` file with raw data sheets + formula-driven summary sheets
- [ ] Summary sheets (Daily, Weekly, Fortnightly, Monthly, Yearly) correctly aggregate from `All Transactions`
- [ ] `Wallets` sheet shows running balance per currency
- [ ] Exported data matches what is stored locally (mobile) or in PostgreSQL (web) for the selected date range
- [ ] Mobile: file is generated on-device from Drift data; no network request required
- [ ] Mobile: OS share sheet is triggered on completion
- [ ] Web: file is generated by NestJS and downloaded via browser
- [ ] Apple Sign-In users see export as the primary data-sharing option (Google Sheets section shows upsell banner above export buttons)
- [ ] Export works in local mode on mobile (no account required)

---

## 18. Theming (light & dark mode)

Dark mode is supported on first release. Both the mobile app and web app respect the system default and allow manual override in Settings.

### Theme tokens

| Token | Light | Dark |
|---|---|---|
| `surface` | `#FFFFFF` | `#121212` |
| `background` | `#F5F5F5` | `#1E1E1E` |
| `primary` | `#2196F3` | `#90CAF9` |
| `onPrimary` | `#FFFFFF` | `#000000` |
| `error` | `#F44336` | `#EF9A9A` |
| `textPrimary` | `#212121` | `#EFEFEF` |
| `textSecondary` | `#757575` | `#9E9E9E` |
| `divider` | `#E0E0E0` | `#2C2C2C` |

**Cross-platform consistency**: These tokens are used by both the Flutter `ThemeData` and the Tailwind CSS config in the web app to ensure visual consistency.

Transaction list row accent colours:

| Transaction type | Left border colour |
|---|---|
| Expense | Category colour |
| Currency income | `#4CAF50` (green) |
| Currency exchange | `#00897B` (teal) |

Budget progress colours (both themes):

| State | Colour |
|---|---|
| On track (< 80%) | `#4CAF50` |
| Warning (80–99%) | `#FFC107` |
| Over budget (≥ 100%) | `#F44336` |

### Acceptance criteria

- [ ] App respects system dark/light mode on launch (both mobile and web)
- [ ] User can override theme in Settings → Preferences
- [ ] All screens, charts, and modals render correctly in both modes
- [ ] Category colours remain consistent across themes
- [ ] Income and exchange rows have correct accent border colours in both themes
- [ ] WCAG AA contrast ratios met in both themes
- [ ] Mobile and web use matching colour tokens for visual consistency

---

## 19. Error states & edge cases

Every async operation must have a defined error state. The AI agent must implement all of these — do not leave error handling as a TODO.

### Frankfurter API unavailable

- Show "Estimated rate" badge on expense/exchange amount field
- Use last cached rate for the currency pair
- If no cached rate exists: disable Save; show inline error "Exchange rate unavailable. Please try again when online or enter the amount in your base currency."

### NestJS sync failure (mobile)

- Record stays `pending` in local Drift DB
- Retry with exponential backoff (1s, 2s, 4s, 8s, 16s — max 5 attempts)
- After 5 failures: mark `last_error`, show sync warning icon in Settings
- User can tap warning to see failed records and trigger manual retry

### NestJS API error (web)

- Show toast notification with error message
- Retry button on failed operations where applicable
- Network error → show "You appear to be offline. Please check your connection."

### Google Sheets write failure

- Handled by NestJS backend — does not affect client
- Backend retries with exponential backoff
- Failure does not affect local data or API operations
- Admin logging for persistent failures

### No internet, no cached rate (mobile)

- Disable currency conversion; show inline message
- User can still save by entering the amount in their base currency directly

### Category has expenses on delete attempt

- Show dialog: "This category has [N] expenses. Reassign them to another category before deleting."

### THB running balance goes negative

- Show inline warning on expense entry sheet: `⚠ This will put your THB balance at −X,XXX THB`
- Save is still allowed — warning only

### Currency exchange — partial entry

- If user has filled `from_amount` but not `to_amount` (or vice versa): Save button disabled
- Both amount fields and both currency fields are required

### Exchange event deletion

- Confirm dialog: "Delete this exchange? Both the THB out and AUD in entries will be removed."
- Deletes both records atomically (mobile: local + sync queue; web: API call)

### Account deletion

- Confirmation dialog: "This will permanently delete all your cloud data. Your local data will remain on this device."
- On confirm: NestJS deletes all user data from PostgreSQL; revokes JWT; mobile returns to local mode
- Google Sheet (if connected) remains in Drive but is no longer updated

---

## 20. Data models

### Shared logical model

Both Drift (mobile SQLite) and Prisma (backend PostgreSQL) implement the same logical data model. Field names use snake_case in both.

### `users` (backend Prisma only)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `email` | VARCHAR(255) | From OAuth provider |
| `display_name` | VARCHAR(100) | From OAuth provider |
| `avatar_url` | TEXT | Nullable |
| `base_currency` | VARCHAR(3) | Default `AUD`; user-configurable |
| `auth_provider` | VARCHAR(10) | `google` / `apple` |
| `provider_id` | VARCHAR(255) | OAuth provider user ID |
| `google_refresh_token` | TEXT | Nullable; encrypted; for Google Sheets |
| `sheets_spreadsheet_id` | TEXT | Nullable |
| `sheets_enabled` | BOOLEAN | Default false |
| `fcm_token` | TEXT | Nullable; for push notifications |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

### `transactions` (unified table for all transaction types)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK, generated on device (mobile) or backend (web) |
| `user_id` | UUID | FK → users (backend only; mobile uses implicit single-user) |
| `transaction_type` | VARCHAR(25) | `expense` / `currency_income` / `currency_exchange_out` / `currency_exchange_in` |
| `amount_base` | DECIMAL(12,4) | Base currency equivalent (stored for expenses; estimated for income) |
| `original_amount` | DECIMAL(12,4) | Amount as entered |
| `original_currency` | VARCHAR(3) | ISO 4217 e.g. "THB" |
| `exchange_rate` | DECIMAL(10,6) | Rate at time of entry |
| `rate_date` | DATE | Date the rate was fetched |
| `rate_estimated` | BOOLEAN | True if rate from cache while offline |
| `rate_source` | VARCHAR(15) | `frankfurter` / `custom` / `estimated` |
| `exchange_event_id` | UUID | Nullable; links `out` and `in` records of same exchange |
| `category_id` | UUID | Nullable; FK → categories (expenses only) |
| `note` | TEXT | Nullable, max 200 chars |
| `source_label` | TEXT | Nullable; for currency income (e.g. "ATM withdrawal") |

| `transaction_date` | DATE | Date of the transaction |
| `is_recurring` | BOOLEAN | Default false (expenses only) |
| `recurrence_type` | VARCHAR(12) | weekly / fortnightly / monthly / null |
| `sync_status` | VARCHAR(10) | pending / synced / conflict (mobile Drift only; not in Prisma) |
| `deleted_at` | TIMESTAMP | Nullable; soft delete |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | Used for conflict resolution |

### `currency_balances` (derived, kept in sync on every transaction save)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users (backend only) |
| `currency` | VARCHAR(3) | ISO 4217 code |
| `balance` | DECIMAL(12,4) | Current running balance |
| `updated_at` | TIMESTAMP | |

### `categories`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users (backend only) |
| `name` | VARCHAR(50) | |
| `colour_hex` | VARCHAR(7) | e.g. `#378ADD` |
| `is_default` | BOOLEAN | |
| `is_hidden` | BOOLEAN | Default false |
| `sort_order` | INTEGER | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

### `budgets`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users (backend only) |
| `scope` | VARCHAR(10) | global / category |
| `category_id` | UUID | Nullable; FK → categories |
| `amount_base` | DECIMAL(12,2) | Budget limit in user's base currency |
| `period_type` | VARCHAR(12) | weekly / fortnightly / monthly / custom |
| `start_date` | DATE | Anchor date for repeating; start for custom |
| `end_date` | DATE | Nullable; only for custom ranges |
| `is_active` | BOOLEAN | False after custom range expires |
| `notified_80` | BOOLEAN | Reset each cycle |
| `notified_100` | BOOLEAN | Reset each cycle |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

### `exchange_rates`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `base_currency` | VARCHAR(3) | e.g. "AUD" |
| `quote_currency` | VARCHAR(3) | e.g. "THB" |
| `rate` | DECIMAL(10,6) | |
| `rate_date` | DATE | Date the rate applies to |
| `fetched_at` | TIMESTAMP | When fetched from Frankfurter |
| `source` | VARCHAR(20) | "frankfurter" |

### `sync_queue` (mobile Drift only — not in Prisma)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `record_type` | VARCHAR(20) | transaction / budget / category |
| `record_id` | UUID | FK to relevant table |
| `operation` | VARCHAR(10) | insert / update / delete |
| `payload` | JSON | Full record snapshot |
| `created_at` | TIMESTAMP | |
| `attempts` | INTEGER | Default 0 |
| `last_error` | TEXT | Nullable |

### `conflict_log` (backend Prisma only)

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users |
| `record_type` | VARCHAR(20) | transaction / budget / category |
| `record_id` | UUID | The conflicting record UUID |
| `winning_version` | JSON | The version that was kept |
| `losing_version` | JSON | The version that was discarded |
| `resolved_at` | TIMESTAMP | |

### `settings` (mobile Drift only — key-value)

| Key | Type | Default |
|---|---|---|
| `base_currency` | VARCHAR(3) | `AUD` |
| `view_currency` | VARCHAR(3) | `AUD` |
| `theme_mode` | VARCHAR(10) | `system` |
| `last_used_currency` | VARCHAR(3) | `AUD` |
| `last_used_category_id` | UUID | null |
| `sign_in_prompt_dismissed` | BOOLEAN | false |
| `last_sync_timestamp` | TIMESTAMP | null |

---

## 21. Riverpod providers

Define the following providers in the Flutter mobile app. All async providers use `AsyncNotifier` or `FutureProvider`.

| Provider | Type | Responsibility |
|---|---|---|
| `transactionListProvider` | `AsyncNotifierProvider` | All transactions for selected period from Drift; watches `selectedPeriodProvider` |
| `expenseListProvider` | `Provider` | Filters `transactionListProvider` to `transaction_type = expense` only |
| `selectedPeriodProvider` | `StateProvider` | Current period type + date range |
| `categoryListProvider` | `AsyncNotifierProvider` | All categories (including hidden) from Drift |
| `activeCategoryListProvider` | `Provider` | Filters `categoryListProvider` to non-hidden |
| `budgetListProvider` | `AsyncNotifierProvider` | All active budgets from Drift |
| `budgetProgressProvider(budgetId)` | `FutureProvider.family` | % spent for a given budget in current cycle (expenses only) |
| `exchangeRateProvider(currency, date)` | `FutureProvider.family` | Rate for currency pair on given date (Drift cache or Frankfurter API) |
| `currencyBalancesProvider` | `AsyncNotifierProvider` | Running balances for all currencies from Drift |
| `syncStatusProvider` | `StreamProvider` | Current sync state (idle / syncing / error) from SyncWorker |
| `authStateProvider` | `StateNotifierProvider` | Auth state; exposes JWT, provider type (google/apple/none), user info |
| `settingsProvider` | `NotifierProvider` | App settings from Drift (theme, view currency, etc.) |
| `dashboardSummaryProvider` | `Provider` | Derives summary cards from `expenseListProvider` + `currencyBalancesProvider` |

---

## 22. User stories & acceptance criteria

### Onboarding

**US-01** As a new mobile user, I want to start using the app immediately without creating an account.
- Given I open the app for the first time
- When I dismiss the sign-in banner
- Then I can add, view, and manage expenses locally

**US-02** As a mobile user who signs in later, I want my existing local records to carry over.
- Given I have existing local transactions in Drift
- When I sign in with Google for the first time
- Then all local records are uploaded to NestJS and marked `synced`

**US-02b** As an iPhone user, I want to sign in with Apple instead of Google.
- Given I tap "Sign in" on the banner
- When I choose "Continue with Apple" and authenticate
- Then my account is created via NestJS, local records sync, and I have full cloud sync

**US-02c** As an Apple Sign-In user, I want to export my data since I can't use Google Sheets.
- Given I am signed in with Apple
- When I navigate to Settings → Export and tap "Export as Excel"
- Then a `.xlsx` file with all my transactions is generated and the share sheet opens

**US-02d** As a web user, I want to access my expense data from my browser.
- Given I am signed in via the Next.js web app
- When I navigate to the dashboard
- Then I see the same data as my mobile app, with the same visual style

### Expense management

**US-03** As a user, I want to log an expense quickly.
- Given I am on the Home screen
- When I tap `+`, fill in amount and category, and tap Save
- Then the expense is saved in under 10 seconds and appears in the list

**US-04** As a traveller, I want to enter an expense in Thai Baht.
- Given I select THB as currency
- When I enter 500 THB and save
- Then the base currency equivalent is stored alongside the original THB amount

**US-05** As a user entering a past expense, I want the correct historical rate used.
- Given I set the expense date to last Tuesday
- When I save
- Then the Frankfurter historical rate for that date is fetched and stored

### Currency income & exchange

**US-11** As a traveller, I want to log that I received 20,000 THB from an ATM.
- Given I tap `+` and select "Income"
- When I enter 20,000 THB and save
- Then a currency income record appears in the list and my THB balance increases by 20,000

**US-12** As a traveller, I want to log that I exchanged 15,000 THB to AUD at a money changer.
- Given I tap `+` and select "Exchange"
- When I enter 15,000 THB → 620 AUD with a custom rate and save
- Then both sides appear as a linked pair in the list, my THB balance decreases by 15,000, and my AUD balance increases by 620

**US-13** As a traveller, I want to see a warning if my THB spending would exceed what I have logged.
- Given my THB running balance is 500 THB
- When I add a 600 THB expense
- Then I see a warning "This will put your THB balance at −100 THB" but can still save

### Budget alerts

**US-06** As a user, I want to set a monthly food budget.
- Given I create a category budget: Food & Dining, monthly, $400 AUD
- When my Food & Dining spend reaches $320 (80%)
- Then I receive a push notification once (via FCM from NestJS) and the category card turns amber

**US-07** As a traveller, I want a trip budget for a specific date range.
- Given I create a custom budget: 10 Apr–20 Apr, $1,500 AUD
- When 20 Apr passes
- Then the budget deactivates automatically and shows as expired

### Sync

**US-08** As a mobile user, I want to log transactions without internet.
- Given my phone has no internet
- When I add any transaction type
- Then it saves instantly to Drift SQLite with `sync_status = pending`

**US-09** As a user, I want my phone and web to stay in sync.
- Given I added transactions on web while my phone was offline
- When my phone reconnects
- Then the new records appear on my phone within 10 seconds (via `/sync/pull`)

### Google Sheets

**US-10** As a user, I want my expenses mirrored to a Google Sheet automatically.
- Given I have connected my Google account and set up a sheet
- When I add an expense (from mobile or web)
- Then a row appears in the correct monthly tab within 5 seconds (written by NestJS backend)

---

## 23. Non-functional requirements

| Requirement | Target |
|---|---|
| App cold start (mobile) | < 2 seconds on mid-range device |
| Web page load (initial) | < 3 seconds |
| Transaction save (mobile, local Drift) | < 200ms |
| Transaction save (web, NestJS API) | < 500ms |
| Exchange rate API timeout | 5 seconds; fall back to cache |
| Sync on reconnect (mobile) | Within 10 seconds of connectivity restored |
| Google Sheet write latency | < 5 seconds after data reaches NestJS |
| Local data retention (mobile) | Never auto-deleted |
| Cloud data retention | Retained for lifetime of account |
| Offline capability (mobile) | 100% of core features work offline (except Sheet sync) |
| Offline capability (web) | Not supported — online only |
| Auth token storage (mobile) | `flutter_secure_storage` only; no plain text |
| Auth token storage (web) | httpOnly secure cookies |
| GDPR / Privacy | User can export and delete all data from Settings |
| Accessibility | WCAG AA contrast in both themes; supports system text scaling |
| Dark mode | Supported on first release; respects system setting (both platforms) |

---

## 24. Out of scope (v1)

- Receipt photo upload and OCR / photo scanning
- AI-powered spend insights
- Shared expenses / bill splitting
- Bank or credit card import (open banking)
- Multi-currency wallet with live balance tracking (beyond informational running balance)
- Support for more than one Google Sheet per user
- Conflict resolution UI (last-write-wins only in v1)
- Web push notifications (mobile FCM only in v1)
- Tablet-optimised layout
- Additional currencies beyond: AUD, THB, USD, EUR, GBP, JPY, SGD
- Offline support for web app
- Real-time WebSocket sync (polling-based in v1; WebSocket in v2)

---

*End of document — Project PET v3.0 (adapted for DailySpend monorepo)*
