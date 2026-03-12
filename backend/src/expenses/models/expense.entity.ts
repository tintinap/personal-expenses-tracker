import { Entity, Column, PrimaryColumn } from 'typeorm';

@Entity('expenses')
export class Expense {
  @PrimaryColumn({ type: 'varchar', length: 255 })
  id: string;

  @Column({ type: 'double precision' })
  amount: number;

  @Column({ type: 'timestamp' })
  date: Date;

  @Column({ name: 'category_index', type: 'int' })
  categoryIndex: number;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ name: 'is_income', type: 'boolean', default: false })
  isIncome: boolean;

  @Column({ name: 'currency_code', type: 'varchar', length: 10, default: 'USD' })
  currencyCode: string;
}
