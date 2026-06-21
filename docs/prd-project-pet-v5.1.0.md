# Product Requirements Document

## Project PET — Personal Expense Tracker (Monorepo)

**Version:** 5.1.0
**Last updated:** 21 June 2026
**Status:** Active

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals &amp; success metrics](#2-goals--success-metrics)
3. [Target users](#3-target-users)
4. [Platform &amp; tech stack](#4-platform--tech-stack)
5. [App architecture overview](#5-app-architecture-overview)
6. [Screen map &amp; navigation](#6-screen-map--navigation)
7. [Authentication &amp; account model](#7-authentication--account-model)
8. [Expense entry &amp; management](#8-expense-entry--management)
9. [Categories](#9-categories)
10. [Currency handling](#10-currency-handling)
11. [Currency income &amp; exchange events](#11-currency-income--exchange-events)
12. [Time period views](#12-time-period-views)
13. [Budget alerts](#13-budget-alerts)
14. [Visualisation dashboard](#14-visualisation-dashboard)
15. [Offline-first sync architecture](#15-offline-first-sync-architecture)
16. [Google Sheets integration](#16-google-sheets-integration)
17. [Excel export](#17-excel-export)
18. [Theming (light &amp; dark mode)](#18-theming-light--dark-mode)
19. [Error states &amp; edge cases](#19-error-states--edge-cases)
20. [Data models](#20-data-models)
21. [Riverpod providers](#21-riverpod-providers)
22. [User stories &amp; acceptance criteria](#22-user-stories--acceptance-criteria)
23. [Non-functional requirements](#23-non-functional-requirements)
24. [Out of scope (v1)](#24-out-of-scope-v1)
25. [Excel Import](#25-excel-import)
26. [View Currency Display Improvements (v5.1.0)](#26-view-currency-display-improvements-v510)

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

| Metric                              | Target                                                  |
| ----------------------------------- | ------------------------------------------------------- |
| Time to log one expense             | < 10 seconds                                            |
| Offline entry → sync on reconnect  | 100% of pending records synced                          |
| Budget alert delivery               | Fires once at 75%, once at 90%, once at 100% per period |
| Google Sheet write latency (online) | < 5 seconds after sync to backend                       |
| App cold start (mobile)             | < 2 seconds on mid-range device                         |
| Web page load (initial)             | < 3 seconds                                             |
| Crash rate                          | < 0.5% of sessions                                      |

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

| App         | Technology                                       | Location         |
| ----------- | ------------------------------------------------ | ---------------- |
| Mobile      | Flutter (iOS & Android)                          | `apps/mobile/` |
| Web         | Next.js 16 (App Router, Tailwind, i18n: EN + TH) | `apps/web/`    |
| Backend API | NestJS 11 (TypeScript)                           | `apps/api/`    |

### Mobile app stack

| Layer            | Choice                                    | Notes                                                  |
| ---------------- | ----------------------------------------- | ------------------------------------------------------ |
| Framework        | Flutter                                   | iOS & Android from one codebase                        |
| Local database   | **SQLite via `drift`**            | Source of truth on device; offline-first               |
| State management | **Riverpod**                        | `flutter_riverpod` + `riverpod_annotation`         |
| Navigation       | **`go_router`**                   | Declarative routing with `ShellRoute` for bottom nav |
| HTTP             | **`dio`**                         | With interceptors for auth (JWT) + retry               |
| Secure storage   | `flutter_secure_storage`                | JWT tokens only                                        |
| Exchange rates   | Frankfurter API (`api.frankfurter.app`) | Free, ECB-backed, no API key required                  |

### Backend API stack

| Layer              | Choice                           | Notes                                               |
| ------------------ | -------------------------------- | --------------------------------------------------- |
| Framework          | NestJS 11                        | TypeScript, modular                                 |
| ORM                | **Prisma 6**               | PostgreSQL schema management + migrations           |
| Database           | **PostgreSQL 16**          | Cloud source of truth                               |
| Auth               | **Passport.js + JWT**      | `@nestjs/passport` + `@nestjs/jwt`              |
| OAuth providers    | Google OAuth 2.0 + Apple Sign-In | Via Passport strategies                             |
| Google Sheets      | Google Sheets API v4             | Server-side mirror; backend writes to Sheet on sync |
| Push notifications | Firebase Cloud Messaging (FCM)   | Budget alerts (mobile only, v1)                     |

### Web app stack

| Layer     | Choice                           | Notes                            |
| --------- | -------------------------------- | -------------------------------- |
| Framework | Next.js 16                       | App Router, server components    |
| Styling   | Tailwind CSS                     | Same design tokens as mobile     |
| i18n      | `next-intl`                    | EN + TH locales                  |
| HTTP      | Fetch API                        | Calls NestJS API directly        |
| Auth      | JWT (stored in httpOnly cookies) | Received from NestJS after OAuth |

### Infrastructure

| Layer            | Choice         | Notes                                |
| ---------------- | -------------- | ------------------------------------ |
| Containerisation | Docker Compose | PostgreSQL + NestJS + Next.js        |
| Toolchain        | MISE           | `mise run setup`, `mise run dev` |

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

Bottom navigation bar with 4 tabs using `ShellRoute` and a notched center FAB. Persists across the app. Hidden only when add/edit sheets are open.

| Tab index | Label           | Icon                                | Route                             |
| --------- | --------------- | ----------------------------------- | --------------------------------- |
| 0         | Home            | `home_outlined`                   | `/`                             |
| 1         | Wallets         | `account_balance_wallet_outlined` | `/wallets`                      |
| —        | *(FAB notch)* | `add`                             | *(opens Add Transaction sheet)* |
| 2         | Budgets         | `savings_outlined`                | `/budgets`                      |
| 3         | Reports         | `bar_chart`                       | `/reports`                      |

A floating `+` FAB sits in the centre notch of the `BottomAppBar` and opens the Add Transaction bottom sheet.

**Settings access:** A gear icon (`settings_outlined`) in the **top-right corner of the AppBar** on all primary screens provides access to Settings. Settings is **not** a bottom navigation tab.

### Navigation structure (web — Next.js App Router)

Sidebar navigation (desktop) / hamburger menu (mobile viewport). Same four sections as mobile.

| Section          | Route                   |
| ---------------- | ----------------------- |
| Dashboard (Home) | `/[locale]/dashboard` |
| Wallets          | `/[locale]/wallets`   |
| Reports          | `/[locale]/reports`   |
| Budgets          | `/[locale]/budgets`   |
| Settings         | `/[locale]/settings`  |

### Screen inventory

#### Home (`/`)

- Period selector (segmented control: Daily / Weekly / Fortnightly / Monthly / Yearly)
- Period navigation (← label →, tap label to date-pick)
- Summary cards: **base currency** total spent (primary), view currency equivalent below in smaller text (secondary, hidden when base == view)
- Top category card: category name (primary), base currency amount spent (secondary)
- Currency balance bar: horizontal scrollable chips showing each currency balance (tappable → opens Currency Wallets screen)
- Expense list for selected period (grouped by date)
- Each expense row: category colour dot, category name, note (truncated), original amount; **view currency estimate** shown underneath if currencies differ and a cached rate is available
- Swipe-left on row: delete (with confirmation); swipe-right: edit
- Donut chart: shows **base currency only** (no view currency overlay on home screen)

#### Add/Edit Expense (bottom sheet on mobile, modal on web)

- Auto-focuses amount field on open
- Fields: Amount, Currency (picker, defaults to last used), Date (defaults to today), Time (defaults to current time, follows system 12h/24h format), Category (picker), Note (optional, max 200 chars)
- "Save" button — disabled until Amount and Category are filled
- Shows converted base currency equivalent below amount field in real time

#### Transaction Detail (bottom sheet — tap any row in the transaction list)

- Opened by tapping a transaction row in any list (Home, Currency Detail, Reports, etc.)
- Shows all transaction fields in a read-only detail view inside a bottom sheet
- **No Edit or Delete action buttons** — these are accessed via swipe on the list tile
- **Sync status badge** (`pending` / `synced` / `conflict`) — mobile only, shown prominently near the top
- Shows whether exchange rate was estimated (offline) with an "Estimated rate" label
- **View currency estimate** shown next to the amount if view currency differs from base currency, including the conversion rate used (e.g. `≈ + THB 1,234.56 (1 AUD = 24.50 THB)`)
- For exchange transactions: shows both sides of the linked pair

#### Dashboard Detail (tap "Spend by Category" →)

- Full-screen donut + expanded category breakdown
- Summary cards (Total Spent, Net Income, Top Category) show **base currency** as primary value and **view currency** as secondary (≈ prefix) when base ≠ view
- Donut chart now shows **all currencies** (not filtered to base currency), with optional view currency overlay

#### Reports (`/reports`)

- Same period selector as Home
- Donut chart: spend by category — shows **base currency** with view currency overlay beneath center value when base ≠ view
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
- Full progress breakdown (percentage, spent, remaining, progress bar)
- Configuration section: period mode, recurring toggle, scope, categories, current period dates
- **Period history** (recurring budgets only): inline scrollable list of all past completed periods showing date range, amount spent, limit, and percentage — most recent first

#### Settings (`/settings` — accessed via gear icon in AppBar, not bottom nav)

- Account section: sign-in status (Google or Apple), sign out, delete account
- Google Sheets section: connect/disconnect (only available for Google accounts), linked sheet name
- Export section: "Export as Excel (.xlsx)" button — available to all signed-in users and local-mode users
- Preferences: base currency picker (default: AUD, changeable to any supported currency), view currency toggle, dark mode toggle
- Categories: manage default + custom categories
- About: version, licenses

#### Currency Wallets (`/wallets`)

- Overview card: **total portfolio value** — sum of all currency balances converted to base currency using today's rate; view currency equivalent shown in smaller text below when base ≠ view
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

| Feature                | Local mode (mobile) | Apple Sign-In | Google Sign-In |
| ---------------------- | ------------------- | ------------- | -------------- |
| Expense logging        | ✅                  | ✅            | ✅             |
| Offline-first (mobile) | ✅                  | ✅            | ✅             |
| Cloud sync (NestJS)    | ❌                  | ✅            | ✅             |
| Cross-device sync      | ❌                  | ✅            | ✅             |
| Web app access         | ❌                  | ✅            | ✅             |
| Google Sheets mirror   | ❌                  | ❌            | ✅             |
| Excel export           | ✅                  | ✅            | ✅             |
| Budget alerts (FCM)    | ✅                  | ✅            | ✅             |

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
│   └── jwt-auth.guard.ts      # Protects authenticated routes (JwtAuthGuard)
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

| Field    | Type                     | Required | Default                      | Notes                                                                         |
| -------- | ------------------------ | -------- | ---------------------------- | ----------------------------------------------------------------------------- |
| Amount   | Decimal input            | Yes      | Empty                        | Auto-focused on sheet open                                                    |
| Currency | Picker                   | Yes      | Last used (or base currency) | Shows ISO code + flag                                                         |
| Date     | Date picker              | Yes      | Today                        | Can be backdated or set to a future date                                      |
| Time     | Time picker (input mode) | Yes      | Current time                 | Follows system 12h (AM/PM) or 24h format; opens in text-input mode by default |
| Category | Picker                   | Yes      | Last used                    | From active categories                                                        |
| Note     | Text field               | No       | Empty                        | Max 200 chars                                                                 |

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

| Category              | Colour hex  |
| --------------------- | ----------- |
| Food & dining         | `#378ADD` |
| Groceries             | `#4CAF50` |
| Transport             | `#FF7043` |
| Health & medical      | `#E91E8C` |
| Shopping & retail     | `#9C27B0` |
| Bills & utilities     | `#009688` |
| Entertainment         | `#FFC107` |
| Travel                | `#FF8F00` |
| Subscriptions         | `#F44336` |
| Education             | `#455A64` |
| Personal care         | `#4FC3F7` |
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

**Changing base currency:** When the user changes their base currency (e.g. AUD → THB), all existing `amount_base` values are re-converted from `original_amount` + `original_currency` using the latest Frankfurter rate for each transaction's date. This is a background operation; a progress indicator is shown. The exchange rate cache is also updated for the new base currency. On app startup, a background `recalculateBaseAmounts` pass is also run to ensure consistency.

### Exchange rate source

**Frankfurter API** (`https://api.frankfurter.app`) — free, no API key, ECB-backed

| Use case        | Consumer                          | Endpoint                                                 |
| --------------- | --------------------------------- | -------------------------------------------------------- |
| Today's rate    | Mobile (direct) or NestJS (proxy) | `GET /latest?from={currency}&to={base_currency}`       |
| Historical rate | Mobile (direct) or NestJS (proxy) | `GET /{YYYY-MM-DD}?from={currency}&to={base_currency}` |

**NestJS exchange rate module**: The backend also caches exchange rates in PostgreSQL. When the mobile app syncs a transaction with a rate, the backend stores it. The web app fetches rates from the NestJS API (which proxies/caches Frankfurter).

### Caching strategy

**Mobile (Drift/SQLite):**

1. On first use of a currency pair on a given date → fetch from Frankfurter → cache in local `exchange_rates` table
2. Same pair + same date → use cached rate (no API call)
3. New day → fetch fresh rate and cache
4. API timeout (5s) or offline → use last known cached rate → set `rate_estimated = true`

New in v5.1.0: A **DB-only cache lookup** (`getForDateOrRecent`) is available for UI display purposes. This returns `null` instead of the 1.0 fallback when no rate is cached, allowing the UI to hide view currency estimates rather than showing a misleading 1:1 conversion.

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
- **Summary cards and totals** display the base currency amount as the primary value, with the view currency equivalent beneath in smaller text (hidden when base == view)
- **Transaction list tiles** display the view currency estimate beneath the original amount, using the **historical cached rate for the transaction's date** (not today's rate); hidden if no rate is cached
- **Donut chart center** on the Home screen shows **base currency only** (no view currency overlay)
- **Donut chart center** on the Reports screen shows base currency with view currency below when base ≠ view
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
- [ ] Transaction list tile view estimate uses historical cached rate at transaction date; hidden if rate unavailable
- [ ] Summary cards show base currency primary, view currency secondary (≈ prefix)
- [ ] When base == view, no secondary row is shown anywhere

---

## 11. Currency income & exchange events

This section covers two new transaction types that sit alongside expenses in the ledger:

1. **Currency income** — user receives foreign cash (e.g. withdraws 20,000 THB from an ATM). Records that the user now holds that foreign currency but has not yet spent or exchanged it.
2. **Currency exchange** — user converts one currency to another at a money changer or bank (e.g. 20,000 THB → AUD). Records the conversion, the actual rate received, and auto-logs a base currency income entry when applicable.

### Why a separate transaction type (not an expense)

These events are not spending — they are balance movements. Treating them as expenses would inflate spending totals and distort budgets. They must be visually distinct but live in the **same chronological list** as expenses so the user has a single unified ledger view.

### Transaction type taxonomy

| Type                    | `transaction_type` value | Effect on ledger                                                                       |
| ----------------------- | -------------------------- | -------------------------------------------------------------------------------------- |
| Expense                 | `expense`                | Reduces base currency balance                                                          |
| Currency income         | `currency_income`        | Records foreign currency received; no base currency spending impact                    |
| Currency exchange (out) | `currency_exchange_out`  | Reduces source currency balance                                                        |
| Currency exchange (in)  | `currency_exchange_in`   | Increases target currency balance; auto-logged as base currency income when applicable |

---

### 11a. Currency income

#### What it represents

User received foreign currency cash. Example: just landed in Bangkok, withdrew 20,000 THB from ATM.

#### Entry fields

| Field    | Type                     | Required | Notes                                                   |
| -------- | ------------------------ | -------- | ------------------------------------------------------- |
| Amount   | Decimal                  | Yes      | Amount received in foreign currency                     |
| Currency | Picker                   | Yes      | The currency received (e.g. THB)                        |
| Date     | Date picker              | Yes      | Defaults to today; future dates allowed                 |
| Time     | Time picker (input mode) | Yes      | Defaults to current time; follows system 12h/24h format |
| Source   | Text                     | No       | e.g. "ATM withdrawal", "Gift from friend"               |
| Note     | Text                     | No       | Max 200 chars                                           |

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

#### Dashboard income totals

`currency_income` transactions are included in the Net Income summary. `currency_exchange_in` transactions are **excluded** from income totals to avoid double-counting exchange events.

---

### 11b. Currency exchange

#### What it represents

User physically exchanges currency at a money changer, bank, or airport booth.
Example: exchange 15,000 THB → AUD and receive A$620 at the counter.

#### Entry fields

| Field         | Type                     | Required | Notes                                                       |
| ------------- | ------------------------ | -------- | ----------------------------------------------------------- |
| From amount   | Decimal                  | Yes      | Amount given away (e.g. 15,000)                             |
| From currency | Picker                   | Yes      | Source currency (e.g. THB)                                  |
| To amount     | Decimal                  | Yes      | Amount received (e.g. 620)                                  |
| To currency   | Picker                   | Yes      | Target currency (e.g. AUD)                                  |
| Date          | Date picker              | Yes      | Defaults to today; future dates allowed                     |
| Time          | Time picker (input mode) | Yes      | Defaults to current time; follows system 12h/24h format     |
| Exchange rate | Calculated / editable    | Yes      | Auto-filled as `to_amount ÷ from_amount`; always visible |
| Rate source   | Toggle                   | Yes      | "Custom (what I got)" or "Use Frankfurter rate"             |
| Note          | Text                     | No       | e.g. "Superrich exchange booth"                             |

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

| Record             | `transaction_type`      | Effect                                                                     |
| ------------------ | ------------------------- | -------------------------------------------------------------------------- |
| Exchange out       | `currency_exchange_out` | Reduces `from_currency` running balance (e.g. THB −15,000)              |
| Exchange in (auto) | `currency_exchange_in`  | Increases `to_currency` running balance (e.g. AUD +620); shown as income |

Both records share the same `exchange_event_id` UUID so they display together and delete together.

#### Import: exchange rate calculation

When importing exchange transactions from Excel, the `amount_base` for both the OUT and IN sides is now correctly computed by looking up the cached exchange rate (`originalCurrency → baseCurrency`) at the transaction date (falling back to most-recently-cached rate). Previously both sides were stored with a hardcoded 1.0 rate.

---

## 12. Time period views

*(unchanged from v5.0.4)*

---

## 13. Budget alerts

*(unchanged from v5.0.4)*

---

## 14. Visualisation dashboard

### Home screen summary cards

The three coloured summary cards at the top of the Home screen display:

| Card          | Primary value                           | Secondary value                         |
|---------------|-----------------------------------------|-----------------------------------------|
| Total Spent   | `{baseCurrency} {amount}` (bold)        | `≈ {viewCurrency} {amount}` (small, hidden when base == view) |
| Net Income    | `{baseCurrency} {amount}` (bold)        | `≈ {viewCurrency} {amount}` (small, hidden when base == view) |
| Top Category  | Category name (bold)                    | `≈ {viewCurrency} {amount}` (small, hidden when base == view) |

Summary totals are computed from `amountBase` across **all** transaction currencies (multi-currency support), not restricted to base-currency-only transactions.

### Net Income calculation

Net Income = sum of `currency_income` transactions' `amountBase` − sum of `expense` transactions' `amountBase`.

**`currency_exchange_in` transactions are excluded from income totals** to avoid double-counting.

### Donut chart (Home screen)

- Center label: `Total\n{baseCurrency} {amount}` — **base currency only**, no view currency overlay
- Category slices show percentage of total spend

### Donut chart (Dashboard Detail / Reports)

- Center label: `Total\n{baseCurrency} {amount}` — primary
- When base ≠ view: `≈ {viewCurrency} {amount}` beneath (secondary, smaller font)
- Category slices unchanged

### Dashboard Detail summary cards

The Dashboard Detail screen (accessed by tapping "Spend by Category →") includes the same base + view dual-display pattern as the home summary cards.

---

## 15. Offline-first sync architecture

*(unchanged from v5.0.4)*

---

## 16. Google Sheets integration

*(unchanged from v5.0.4)*

---

## 17. Excel export

*(unchanged from v5.0.4)*

---

## 18. Theming (light & dark mode)

*(unchanged from v5.0.4)*

---

## 19. Error states & edge cases

*(unchanged from v5.0.4)*

---

## 20. Data models

*(unchanged from v5.0.4)*

---

## 21. Riverpod providers

### New providers (v5.1.0)

#### `txViewAmountProvider` (FutureProvider.family)

```dart
typedef _TxViewKey = ({
  String fromCurrency,
  String toCurrency,
  String dateKey, // "yyyy-MM-dd"
  double originalAmount,
});

final txViewAmountProvider =
    FutureProvider.family<double?, _TxViewKey>((ref, args) async { ... });
```

**Purpose:** Computes the view currency equivalent of a single transaction's `originalAmount` using a **DB-only cached rate** for the transaction's date. Returns `null` when no rate is cached — callers must hide the display row when null.

**Key behaviour:**
- Looks up `fromCurrency → toCurrency` rate for `dateKey` in the local SQLite cache
- Falls back to the most-recent cached rate for that pair (still DB-only, no network)
- Returns `null` if no rate exists in the cache at all
- Never makes a network request (safe to call on every list tile)

#### `ExchangeRateDao.getForDateOrRecent` (new DAO method)

```dart
Future<double?> getForDateOrRecent(String baseCurrency, String quoteCurrency, DateTime date)
```

**Purpose:** DB-only rate lookup returning `null` (not a 1.0 fallback) when nothing is cached. Used exclusively by `txViewAmountProvider`.

---

## 22. User stories & acceptance criteria

*(unchanged from v5.0.4)*

---

## 23. Non-functional requirements

*(unchanged from v5.0.4)*

---

## 24. Out of scope (v1)

*(unchanged from v5.0.4)*

---

## 25. Excel Import

*(unchanged from v5.0.4)*

---

## 26. View Currency Display Improvements (v5.1.0)

This section documents the view currency UI changes introduced in v5.1.0.

### Problem statement

Prior to v5.1.0:

1. **Incorrect view estimate on transaction tiles**: When base == view (e.g. both AUD), a foreign-currency transaction (e.g. 500 THB) would show `≈ AUD 500.00` because the code used `amountBase * viewRate` where `amountBase` was stored with a 1:1 fallback rate and `viewRate = 1.0`. This was misleading.
2. **Missing `≈` prefix**: Some secondary currency rows used `=` instead of the approximation symbol `≈`.
3. **Dashboard totals inconsistency**: Summary card totals showed the view currency as the primary value; base currency was not always clearly differentiated.
4. **Donut chart center**: The home screen donut chart showed view currency below the base currency, crowding the center hole.
5. **Income calculation**: `currency_exchange_in` was incorrectly included in Net Income totals, inflating them.

### Solution

| Component | Change |
|-----------|--------|
| `ExchangeRateDao` | Added `getForDateOrRecent()` — DB-only lookup, returns `null` if uncached |
| `shared_providers.dart` | Added `txViewAmountProvider` (FutureProvider.family) for per-transaction historical-rate conversion |
| `transaction_list_tile.dart` | Uses `txViewAmountProvider`; hides `≈` row when `viewAmount == null`; replaced `=` with `≈` |
| `dashboard_summary_cards.dart` | Base currency shown as primary value (bold, large); view currency as secondary (`≈`, smaller) |
| `wallets_screen.dart` | Total Net Worth card shows base currency primary, view currency secondary |
| `category_donut_chart.dart` | Added `showViewCurrency` flag; home screen sets it to `false` |
| `home_screen.dart` | `CategoryDonutChart(showViewCurrency: false)` — donut center shows base currency only |
| `dashboard_detail_screen.dart` | Summary cards show base primary + view secondary; donut shows all currencies (no currency filter) |
| `shared_providers.dart` | `currency_exchange_in` removed from income totals to prevent double-counting |
| `import_provider.dart` | Exchange transaction import now correctly computes `amountBase` using cached rates for both OUT and IN sides |
| `transaction_detail_sheet.dart` | View currency estimate row added with rate label (e.g. `≈ + THB 1,234.56 (1 AUD = 24.50 THB)`) |
| `period_comparison_card.dart` | View currency shown as secondary below base currency totals |

### Behaviour rules

1. **`≈` symbol** is used universally for all view/estimated currency conversions
2. **View currency secondary row** is hidden whenever `fromCurrency == viewCurrency`
3. **Transaction tile view estimate** uses historical cached rate (at transaction date, DB-only); hidden when no rate is cached
4. **Summary totals** use `amountBase` for multi-currency accuracy (base currency equivalent stored at save time)
5. **Donut chart at Home** — base currency only, no view overlay
6. **Donut chart at Reports/Dashboard Detail** — base primary, view secondary when base ≠ view

---

*End of document — Project PET v5.1.0 (adapted for DailySpend monorepo)*
