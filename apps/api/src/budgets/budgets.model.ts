export class CreateBudgetDto {
  scope: string;
  categoryId?: string;
  amountBase: number;
  periodType: string;
  startDate: string;
  endDate?: string;
}

export class UpdateBudgetDto {
  amountBase?: number;
  periodType?: string;
  startDate?: string;
  endDate?: string;
  isActive?: boolean;
}
