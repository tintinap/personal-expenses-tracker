import { IsString, IsNumber, IsOptional, IsBoolean, IsIn, MaxLength } from 'class-validator';

export class CreateBudgetDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @IsIn(['global', 'category'])
  scope: string;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsNumber()
  amountBase: number;

  @IsString()
  @IsIn(['weekly', 'fortnightly', 'monthly', 'custom'])
  periodType: string;

  @IsString()
  startDate: string;

  @IsOptional()
  @IsString()
  endDate?: string;
}

export class UpdateBudgetDto {
  @IsOptional()
  @IsNumber()
  amountBase?: number;

  @IsOptional()
  @IsString()
  @IsIn(['weekly', 'fortnightly', 'monthly', 'custom'])
  periodType?: string;

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
