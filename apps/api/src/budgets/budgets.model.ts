import {
  IsString,
  IsNumber,
  IsOptional,
  IsBoolean,
  IsIn,
  MaxLength,
} from 'class-validator';

export class CreateBudgetDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  name?: string;

  @IsString()
  @IsIn(['all', 'include', 'exclude'])
  scopeType: string;

  @IsOptional()
  @IsString()
  categoryIds?: string; // JSON-encoded string: '["uuid1","uuid2"]'

  @IsString()
  @MaxLength(3)
  currency: string;

  @IsNumber()
  amountBase: number;

  @IsString()
  @IsIn(['weekly', 'fortnightly', 'monthly', 'custom'])
  periodType: string;

  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;

  @IsString()
  startDate: string;

  @IsOptional()
  @IsString()
  endDate?: string;
}

export class UpdateBudgetDto {
  @IsOptional()
  @IsString()
  @MaxLength(150)
  name?: string;

  @IsOptional()
  @IsString()
  @IsIn(['all', 'include', 'exclude'])
  scopeType?: string;

  @IsOptional()
  @IsString()
  categoryIds?: string;

  @IsOptional()
  @IsString()
  @MaxLength(3)
  currency?: string;

  @IsOptional()
  @IsNumber()
  amountBase?: number;

  @IsOptional()
  @IsString()
  @IsIn(['weekly', 'fortnightly', 'monthly', 'custom'])
  periodType?: string;

  @IsOptional()
  @IsBoolean()
  isRecurring?: boolean;

  @IsOptional()
  @IsString()
  startDate?: string;

  @IsOptional()
  @IsString()
  endDate?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
