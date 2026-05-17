import { Module } from '@nestjs/common';
import { AdminFinanceController } from './admin-finance.controller';
import { AdminFinanceService } from './admin-finance.service';
import { PrismaService } from '../prisma/prisma.service';

@Module({
  controllers: [AdminFinanceController],
  providers: [AdminFinanceService, PrismaService],
})
export class AdminFinanceModule {}