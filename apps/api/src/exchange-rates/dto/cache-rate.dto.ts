import { IsString, IsNumber, MaxLength, Matches } from 'class-validator';

export class CacheRateDto {
  @IsString()
  @MaxLength(3)
  from: string;

  @IsString()
  @MaxLength(3)
  to: string;

  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date must be in YYYY-MM-DD format' })
  date: string;

  @IsNumber()
  rate: number;
}
