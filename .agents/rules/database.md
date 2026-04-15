---
description: Database standards with Prisma ORM and PostgreSQL
globs: "**/*.{sql,prisma}"
alwaysApply: false
---

# Database Standards

## Core Rules

1. **Prisma as single source of truth**: All schema changes go through `prisma/schema.prisma`
2. **Migrations via Prisma Migrate**: `npx prisma migrate dev` for development, `npx prisma migrate deploy` for production
3. **Never modify migration files after they've been applied**
4. **Use `@@map()` and `@map()`** to keep PostgreSQL column names snake_case while using camelCase in TypeScript
5. **Always add indexes** for frequently queried columns
6. **Use explicit types** via `@db.VarChar()`, `@db.Text`, etc.

## Workflow

```
Edit schema.prisma → prisma migrate dev → prisma generate → commit migration files
```

## Naming Conventions

- Models: `PascalCase` (e.g., `Expense`)
- Table names: `snake_case` via `@@map("expenses")`
- Column names: `snake_case` via `@map("column_name")`
- Migration names: descriptive (e.g., `add_user_auth_fields`)

## Anti-Patterns

- ❌ Never use `db push` in production
- ❌ Never delete migration files from `prisma/migrations/`
- ❌ Never inline raw SQL unless Prisma cannot express the query
- ❌ Never store monetary amounts as `Float` in production (use `Decimal` — current schema uses `Float` for simplicity)
