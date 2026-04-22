import { Test, TestingModule } from '@nestjs/testing';
import { ExportController } from '../src/export/export.controller';
import { ExportService } from '../src/export/export.service';
import { BadRequestException } from '@nestjs/common';

describe('ExportController (Regression)', () => {
  let controller: ExportController;
  let service: ExportService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ExportController],
      providers: [
        {
          provide: ExportService,
          useValue: {
            generateExcel: jest.fn().mockResolvedValue(Buffer.from('mock')),
          },
        },
      ],
    }).compile();

    controller = module.get<ExportController>(ExportController);
    service = module.get<ExportService>(ExportService);
  });

  describe('exportExcel parameter validation', () => {
    it('should throw BadRequestException when startDate is an invalid string', async () => {
      const req = { user: { userId: '123' } };
      const res = { setHeader: jest.fn(), send: jest.fn() } as any;

      await expect(
        controller.exportExcel(req, res, 'INVALID_DATE', undefined)
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException when endDate is an invalid string', async () => {
      const req = { user: { userId: '123' } };
      const res = { setHeader: jest.fn(), send: jest.fn() } as any;

      await expect(
        controller.exportExcel(req, res, undefined, 'INVALID_DATE')
      ).rejects.toThrow(BadRequestException);
    });

    it('should proceed normally with valid dates', async () => {
      const req = { user: { userId: '123' } };
      const res = { setHeader: jest.fn(), send: jest.fn() } as any;

      await controller.exportExcel(req, res, '2026-04-21', '2026-04-30');
      
      expect(service.generateExcel).toHaveBeenCalledWith('123', new Date('2026-04-21'), new Date('2026-04-30'));
      expect(res.send).toHaveBeenCalled();
    });
  });
});
