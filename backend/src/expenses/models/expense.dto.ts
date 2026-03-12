export class CreateExpenseDto {
  id: string;
  amount: number;
  date: Date;
  categoryIndex: number;
  note?: string | null;
  isIncome?: boolean;
  currencyCode?: string;
}

export class UpdateExpenseDto {
  amount?: number;
  date?: Date;
  categoryIndex?: number;
  note?: string | null;
  isIncome?: boolean;
  currencyCode?: string;
}
