# DailySpend

A production-ready expense tracking application.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter 3.41.7 — iOS & Android |
| Web App | Next.js 16 (App Router, Tailwind, i18n: EN + TH) |
| Backend API | NestJS 11 (TypeScript) |
| Database | PostgreSQL 16 |
| ORM & Migrations | Prisma 6 |
| Containerization | Docker Compose |
| Toolchain | MISE |

## 🚀 Getting Started

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (running)
- [MISE](https://mise.jdx.dev/) (`brew install mise` or `curl https://mise.run | sh`)
- **Flutter 3.41.7+** — required for debug mode on iOS 26+ physical devices (managed automatically via MISE)

### Two commands — that's it

```bash
# First time only — installs Node, pnpm, Flutter, deps, DB, migrations
mise run setup

# Every day — starts PostgreSQL + NestJS + Next.js
mise run dev
```

Once running:

| Service | URL |
|---------|-----|
| **Web App** | http://localhost:3001 |
| **API** | http://localhost:3000/expenses |
| **API Docs (Swagger)** | http://localhost:3000/api/docs |
| **Prisma Studio** | `mise run db-studio` |

Press `Ctrl+C` to stop everything.

### Running Flutter Separately

To run the Flutter mobile app on a simulator or physical device:

```bash
# Ensure a simulator is open, then run:
mise run dev-mobile

# Or manually:
cd apps/mobile && flutter run
```

> **Note for physical device users:** iOS 26+ requires Flutter 3.32+ for debug mode support.
> If prompted to choose a device, select your physical device or the simulator.
> Flutter is managed via MISE (`flutter = "3.44"` in `.mise.toml`) — run `mise install` to upgrade.

---

## 📱 Installing on a Physical iPhone (Step-by-Step)

This guide walks you through **every step** needed to run DailySpend on your own iPhone — even if you've never done this before.

### What You Need Before Starting

| Item | Why You Need It |
|------|----------------|
| A Mac computer | Apple only allows iOS development from macOS |
| An iPhone (iOS 16 or newer) | The device you'll install the app on |
| A USB cable (Lightning or USB-C) | To connect your iPhone to the Mac |
| An **Apple ID** | Free is fine — no paid developer account required for personal testing |
| **Xcode** installed | Download free from the Mac App Store (⚠️ ~12 GB, may take a while) |

### Step 1 — Install Xcode (One-Time)

1. Open the **App Store** on your Mac (blue icon with an "A" in the dock).
2. Search for **Xcode**.
3. Click **Get** → **Install**. Wait for it to finish (this can take 30+ minutes).
4. Once installed, **open Xcode once** and accept the license agreement when prompted.
5. If Xcode asks to install additional components, click **Install** and wait.

### Step 2 — Turn On Developer Mode on Your iPhone

Your iPhone needs "Developer Mode" enabled so it can accept apps installed from your Mac.

1. On your iPhone, open the **Settings** app.
2. Scroll down and tap **Privacy & Security**.
3. Scroll all the way to the bottom — tap **Developer Mode**.
4. Toggle it **ON** (the switch turns green).
5. Your iPhone will ask you to **restart** — tap **Restart**.
6. After the reboot, a popup will appear asking to confirm — tap **Turn On** and enter your passcode.

> **Can't find Developer Mode?** It only appears after you've connected the iPhone to a Mac with Xcode installed at least once. Plug in your phone (Step 3), then come back here.

### Step 3 — Connect Your iPhone to the Mac

1. Plug your iPhone into your Mac using the USB cable.
2. **Unlock your iPhone** (Face ID, Touch ID, or passcode).
3. A popup will appear on your iPhone:

   > **"Trust This Computer?"**

4. Tap **Trust** → Enter your iPhone **passcode**.
5. On your Mac, a popup may appear in **Finder** asking to allow the accessory — click **Allow**.

### Step 4 — Sign In to Xcode with Your Apple ID

1. Open **Xcode** on your Mac.
2. In the top menu bar, click **Xcode** → **Settings…** (or press `⌘ + ,`).
3. Click the **Accounts** tab at the top.
4. Click the **+** button in the bottom-left corner.
5. Select **Apple ID** → click **Continue**.
6. Sign in with your Apple ID email and password.
7. Close the Settings window.

### Step 5 — Open the Project in Xcode

1. Open Terminal (or use the one in your editor).
2. Run this command:

   ```bash
   open apps/mobile/ios/Runner.xcworkspace
   ```

3. Xcode will open with the DailySpend project.

### Step 6 — Select Your iPhone as the Target Device

1. At the very top of the Xcode window, you'll see a toolbar with a **device selector** (it might say "Any iOS Device" or a simulator name).
2. Click it and find your iPhone's name under **Connected Devices** (e.g., "KIRA iPhone" or "Ryu").
3. Select your iPhone.

### Step 7 — Fix Code Signing (First Time Only)

1. In the left sidebar of Xcode, click on **Runner** (the blue icon at the top of the file list).
2. In the center panel, make sure the **Signing & Capabilities** tab is selected.
3. Under **Team**, click the dropdown and select your Apple ID / personal team.
   - It will say something like `Your Name (Personal Team)`.
4. If Xcode shows a **signing error** about the bundle identifier, change the **Bundle Identifier** to something unique:
   - Example: `com.yourname.dailySpend`
   - Just change the `com.projectPET` part to something unique to you.
5. Xcode should now show a ✅ **"Signing Certificate: Apple Development"** message.

### Step 8 — Run the App

**Option A — Using the Terminal (Recommended):**

```bash
cd apps/mobile
flutter run
```

When prompted to choose a device, enter the number next to your iPhone.

> ⚠️ **Important:** Simulators do **not** support `--release` mode. If you're using a simulator, just use `flutter run` without the `--release` flag. Physical devices support both.

**Option B — Using Xcode:**

1. Click the **▶ Play** button in the top-left corner of Xcode.
2. The app will build, install, and launch on your iPhone.

### Step 9 — Trust the Developer on Your iPhone (First Time Only)

The first time you install the app, your iPhone will **block it from opening** and show an error:

> **"Untrusted Developer"**

To fix this:

1. On your iPhone, open **Settings**.
2. Go to **General** → **VPN & Device Management** (or **Profiles & Device Management** on older iOS).
3. Under **Developer App**, you'll see your Apple ID email — tap on it.
4. Tap **Trust "[your Apple ID email]"**.
5. Confirm by tapping **Trust** in the popup.
6. Go back to the home screen and tap the **DailySpend** app icon — it should open now! 🎉

### 🔧 Troubleshooting iPhone Installation

<details>
<summary><strong>❌ "Could not run build/ios/iphoneos/Runner.app on [device]"</strong></summary>

This usually means code signing succeeded but the device didn't accept the install.

**Fix:**
1. Open the project in Xcode: `open apps/mobile/ios/Runner.xcworkspace`
2. Select your iPhone from the device dropdown at the top.
3. Click **Product** → **Run** in the menu bar (or press `⌘ + R`).
4. Xcode will show a more detailed error message to help you fix it.
</details>

<details>
<summary><strong>❌ "Untrusted Developer" when opening the app</strong></summary>

See **Step 9** above — you need to trust the developer profile in iPhone Settings.
</details>

<details>
<summary><strong>❌ iPhone not showing up in Flutter / Xcode</strong></summary>

1. Make sure the iPhone is **unlocked** and the **screen is on**.
2. Unplug the USB cable and plug it back in.
3. If the "Trust This Computer?" dialog appears again, tap **Trust**.
4. Run `flutter devices` to check if the phone is detected.
5. Restart Xcode if needed.
</details>

<details>
<summary><strong>❌ "Developer Mode" is not visible in iPhone Settings</strong></summary>

1. Connect the iPhone to the Mac via USB.
2. Open **Xcode** → **Window** → **Devices and Simulators** (or press `⇧ + ⌘ + 2`).
3. Select your iPhone in the sidebar. Xcode may prompt to "Enable Developer Mode".
4. After this, "Developer Mode" should appear in **Settings → Privacy & Security**.
</details>

<details>
<summary><strong>❌ "Release mode is not supported" on a Simulator</strong></summary>

iOS Simulators only support **debug** and **profile** modes. Use:

```bash
flutter run           # debug (simulator or device)
flutter run --release # release (physical device ONLY)
```
</details>

<details>
<summary><strong>❌ App installs but immediately crashes</strong></summary>

1. Check that the API backend is running: `mise run dev`
2. Check the console logs: run `flutter run` (not `--release`) to see error output.
3. Make sure the API URL in the app points to the correct backend address.
</details>

---

## All MISE Tasks

```bash
# ── Primary ─────────────────────────
mise run setup          # First-time setup (once)
mise run dev            # Start all services (daily)

# ── Individual services ─────────────
mise run dev-api        # NestJS only (port 3000)
mise run dev-web        # Next.js only (port 3001)
mise run dev-mobile     # Flutter mobile

# ── Database ────────────────────────
mise run db-migrate     # Create + apply migration
mise run db-studio      # Database GUI
mise run db-generate    # Regenerate Prisma Client

# ── Docker ──────────────────────────
mise run docker-up      # Docker: db + api + web
mise run docker-up-all  # Docker: + Flutter web (port 8080)
mise run docker-down    # Stop + wipe everything
mise run docker-logs    # Follow all logs
```

## 🧹 Troubleshooting / Resetting

If you ever need to completely reset your database or if you run into environment issues (like Docker container conflicts):

```bash
# 1. Stop all containers and delete database volumes (THIS ERASES YOUR DATA)
mise run docker-down
# OR manually: docker compose down -v 

# 2. Re-run setup to initialize a fresh database
mise run setup
```

## Project Structure

```
expense_app/
├── .mise.toml              # Tool versions + task runner
├── scripts/
│   ├── setup.sh            # First-time setup
│   └── dev.sh              # Start all services
├── docker-compose.yml
│
├── apps/
│   ├── mobile/             # Flutter (iOS & Android)
│   │   ├── lib/
│   │   │   ├── core/       # Theme, constants
│   │   │   ├── data/       # Models, API client
│   │   │   ├── providers/  # State (Provider)
│   │   │   ├── screens/    # Pages
│   │   │   ├── services/   # Export, import, FX rates
│   │   │   └── widgets/    # Reusable components
│   │   └── pubspec.yaml
│   │
│   ├── web/                # Next.js (web frontend)
│   │   ├── messages/       # i18n (en.json, th.json)
│   │   └── src/
│   │       ├── app/[locale]/   # Locale routes (/en, /th)
│   │       ├── i18n/           # next-intl config
│   │       └── proxy.ts        # Locale detection
│   │
│   └── api/                # NestJS (backend)
│       ├── prisma/
│       │   └── schema.prisma   # DB schema (source of truth)
│       └── src/
│           ├── prisma/         # PrismaService
│           └── expenses/       # Controller → Service → Repository
│
└── .agents/rules/          # AI coding rules
```

## i18n (Web)

- **Locales**: English (`en`), Thai (`th`)
- **URLs**: `/en/dashboard`, `/th/dashboard`
- **Add language**: Create `messages/[locale].json` + update `src/i18n/config.ts`

## Features

- **Dashboard**: Filter by Weekly/Fortnightly/Monthly/Yearly, pie chart, net total
- **Spreadsheet**: Pivot-style view (categories × time periods)
- **Settings**: Theme, Display Currency, Import/Export Excel
- **Multi-currency**: Per-transaction currency, converted via Frankfurter (ECB rates)

---

## 📊 Implementation Progress

> [!IMPORTANT]
> **Current Usability Status:**
> **Mobile** is the primary production path (offline-first + sync). **Backend** APIs for auth/sync/sheets/notifications are in place. **Web** now talks to the NestJS API for core pages, but browser OAuth SDK wiring and full chart/import polish still need production env credentials and UAT.
>
> See [remaining-tasks.md](docs/exec-plans/active/remaining-tasks.md) and PRD v5.2.0 for detailed status.

### 📱 Mobile App (Flutter) — 🟡 ~95%
* **Implemented:**
  - [x] Core Dashboard, Transaction details, & Category breakdowns
  - [x] Transaction bottom sheet editor with recurring toggle
  - [x] Wallets screen with per-currency breakdown and totals
  - [x] Background engine for generating recurring transaction instances
  - [x] Real sync push/pull with Drift last-write-wins merge + reconnect trigger
  - [x] FCM token register/unregister on sign-in/sign-out
  - [x] Recurring templates management UI (pause/delete) in Settings
  - [x] Manual balance adjustment on currency wallet detail
* **Pending:**
  - [ ] Device-level FCM delivery UAT with real Firebase credentials

### 🖥️ Backend API (NestJS) — 🟡 ~95%
* **Implemented:**
  - [x] Prisma ORM and PostgreSQL migrations
  - [x] Core Authentication structure (JWT)
  - [x] Transactions, Categories, and Budgets REST API endpoints
  - [x] Excel Import/Export parsers and Google Sheets background worker queue
  - [x] Automated Frankfurter FX rate scheduler
  - [x] Sheets status/disconnect contract aliases for clients
  - [x] Notifications `fcm-token` register/unregister aliases
  - [x] Sync push enqueues Sheets writes when Sheets is enabled
* **Pending:**
  - [ ] Google OAuth and Firebase production credentials (env-gated graceful fallback today)

### 🌐 Web App (Next.js) — 🟡 ~60%
* **Implemented:**
  - [x] Sidebar navigation layout and multi-page routing structure
  - [x] App router-based i18n support for English (`en`) and Thai (`th`) locales
  - [x] Auth context calling NestJS `/auth/google`, `/auth/apple`, `/auth/refresh`
  - [x] Dashboard / Transactions / Wallets / Budgets / Reports / Settings / Import wired to API
  - [x] Vitest request-helper unit test stack
* **Pending:**
  - [ ] Browser OAuth SDK token acquisition (`@react-oauth/google` / Apple web flow)
  - [ ] Full Recharts visualizations and PRD §25 import badge/mapping polish
  - [ ] Production env values (`NEXT_PUBLIC_API_URL`, OAuth client IDs)

