import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma, ExchangeRate } from '@prisma/client';

@Injectable()
export class ExchangeRatesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findByPairAndDate(baseCurrency: string, quoteCurrency: string, rateDate: string): Promise<ExchangeRate | null> {
    return this.prisma.exchangeRate.findUnique({
      where: {
        baseCurrency_quoteCurrency_rateDate: {
          baseCurrency,
          quoteCurrency,
          rateDate: new Date(rateDate),
        },
      },
    });
  }

  async findMostRecentByPair(baseCurrency: string, quoteCurrency: string): Promise<ExchangeRate | null> {
    return this.prisma.exchangeRate.findFirst({
      where: { baseCurrency, quoteCurrency },
      orderBy: { rateDate: 'desc' },
    });
  }

  async upsertRate(
    baseCurrency: string,
    quoteCurrency: string,
    rateDate: string,
    rate: number,
    source: string,
  ): Promise<ExchangeRate> {
    return this.prisma.exchangeRate.upsert({
      where: {
        baseCurrency_quoteCurrency_rateDate: {
          baseCurrency,
          quoteCurrency,
          rateDate: new Date(rateDate),
        },
      },
      create: {
        baseCurrency,
        quoteCurrency,
        rate,
        rateDate: new Date(rateDate),
        source,
      },
      update: { rate, source },
    });
  }
}
