import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ExchangeRatesService {
  private readonly logger = new Logger(ExchangeRatesService.name);
  private readonly frankfurterBaseUrl = 'https://api.frankfurter.app';

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Get exchange rate, checking cache first, then fetching from Frankfurter.
   */
  async getRate(from: string, to: string, date?: string) {
    if (from === to) {
      return { rate: 1, date: date || new Date().toISOString().split('T')[0] };
    }

    const rateDate = date || new Date().toISOString().split('T')[0];

    // Check cache
    const cached = await this.prisma.exchangeRate.findUnique({
      where: {
        baseCurrency_quoteCurrency_rateDate: {
          baseCurrency: from,
          quoteCurrency: to,
          rateDate: new Date(rateDate),
        },
      },
    });

    if (cached) {
      return { rate: Number(cached.rate), date: rateDate };
    }

    // Fetch from Frankfurter
    const url = date
      ? `${this.frankfurterBaseUrl}/${date}?from=${from}&to=${to}`
      : `${this.frankfurterBaseUrl}/latest?from=${from}&to=${to}`;

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(url, { signal: controller.signal });
      clearTimeout(timeout);

      if (!response.ok) {
        throw new Error(`Frankfurter API returned ${response.status}`);
      }

      const data = await response.json();
      const rate = data.rates[to];
      const actualDate = data.date;

      // Cache the rate
      await this.prisma.exchangeRate.upsert({
        where: {
          baseCurrency_quoteCurrency_rateDate: {
            baseCurrency: from,
            quoteCurrency: to,
            rateDate: new Date(actualDate),
          },
        },
        create: {
          baseCurrency: from,
          quoteCurrency: to,
          rate,
          rateDate: new Date(actualDate),
          source: 'frankfurter',
        },
        update: { rate, source: 'frankfurter' },
      });

      return { rate, date: actualDate };
    } catch (error) {
      this.logger.warn(
        `Failed to fetch rate ${from}->${to} for ${rateDate}: ${error.message}`,
      );

      // Fall back to most recent cached rate for this pair
      const fallback = await this.prisma.exchangeRate.findFirst({
        where: { baseCurrency: from, quoteCurrency: to },
        orderBy: { rateDate: 'desc' },
      });

      if (fallback) {
        return {
          rate: Number(fallback.rate),
          date: fallback.rateDate.toISOString().split('T')[0],
          estimated: true,
        };
      }

      throw error;
    }
  }
}
