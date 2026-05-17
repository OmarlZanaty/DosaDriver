import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AdminDashboardService } from './admin-dashboard.service';
import { CreateDashboardUserDto } from './dto/create-dashboard-user.dto';
import { UpdateDashboardUserDto } from './dto/update-dashboard-user.dto';

import { DashboardAuthGuard } from '../dashboard-auth/dashboard-auth.guard';
import type { DashboardRequest } from '../dashboard-auth/dashboard-auth.guard';

import { PermissionGuard } from '../dashboard-auth/permission.guard';
import { RequirePermission } from '../dashboard-auth/require-permission.decorator';

import { Public } from '../auth/public.decorator';
import { getFirebaseAdminApp } from '../auth/firebase-admin';

@Controller('admin') // ✅ FIX: no v1 here
@Public()
@UseGuards(DashboardAuthGuard, PermissionGuard)
export class AdminDashboardController {
  constructor(private readonly svc: AdminDashboardService) {}

  @Get('me')
  async me(@Req() req: DashboardRequest) {
    return { ok: true, user: req.dashboardUser };
  }

  @Get('overview-stats')
  async overviewStats() {
    const db = getFirebaseAdminApp().firestore();

    // Backend mirrors ride status as UPPERCASE (e.g. REQUESTED, ACCEPTED, STARTED, COMPLETED, CANCELED)
    const activeStatuses = ['REQUESTED', 'ACCEPTED', 'STARTED'];

    const activeSnap = await db.collection('rides').where('status', 'in', activeStatuses).get();
    const requestedSnap = await db.collection('rides').where('status', '==', 'REQUESTED').get();
    // Captain online status is stored in the 'drivers' collection, not 'users'
    const onlineSnap = await db.collection('drivers').where('isOnline', '==', true).get();

    return {
      ok: true,
      activeRides: activeSnap.size,
      requestedRides: requestedSnap.size,
      onlineDrivers: onlineSnap.size,
    };
  }

  @Get('dashboard-users')
  @RequirePermission('ADMIN_USERS_MANAGE')
  async list() {
    const users = await this.svc.listUsers();
    return { ok: true, users };
  }

  @Get('dashboard-users/:id')
  @RequirePermission('ADMIN_USERS_MANAGE')
  async get(@Param('id', ParseIntPipe) id: number) {
    const user = await this.svc.getUser(id);
    return { ok: true, user };
  }

  @Post('dashboard-users')
  @RequirePermission('ADMIN_USERS_MANAGE')
  async create(@Req() req: DashboardRequest, @Body() dto: CreateDashboardUserDto) {
    const actorRole = req.dashboardUser?.role ?? 'SUPER_ADMIN';
    const user = await this.svc.createUser(dto, actorRole);
    return { ok: true, user };
  }

  @Patch('dashboard-users/:id')
  @RequirePermission('ADMIN_USERS_MANAGE')
  async update(
    @Req() req: DashboardRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateDashboardUserDto,
  ) {
    const actorRole = req.dashboardUser?.role ?? 'SUPER_ADMIN';
    const user = await this.svc.updateUser(id, dto, actorRole);
    return { ok: true, user };
  }

  @Delete('dashboard-users/:id')
  @RequirePermission('ADMIN_USERS_MANAGE')
  async remove(@Req() req: DashboardRequest, @Param('id', ParseIntPipe) id: number) {
    const actorRole = req.dashboardUser?.role ?? 'SUPER_ADMIN';
    return await this.svc.deleteUser(id, actorRole);
  }
}