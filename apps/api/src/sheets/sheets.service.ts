import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { google, sheets_v4 } from 'googleapis';

@Injectable()
export class SheetsService {
  private readonly logger = new Logger(SheetsService.name);
  private readonly oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );

  constructor(private readonly prisma: PrismaService) {}

  private async getSheetsClient(userId: string): Promise<sheets_v4.Sheets> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { googleRefreshToken: true }
    });
    
    if (!user || !user.googleRefreshToken) {
      throw new BadRequestException('User does not have a Google refresh token');
    }

    const client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );
    client.setCredentials({ refresh_token: user.googleRefreshToken });
    return google.sheets({ version: 'v4', auth: client });
  }

  /**
   * Initializes a Google Sheet for the user and configures formula-driven summary sheets.
   */
  async setupSheet(userId: string): Promise<{ sheetId: string; url: string }> {
    this.logger.log(`Setting up Google Sheet for user ${userId}`);
    const sheets = await this.getSheetsClient(userId);
    
    const year = new Date().getFullYear();
    const spreadsheet = await sheets.spreadsheets.create({
      requestBody: {
        properties: {
          title: `Project PET — ${year}`,
        },
        sheets: [
          { properties: { title: 'All Transactions' } },
          { properties: { title: 'Currency Income' } },
          { properties: { title: 'Currency Exchanges' } },
          { properties: { title: 'Daily' } },
          { properties: { title: 'Weekly' } },
          { properties: { title: 'Fortnightly' } },
          { properties: { title: 'Monthly' } },
          { properties: { title: 'Yearly' } },
          { properties: { title: 'Wallets' } },
        ]
      },
    });

    const sheetId = spreadsheet.data.spreadsheetId;
    if (!sheetId) throw new Error('Failed to create spreadsheet');

    // Add headers to raw data sheets
    await sheets.spreadsheets.values.batchUpdate({
      spreadsheetId: sheetId,
      requestBody: {
        valueInputOption: 'USER_ENTERED',
        data: [
          {
            range: "'All Transactions'!A1:J1",
            values: [['Date', 'Type', 'Description', 'Category', 'Original Amount', 'Original Currency', 'Base Amount', 'Exchange Rate', 'Rate Source', 'UUID']]
          },
          {
            range: "'Currency Income'!A1:F1",
            values: [['Date', 'Currency', 'Amount', 'Source', 'Base currency equivalent (est.)', 'UUID']]
          },
          {
            range: "'Currency Exchanges'!A1:I1",
            values: [['Date', 'From currency', 'From amount', 'To currency', 'To amount', 'Rate', 'Rate source', 'Note', 'UUID']]
          }
        ]
      }
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        sheetsSpreadsheetId: sheetId,
        sheetsEnabled: true,
      }
    });

    return {
      sheetId: sheetId,
      url: `https://docs.google.com/spreadsheets/d/${sheetId}`,
    };
  }

  async executeAppend(userId: string, spreadsheetId: string, payload: any) {
    const sheets = await this.getSheetsClient(userId);
    const row = [
      payload.transactionDate,
      payload.transactionType || 'expense',
      payload.note || '',
      payload.category?.name || '',
      payload.originalAmount || 0,
      payload.originalCurrency || 'AUD',
      payload.amountBase || 0,
      payload.exchangeRate || 1,
      payload.rateSource || 'custom',
      payload.id
    ];

    await sheets.spreadsheets.values.append({
      spreadsheetId,
      range: "'All Transactions'!A:J",
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: { values: [row] }
    });
  }

  async executeUpdate(userId: string, spreadsheetId: string, payload: any) {
    const sheets = await this.getSheetsClient(userId);
    // 1. Find the row by UUID
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId,
      range: "'All Transactions'!A:J"
    });
    
    const rows = response.data.values || [];
    const rowIndex = rows.findIndex(r => r[9] === payload.id);
    if (rowIndex === -1) {
      // Row not found, just append instead
      return this.executeAppend(userId, spreadsheetId, payload);
    }
    
    // 2. Update the row
    const rowNumber = rowIndex + 1; // 1-indexed
    const row = [
      payload.transactionDate,
      payload.transactionType || 'expense',
      payload.note || '',
      payload.category?.name || '',
      payload.originalAmount || 0,
      payload.originalCurrency || 'AUD',
      payload.amountBase || 0,
      payload.exchangeRate || 1,
      payload.rateSource || 'custom',
      payload.id
    ];
    
    await sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `'All Transactions'!A${rowNumber}:J${rowNumber}`,
      valueInputOption: 'USER_ENTERED',
      requestBody: { values: [row] }
    });
  }

  async executeDelete(userId: string, spreadsheetId: string, uuid: string) {
    const sheets = await this.getSheetsClient(userId);
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId,
      range: "'All Transactions'!A:J"
    });
    
    const rows = response.data.values || [];
    const rowIndex = rows.findIndex(r => r[9] === uuid);
    if (rowIndex === -1) return; // Not found, nothing to delete
    
    // To delete a row using Sheets API, we need the sheetId for the tab
    const spreadsheet = await sheets.spreadsheets.get({ spreadsheetId });
    const sheetTab = spreadsheet.data.sheets?.find(s => s.properties?.title === 'All Transactions');
    if (!sheetTab || sheetTab.properties?.sheetId === undefined) return;
    
    await sheets.spreadsheets.batchUpdate({
      spreadsheetId,
      requestBody: {
        requests: [
          {
            deleteDimension: {
              range: {
                sheetId: sheetTab.properties.sheetId,
                dimension: 'ROWS',
                startIndex: rowIndex, // 0-indexed
                endIndex: rowIndex + 1
              }
            }
          }
        ]
      }
    });
  }

  async executeAppendIncome(userId: string, spreadsheetId: string, payload: any) {
    const sheets = await this.getSheetsClient(userId);
    const row = [
      payload.transactionDate,
      payload.originalCurrency,
      payload.originalAmount,
      payload.sourceLabel || '',
      payload.amountBase,
      payload.id
    ];

    await sheets.spreadsheets.values.append({
      spreadsheetId,
      range: "'Currency Income'!A:F",
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: { values: [row] }
    });
  }

  async executeAppendExchange(userId: string, spreadsheetId: string, payload: any) {
    const sheets = await this.getSheetsClient(userId);
    const row = [
      payload.transactionDate,
      payload.fromCurrency,
      payload.fromAmount,
      payload.toCurrency,
      payload.toAmount,
      payload.exchangeRate,
      payload.rateSource,
      payload.note || '',
      payload.id
    ];

    await sheets.spreadsheets.values.append({
      spreadsheetId,
      range: "'Currency Exchanges'!A:I",
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: { values: [row] }
    });
  }

  async disconnectSheet(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        sheetsSpreadsheetId: null,
        sheetsEnabled: false
      }
    });
  }
}
