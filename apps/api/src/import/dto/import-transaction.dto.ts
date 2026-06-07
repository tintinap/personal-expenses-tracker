import { IsString, IsNumber, IsOptional, IsBoolean, IsIn, MaxLength, IsArray, ValidateNested, IsNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';

export class ImportTransactionItemDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @IsNotEmpty()
  date: string; // YYYY-MM-DD format

  @IsString()
  @IsIn(['expense', 'currency_income', 'currency_exchange_out', 'currency_exchange_in'])
  transactionType: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  categoryName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  subcategoryOf?: string; // Parent category name — used when auto-creating subcategories

  @IsOptional()
  @IsString()
  @MaxLength(7)
  categoryColor?: string; // Hex colour e.g. #FF5733

  @IsOptional()
  @IsNumber()
  categoryIcon?: number; // Flutter IconData.codePoint integer

  @IsNumber()
  originalAmount: number;

  @IsString()
  @MaxLength(3)
  originalCurrency: string;

  @IsOptional()
  @IsNumber()
  amountBase?: number;

  @IsOptional()
  @IsNumber()
  exchangeRate?: number;

  @IsOptional()
  @IsString()
  rateSource?: string;

  @IsOptional()
  @IsString()
  exchangeEventId?: string;

  @IsOptional()
  @IsString()
  sourceLabel?: string;

  @IsOptional()
  @IsBoolean()
  isAggregate?: boolean;
}

export class ImportTransactionsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ImportTransactionItemDto)
  transactions: ImportTransactionItemDto[];
}
