import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { CategoriesModule } from './categories/categories.module';
import { TransactionsModule } from './transactions/transactions.module';
import { BudgetsModule } from './budgets/budgets.module';
import { ExchangeRatesModule } from './exchange-rates/exchange-rates.module';
import { SyncModule } from './sync/sync.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SheetsModule } from './sheets/sheets.module';
import { ExportModule } from './export/export.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    CategoriesModule,
    TransactionsModule,
    BudgetsModule,
    ExchangeRatesModule,
    SyncModule,
    NotificationsModule,
    SheetsModule,
    ExportModule,
  ],
})
export class AppModule {}
