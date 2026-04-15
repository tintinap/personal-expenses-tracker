#!/usr/bin/env bash
# ============================================================
# First-time setup — run once after cloning the repo
# Usage: mise run setup
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▸ $1${NC}"; }
done_msg() { echo -e "${GREEN}✓ $1${NC}"; }

step "1/5 — Copying .env file"
if [ ! -f .env ]; then
  cp .env.example .env
  done_msg ".env created from .env.example"
else
  done_msg ".env already exists, skipping"
fi

step "2/5 — Installing API dependencies"
cd apps/api
pnpm install
cd ../..
done_msg "API dependencies installed"

step "3/5 — Installing Web dependencies"
cd apps/web
pnpm install
cd ../..
done_msg "Web dependencies installed"

step "4/5 — Starting PostgreSQL"
docker compose up db -d --wait
done_msg "PostgreSQL is ready"

step "5/5 — Running Prisma migration"
cd apps/api
npx prisma migrate dev --name init
npx prisma generate
cd ../..
done_msg "Database migrated & Prisma Client generated"

echo ""
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Setup complete!                       ${NC}"
echo -e "${GREEN}  Run: mise run dev                        ${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
