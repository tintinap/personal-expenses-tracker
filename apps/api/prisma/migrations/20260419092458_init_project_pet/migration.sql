/*
  Warnings:

  - You are about to drop the `expenses` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "expenses";

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "display_name" VARCHAR(100) NOT NULL,
    "avatar_url" TEXT,
    "base_currency" VARCHAR(3) NOT NULL DEFAULT 'AUD',
    "auth_provider" VARCHAR(10) NOT NULL,
    "provider_id" VARCHAR(255) NOT NULL,
    "google_refresh_token" TEXT,
    "sheets_spreadsheet_id" TEXT,
    "sheets_enabled" BOOLEAN NOT NULL DEFAULT false,
    "fcm_token" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transactions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "transaction_type" VARCHAR(25) NOT NULL,
    "amount_base" DECIMAL(12,4) NOT NULL,
    "original_amount" DECIMAL(12,4) NOT NULL,
    "original_currency" VARCHAR(3) NOT NULL,
    "exchange_rate" DECIMAL(10,6) NOT NULL,
    "rate_date" DATE NOT NULL,
    "rate_estimated" BOOLEAN NOT NULL DEFAULT false,
    "rate_source" VARCHAR(15) NOT NULL DEFAULT 'frankfurter',
    "exchange_event_id" UUID,
    "category_id" UUID,
    "note" TEXT,
    "source_label" TEXT,
    "transaction_date" DATE NOT NULL,
    "is_recurring" BOOLEAN NOT NULL DEFAULT false,
    "recurrence_type" VARCHAR(12),
    "deleted_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "colour_hex" VARCHAR(7) NOT NULL,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "is_hidden" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "budgets" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "scope" VARCHAR(10) NOT NULL,
    "category_id" UUID,
    "amount_base" DECIMAL(12,2) NOT NULL,
    "period_type" VARCHAR(12) NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "notified_80" BOOLEAN NOT NULL DEFAULT false,
    "notified_100" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "budgets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exchange_rates" (
    "id" UUID NOT NULL,
    "base_currency" VARCHAR(3) NOT NULL,
    "quote_currency" VARCHAR(3) NOT NULL,
    "rate" DECIMAL(10,6) NOT NULL,
    "rate_date" DATE NOT NULL,
    "fetched_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" VARCHAR(20) NOT NULL DEFAULT 'frankfurter',

    CONSTRAINT "exchange_rates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "currency_balances" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "balance" DECIMAL(12,4) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "currency_balances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conflict_log" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "record_type" VARCHAR(20) NOT NULL,
    "record_id" UUID NOT NULL,
    "winning_version" JSONB NOT NULL,
    "losing_version" JSONB NOT NULL,
    "resolved_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "conflict_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "transactions_user_id_transaction_date_idx" ON "transactions"("user_id", "transaction_date" DESC);

-- CreateIndex
CREATE INDEX "transactions_user_id_transaction_type_idx" ON "transactions"("user_id", "transaction_type");

-- CreateIndex
CREATE INDEX "transactions_exchange_event_id_idx" ON "transactions"("exchange_event_id");

-- CreateIndex
CREATE INDEX "categories_user_id_idx" ON "categories"("user_id");

-- CreateIndex
CREATE INDEX "budgets_user_id_idx" ON "budgets"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "exchange_rates_base_currency_quote_currency_rate_date_key" ON "exchange_rates"("base_currency", "quote_currency", "rate_date");

-- CreateIndex
CREATE UNIQUE INDEX "currency_balances_user_id_currency_key" ON "currency_balances"("user_id", "currency");

-- CreateIndex
CREATE INDEX "conflict_log_user_id_idx" ON "conflict_log"("user_id");

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budgets" ADD CONSTRAINT "budgets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budgets" ADD CONSTRAINT "budgets_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "currency_balances" ADD CONSTRAINT "currency_balances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "conflict_log" ADD CONSTRAINT "conflict_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
