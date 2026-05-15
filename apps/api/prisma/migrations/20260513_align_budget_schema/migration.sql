-- Migration: align backend Budget model with mobile schema v4–v6
-- Changes:
--   Budget: scope→scope_type, categoryId→categoryIds(JSON), +currency,
--           +is_recurring, notified_80→notified_75, +notified_90, +name
--   Category: +icon_code_point

-- ─── Category: add icon_code_point ────────────────────────────────────────────
ALTER TABLE "categories"
  ADD COLUMN IF NOT EXISTS "icon_code_point" INTEGER NOT NULL DEFAULT 0;

-- ─── Budget: add new columns (nullable / defaulted first) ─────────────────────
ALTER TABLE "budgets"
  ADD COLUMN IF NOT EXISTS "name"          VARCHAR(150),
  ADD COLUMN IF NOT EXISTS "category_ids"  TEXT,
  ADD COLUMN IF NOT EXISTS "currency"      VARCHAR(3)  NOT NULL DEFAULT 'AUD',
  ADD COLUMN IF NOT EXISTS "is_recurring"  BOOLEAN     NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS "notified_75"   BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "notified_90"   BOOLEAN     NOT NULL DEFAULT false;

-- Copy old notified_80 value into notified_75 before dropping it
UPDATE "budgets" SET "notified_75" = "notified_80" WHERE "notified_80" IS NOT NULL;

-- ─── Budget: migrate scope values and categoryId → categoryIds ────────────────
-- Drop the FK constraint on category_id before we remove the column
DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT conname INTO cname
  FROM pg_constraint
  WHERE conrelid = 'budgets'::regclass
    AND contype = 'f'
    AND conkey = ARRAY(
      SELECT attnum FROM pg_attribute
      WHERE attrelid = 'budgets'::regclass AND attname = 'category_id'
    );
  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE budgets DROP CONSTRAINT ' || quote_ident(cname);
  END IF;
END$$;

-- Backfill category_ids from the old single category_id column (if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'budgets' AND column_name = 'category_id'
  ) THEN
    UPDATE "budgets"
    SET "category_ids" = '["' || "category_id" || '"]'
    WHERE "category_id" IS NOT NULL AND "category_ids" IS NULL;
  END IF;
END$$;

-- Rename scope → scope_type (only if old column still exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'budgets' AND column_name = 'scope'
  ) THEN
    ALTER TABLE "budgets" RENAME COLUMN "scope" TO "scope_type";
  END IF;
END$$;

-- Migrate old scope values (global→all, category→include)
UPDATE "budgets" SET "scope_type" = 'all'     WHERE "scope_type" = 'global';
UPDATE "budgets" SET "scope_type" = 'include' WHERE "scope_type" = 'category';

-- Drop obsolete columns (safe; IF EXISTS guards against re-runs)
ALTER TABLE "budgets"
  DROP COLUMN IF EXISTS "category_id",
  DROP COLUMN IF EXISTS "notified_80";

-- Make scope_type NOT NULL now that data is migrated
ALTER TABLE "budgets" ALTER COLUMN "scope_type" SET NOT NULL;
