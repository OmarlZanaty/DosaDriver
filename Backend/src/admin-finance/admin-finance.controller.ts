import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { DashboardAuthGuard } from '../dashboard-auth/dashboard-auth.guard';
import type { DashboardRequest } from '../dashboard-auth/dashboard-auth.guard';
import { PermissionGuard } from '../dashboard-auth/permission.guard';
import { RequirePermission } from '../dashboard-auth/require-permission.decorator';
import { Public } from '../auth/public.decorator';
import { AdminFinanceService } from './admin-finance.service';
import { CreatePayoutDto } from './dto/create-payout.dto';
import { CreateAdjustmentDto } from './dto/create-adjustment.dto';

@Controller('admin/finance')
@Public()
@UseGuards(DashboardAuthGuard, PermissionGuard)
export class AdminFinanceController {
  constructor(private readonly svc: AdminFinanceService) {}

  @Get('overview')
  @RequirePermission('FINANCE_VIEW')
  overview(@Query('from') from?: string, @Query('to') to?: string) {
    return this.svc.overview({ from, to });
  }

  @Get('rides')
  @RequirePermission('FINANCE_VIEW')
  rides(
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('status') status?: string,
    @Query('paymentMethod') paymentMethod?: string,
    @Query('q') q?: string,
    @Query('page') page = '1',
    @Query('limit') limit = '30',
  ) {
    return this.svc.listRides({ from, to, status, paymentMethod, q, page: +page, limit: +limit });
  }

  @Get('captains')
  @RequirePermission('FINANCE_VIEW')
  captains(
    @Query('q') q?: string,
    @Query('page') page = '1',
    @Query('limit') limit = '30',
  ) {
    return this.svc.listCaptains({ q, page: +page, limit: +limit });
  }

  @Get('payouts')
  @RequirePermission('FINANCE_PAYOUTS_MANAGE')
  payouts(
    @Query('status') status?: string,
    @Query('page') page = '1',
    @Query('limit') limit = '30',
  ) {
    return this.svc.listPayouts({ status, page: +page, limit: +limit });
  }

  @Post('payouts')
  @RequirePermission('FINANCE_PAYOUTS_MANAGE')
  createPayout(@Req() req: DashboardRequest, @Body() dto: CreatePayoutDto) {
    return this.svc.createPayout(req.dashboardUser, dto);
  }

  @Post('adjustments')
  @RequirePermission('FINANCE_ADJUSTMENTS')
  createAdjustment(@Req() req: DashboardRequest, @Body() dto: CreateAdjustmentDto) {
    return this.svc.createAdjustment(req.dashboardUser, dto);
  }
}