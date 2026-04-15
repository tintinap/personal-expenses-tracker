#!/usr/bin/env bash
# ============================================================
# Start all services — one command for daily development
# Usage: mise run dev
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Start Database ──────────────────────────────
echo -e "${BLUE}▸ Starting PostgreSQL...${NC}"
docker compose up db -d --wait 2>/dev/null
echo -e "${GREEN}✓ PostgreSQL ready (port 5432)${NC}"

# ── Apply any pending migrations ────────────────
echo -e "${BLUE}▸ Applying database migrations...${NC}"
cd apps/api
npx prisma migrate deploy 2>/dev/null || npx prisma migrate dev --name auto 2>/dev/null
cd ../..
echo -e "${GREEN}✓ Migrations applied${NC}"

# ── Start Services ────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🚀 DailySpend is starting!                  ${NC}"
echo -e "${GREEN}                                               ${NC}"
echo -e "${GREEN}  Web:    http://localhost:3001                 ${NC}"
echo -e "${GREEN}  API:    http://localhost:3000/expenses        ${NC}"
echo -e "${GREEN}  DB:     localhost:5432                        ${NC}"
echo -e "${GREEN}  Mobile: Outputting Flutter logs               ${NC}"
echo -e "${GREEN}                                               ${NC}"
echo -e "${GREEN}  Press Ctrl+C to stop all services.           ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""

# Use concurrently to run them together with prefixed logs in the foreground
# --kill-others ensures if one crashes, they all cleanly stop.
# --handle-input allows you to type into the terminal (needed for Flutter 'r' to reload).
pnpm dlx concurrently --kill-others --handle-input \
  --names "API,WEB" \
  --prefix-colors "blue,green" \
  "cd apps/api && pnpm run start:dev" \
  "cd apps/web && pnpm run dev --port 3001"
  # To re-enable Mobile (Flutter), change names to "API,WEB,MOB", colors to "blue,green,magenta",
  # and add this line inside the command above: "cd apps/mobile && flutter run -d chrome"

