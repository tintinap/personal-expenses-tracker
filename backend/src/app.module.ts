import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ExpensesModule } from './expenses/expenses.module';
import { Expense } from './expenses/models/expense.entity';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('POSTGRES_HOST', 'localhost'),
        port: config.get<number>('POSTGRES_PORT', 5432),
        username: config.get<string>('POSTGRES_USER', 'expense_user'),
        password: config.get<string>('POSTGRES_PASSWORD', 'expense_password'),
        database: config.get<string>('POSTGRES_DB', 'expense_db'),
        entities: [Expense],
        synchronize: true, // auto-create tables (dev only)
      }),
    }),
    ExpensesModule,
  ],
})
export class AppModule {}
