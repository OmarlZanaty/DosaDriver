import { Module } from '@nestjs/common';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { PrismaService } from '../prisma/prisma.service';
import { DashboardAuthGuard } from '../dashboard-auth/dashboard-auth.guard';
import { PermissionGuard } from '../dashboard-auth/permission.guard';
import { Reflector } from '@nestjs/core';

@Module({
  controllers: [AdminDashboardController],
  providers: [AdminDashboardService, PrismaService, DashboardAuthGuard, PermissionGuard, Reflector],
})
export class AdminDashboardModule {}