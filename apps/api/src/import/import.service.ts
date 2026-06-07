import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ImportTransactionItemDto } from './dto/import-transaction.dto';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class ImportService {
  constructor(private readonly prisma: PrismaService) {}

  async importTransactions(userId: string, items: ImportTransactionItemDto[]): Promise<number> {
    if (!items || items.length === 0) {
      return 0;
    }

    const categories = await this.prisma.category.findMany({
      where: { userId },
    });

    const baseCurrencySetting = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { baseCurrency: true },
    });
    const baseCurrency = baseCurrencySetting?.baseCurrency ?? 'AUD';

    const catMap = new Map<string, string>();
    for (const c of categories) {
      catMap.set(c.name.toLowerCase().trim(), c.id);
    }

    let importedCount = 0;

    // Run all inside a prisma transaction to ensure atomic execution
    await this.prisma.$transaction(async (tx) => {
      for (const item of items) {
        const transactionDate = new Date(item.date);
        if (isNaN(transactionDate.getTime())) {
          throw new BadRequestException(`Invalid date format: ${item.date}`);
        }

        // Validate and resolve Category
        let categoryId: string | null = null;
        if (item.transactionType === 'expense') {
          if (!item.categoryName) {
            throw new BadRequestException(`Category Name is required for expense on date ${item.date}`);
          }
          categoryId = this.resolveCategoryId(item.categoryName, catMap, categories);
          if (!categoryId) {
            // Auto-create the missing category, preserving its colour, icon and hierarchy
            categoryId = await this.autoCreateCategory(
              tx,
              userId,
              item.categoryName,
              catMap,
              categories,
              item.subcategoryOf,
              item.categoryColor,
              item.categoryIcon,
            );
          }
        }

        // Base currency amount calculations
        let exchangeRate = item.exchangeRate ?? 1.0;
        let amountBase = item.amountBase ?? 0.0;

        if (item.originalCurrency === baseCurrency) {
          exchangeRate = 1.0;
          amountBase = item.originalAmount;
        } else if (item.exchangeRate !== undefined) {
          amountBase = item.amountBase ?? (item.originalAmount * item.exchangeRate);
        } else {
          // Check cached exchange rate
          const normalizedDate = new Date(
            Date.UTC(transactionDate.getUTCFullYear(), transactionDate.getUTCMonth(), transactionDate.getUTCDate())
          );
          const cachedRate = await tx.exchangeRate.findUnique({
            where: {
              baseCurrency_quoteCurrency_rateDate: {
                baseCurrency: item.originalCurrency,
                quoteCurrency: baseCurrency,
                rateDate: normalizedDate,
              },
            },
          });

          if (cachedRate) {
            exchangeRate = Number(cachedRate.rate);
            amountBase = item.originalAmount * exchangeRate;
          } else {
            // Get most recent fallback
            const recentRate = await tx.exchangeRate.findFirst({
              where: {
                baseCurrency: item.originalCurrency,
                quoteCurrency: baseCurrency,
              },
              orderBy: { rateDate: 'desc' },
            });
            if (recentRate) {
              exchangeRate = Number(recentRate.rate);
              amountBase = item.originalAmount * exchangeRate;
            } else {
              exchangeRate = 1.0;
              amountBase = item.originalAmount;
            }
          }
        }

        // Check if transaction exists by UUID or duplicate check
        let existingId: string | null = null;

        if (item.id) {
          const match = await tx.transaction.findUnique({
            where: { id: item.id },
            select: { id: true },
          });
          if (match) {
            existingId = match.id;
          }
        }

        // Fallback duplicate detection to avoid double import if UUID is missing or manually filled
        if (!existingId) {
          if (item.transactionType === 'expense') {
            const match = await tx.transaction.findFirst({
              where: {
                userId,
                transactionDate,
                originalAmount: item.originalAmount,
                categoryId,
                deletedAt: null,
              },
              select: { id: true },
            });
            if (match) existingId = match.id;
          } else if (item.transactionType === 'currency_income') {
            const match = await tx.transaction.findFirst({
              where: {
                userId,
                transactionDate,
                originalAmount: item.originalAmount,
                originalCurrency: item.originalCurrency,
                transactionType: 'currency_income',
                deletedAt: null,
              },
              select: { id: true },
            });
            if (match) existingId = match.id;
          } else if (item.transactionType === 'currency_exchange_out' || item.transactionType === 'currency_exchange_in') {
            // Exchange duplicate check
            const match = await tx.transaction.findFirst({
              where: {
                userId,
                transactionDate,
                originalAmount: item.originalAmount,
                originalCurrency: item.originalCurrency,
                transactionType: item.transactionType,
                deletedAt: null,
              },
              select: { id: true },
            });
            if (match) existingId = match.id;
          }
        }

        const id = existingId ?? uuidv4();
        const data = {
          userId,
          transactionType: item.transactionType,
          amountBase,
          originalAmount: item.originalAmount,
          originalCurrency: item.originalCurrency,
          exchangeRate,
          rateDate: transactionDate,
          rateSource: item.rateSource ?? 'import',
          exchangeEventId: item.exchangeEventId ?? null,
          categoryId,
          note: item.note ?? null,
          sourceLabel: item.sourceLabel ?? null,
          transactionDate,
          isAggregate: item.isAggregate ?? false,
          deletedAt: null,
        };

        await tx.transaction.upsert({
          where: { id },
          update: data,
          create: { id, ...data },
        });

        importedCount++;
      }
    });

    return importedCount;
  }

  private resolveCategoryId(name: string, catMap: Map<string, string>, categories: any[]): string | null {
    const clean = name.toLowerCase().trim();
    if (catMap.has(clean)) return catMap.get(clean)!;

    // Check uncategorized aliases
    if (clean === 'uncategorized' || clean === 'uncategorised' || clean === 'unknown') {
      const match = categories.find((c) => {
        const cName = c.name.toLowerCase();
        return cName.includes('other') || cName.includes('uncategorised');
      });
      if (match) return match.id;
    }

    // Fuzzy matching
    const fuzzy = categories.find((c) => {
      const cName = c.name.toLowerCase();
      return cName.includes(clean) || clean.includes(cName);
    });
    if (fuzzy) return fuzzy.id;

    return null;
  }

  /**
   * Auto-creates a missing category in the database during import.
   * Optionally links it to a parent (subcategoryOf), and uses the
   * provided colour/icon from the export (falling back to hash colour
   * and default icon if not provided).
   * Updates catMap and categories array so subsequent items reuse it.
   */
  private async autoCreateCategory(
    tx: any,
    userId: string,
    name: string,
    catMap: Map<string, string>,
    categories: any[],
    subcategoryOf?: string,
    categoryColor?: string,
    categoryIcon?: number,
  ): Promise<string> {
    // Resolve or create parent first
    let parentId: string | undefined = undefined;
    if (subcategoryOf && subcategoryOf.trim()) {
      const resolvedParent = this.resolveCategoryId(subcategoryOf, catMap, categories);
      if (resolvedParent) {
        parentId = resolvedParent;
      } else {
        // Parent also missing — create it as a top-level category
        parentId = await this.autoCreateCategory(tx, userId, subcategoryOf, catMap, categories);
      }
    }

    // Determine next sort order
    const maxSort = categories.length > 0
      ? Math.max(...categories.map((c) => c.sortOrder ?? 0))
      : 0;

    // Use exported colour/icon, fall back to hash colour & default icon
    const finalColour = (categoryColor && categoryColor.trim()) ? categoryColor : this.hashColor(name);
    const finalIcon = (categoryIcon && categoryIcon > 0) ? categoryIcon : 0xe148;

    const newCategory = await tx.category.create({
      data: {
        userId,
        name,
        colourHex: finalColour,
        iconCodePoint: finalIcon,
        isDefault: false,
        isHidden: false,
        sortOrder: maxSort + 1,
        ...(parentId ? { parentId } : {}),
      },
    });

    // Update in-memory lookup for subsequent items
    catMap.set(name.toLowerCase().trim(), newCategory.id);
    categories.push(newCategory);

    return newCategory.id;
  }

  /**
   * Generates a deterministic hex colour from a category name.
   * Uses HSL with varied hue, fixed saturation (65%) and lightness (50%).
   */
  private hashColor(name: string): string {
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.charCodeAt(i)) & 0x7fffffff;
    }
    const hue = hash % 360;
    // HSL to hex conversion
    const h = hue / 360;
    const s = 0.65;
    const l = 0.5;
    const hueToRgb = (p: number, q: number, t: number): number => {
      let tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1 / 6) return p + (q - p) * 6 * tt;
      if (tt < 1 / 2) return q;
      if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
      return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    const r = Math.round(hueToRgb(p, q, h + 1 / 3) * 255);
    const g = Math.round(hueToRgb(p, q, h) * 255);
    const b = Math.round(hueToRgb(p, q, h - 1 / 3) * 255);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }
}
