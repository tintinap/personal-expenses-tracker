-- CreateTable
CREATE TABLE "expenses" (
    "id" VARCHAR(255) NOT NULL,
    "amount" DOUBLE PRECISION NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "category_index" INTEGER NOT NULL,
    "note" TEXT,
    "is_income" BOOLEAN NOT NULL DEFAULT false,
    "currency_code" VARCHAR(10) NOT NULL DEFAULT 'USD',

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "expenses_date_idx" ON "expenses"("date" DESC);
