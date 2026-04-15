# Architecture Recommendation: DailySpend Monorepo Restructure

**Date:** 2026-04-15  
**Type:** Restructure Recommendation  
**Status:** Approved by user request  

---

## 1. Problem Framing

The DailySpend expense tracker needs restructuring to support:
- **Flutter mobile** (iOS/Android cross-platform)
- **Flutter web OR Next.js** for web frontend
- **NestJS** backend (existing)
- **Flyway** for database migrations (replacing TypeORM `synchronize: true`)
- **MISE** for single-command toolchain installation
- **Docker** for running all services

### Current Pain Points
1. No migration tool — `synchronize: true` is dangerous for production
2. No MISE config — each developer installs tools manually
3. Flat project structure — `frontend/` and `backend/` at root with no shared contracts
4. `.agents/rules/frontend.md` describes React/Next.js but codebase is Flutter

---

## 2. Decision: PostgreSQL vs Supabase

### Recommendation: **PostgreSQL (self-hosted in Docker)**

| Criteria | PostgreSQL | Supabase |
|---|---|---|
| **Flyway compatibility** | ✅ Native — Flyway connects directly | ⚠️ Conflict — Supabase has its own migration system |
| **NestJS integration** | ✅ TypeORM/Prisma connect directly | ⚠️ Redundant — Supabase auto-generates REST API that overlaps with NestJS |
| **Cost** | Free (Docker) | Free tier limited; self-hosted requires 8+ containers (Kong, GoTrue, PostgREST, etc.) |
| **Control** | Full — extensions, tuning, backups | Managed — less control over internals |
| **Complexity** | Low — single container | High — multiple services for auth, realtime, storage |
| **Offline/Local dev** | ✅ Simple `docker compose up` | ⚠️ Heavy local setup |

**Verdict:** Supabase adds redundant layers (PostgREST, GoTrue) when you already have NestJS for the API and can handle auth yourself. Flyway requires direct PostgreSQL access, which conflicts with Supabase's managed migration approach. **Stick with PostgreSQL.**

> [!TIP]
> If you later need Supabase features (realtime subscriptions, auth, storage), you can add them incrementally without replacing PostgreSQL — Supabase sits *on top of* PostgreSQL.

---

## 3. Decision: Flutter Web vs Next.js for Web Frontend

### Recommendation: **Flutter Web** (for now)

| Criteria | Flutter Web | Next.js |
|---|---|---|
| **Code sharing with mobile** | ✅ 100% — same codebase | ❌ Separate codebase, duplicated models |
| **Maintenance burden** | Low — one frontend | High — two frontends |
| **SEO** | ❌ Poor (SPA/canvas) | ✅ Excellent (SSR/SSG) |
| **Web performance** | ⚠️ Larger initial bundle | ✅ Smaller, faster FCP |
| **Web-native features** | ⚠️ Limited | ✅ Full access |

**Verdict:** For an expense tracking app (internal tool, not content/SEO-driven), Flutter Web is sufficient and halves your maintenance burden. The monorepo structure below supports adding a Next.js web app later if needed.

---

## 4. Target Monorepo Structure

```
expense_app/
├── .mise.toml                    # Tool versions (Flutter, Node, Java, pnpm)
├── docker-compose.yml            # All services (db, flyway, api, web)
├── .env.example                  # Template for environment variables
├── .env                          # Local overrides (gitignored)
│
├── apps/
│   ├── mobile/                   # Flutter app (mobile + web)
│   │   ├── lib/
│   │   │   ├── core/             # Theme, constants, helpers
│   │   │   ├── data/             # Models, database service (HTTP client)
│   │   │   ├── providers/        # State management (Provider)
│   │   │   ├── screens/          # Screen widgets
│   │   │   ├── services/         # Export, import, exchange rate
│   │   │   ├── widgets/          # Reusable UI components
│   │   │   ├── app.dart
│   │   │   └── main.dart
│   │   ├── pubspec.yaml
│   │   ├── Dockerfile            # Flutter web build → Nginx
│   │   └── ...
│   │
│   └── api/                      # NestJS backend
│       ├── src/
│       │   ├── expenses/         # Feature module (controller/service/repo)
│       │   ├── app.module.ts
│       │   └── main.ts
│       ├── package.json
│       ├── Dockerfile
│       └── ...
│
├── db/
│   ├── flyway.toml               # Flyway config
│   └── migrations/
│       └── sql/
│           └── V1__create_expenses_table.sql
│
└── infra/                        # Future: Terraform, CI/CD
```

### Key Design Decisions

1. **`apps/` directory** — Each deployable unit gets its own folder
2. **`db/` at root** — Flyway migrations are a shared concern, not owned by the API
3. **No `packages/`** — Until a Next.js frontend is added, there's no need for shared TypeScript packages
4. **Dockerfiles colocated** — Each app owns its Dockerfile

---

## 5. MISE Configuration

MISE will manage all SDK/tool versions for local development:

| Tool | Version | Purpose |
|---|---|---|
| `node` | 20 | NestJS backend |
| `pnpm` | 10 | Node package manager |
| `flutter` | 3.29 | Mobile + web frontend |
| `java` | 21 (temurin) | Flyway CLI runtime |

Single install command: `mise install`

---

## 6. Flyway Migration Strategy

### Transition Plan
1. **Disable** `synchronize: true` in TypeORM
2. **Extract** current schema into `V1__create_expenses_table.sql`
3. **Baseline** existing databases with `flyway baseline`
4. **All future changes** via numbered SQL files (`V2__add_xxx.sql`)

### Docker Integration
Flyway runs as a service in `docker-compose.yml`, executing before the API starts:
```yaml
flyway:
  image: flyway/flyway:11
  depends_on:
    db:
      condition: service_healthy
  volumes:
    - ./db/migrations/sql:/flyway/sql
  command: migrate
```

---

## 7. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Git history disrupted by file moves | Medium | Use `git mv` for all moves |
| Import paths break in Flutter | Low | Update `pubspec.yaml` name, fix relative imports |
| Flyway baseline conflict with existing data | Low | Use `flyway baseline` for existing DBs |
| MISE Flutter plugin instability | Low | Pin exact version, document manual fallback |

---

## 8. Execution Plan

1. ✅ Create new directory structure (`apps/mobile/`, `apps/api/`, `db/`)
2. ✅ Move Flutter code from `frontend/` → `apps/mobile/`
3. ✅ Move NestJS code from `backend/` → `apps/api/`
4. ✅ Create `.mise.toml` with all tool versions
5. ✅ Create Flyway config + initial migration SQL
6. ✅ Rewrite `docker-compose.yml` for new structure
7. ✅ Disable TypeORM `synchronize`, configure Flyway-first boot
8. ✅ Update `.gitignore` and `.env.example`
9. ✅ Update `.agents/rules/` to match actual tech stack
