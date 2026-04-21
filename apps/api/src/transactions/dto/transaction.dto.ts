import { IsString, IsNumber, IsOptional, IsBoolean, IsIn, MaxLength } from 'class-validator';

export class CreateTransactionDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @IsIn(['expense', 'currency_income', 'currency_exchange_out', 'currency_exchange_in'])
  transactionType: string;

  @IsNumber()
  amountBase: number;

  @IsNumber()
  originalAmount: number;

  @IsString()
  @MaxLength(3)
  originalCurrency: string;

  @IsNumber()
  exchangeRate: number;

  @IsString()
  rateDate: string;

  @IsOptional()
  @IsBoolean()
  rateEstimated?: boolean;

  @IsOptional()
  @IsString()
  @IsIn(['frankfurter', 'custom', 'estimated'])
  rateSource?: string;

  @IsOptional()
  @IsString()
  exchangeEventId?: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsOptional()
  @IsString()
  sourceLabel?: string;

  @IsString()
  transactionDate: string;

  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;

  @IsOptional()
  @IsString()
  @IsIn(['weekly', 'fortnightly', 'monthly'])
  recurrenceType?: string;
}

export class UpdateTransactionDto {
  @IsOptional()
  @IsNumber()
  amountBase?: number;

  @IsOptional()
  @IsNumber()
  originalAmount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(3)
  originalCurrency?: string;

  @IsOptional()
  @IsNumber()
  exchangeRate?: number;

  @IsOptional()
  @IsString()
  rateDate?: string;

  @IsOptional()
  @IsBoolean()
  rateEstimated?: boolean;

  @IsOptional()
  @IsString()
  rateSource?: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsOptional()
  @IsString()
  transactionDate?: string;
}
