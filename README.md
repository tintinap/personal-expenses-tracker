# DailySpend

A production-ready expense tracking application.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter 3.29 — iOS & Android |
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
| **Prisma Studio** | `mise run db-studio` |

Press `Ctrl+C` to stop everything.

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
