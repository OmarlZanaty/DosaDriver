import {
  Body, Controller, Get, Param, ParseIntPipe,
  Post, Query, Req, UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { RidesService } from './rides.service';
import { Public } from '../auth/public.decorator';

@Controller('')
@UseGuards(FirebaseAuthGuard, RolesGuard)
export class RidesController {
  constructor(private readonly ridesService: RidesService) {}

  // ─── PUBLIC: Fare estimate ────────────────────────────────────────────────────
  @Public()
  @Get('fare-estimate')
  async fareEstimate(
    @Query('type') type = 'FAIR_VALUE',
    @Query('distanceKm') distanceKm = '5',
    @Query('durationMin') durationMin = '10',
  ) {
    const dist = Number(distanceKm);
    const dur  = Number(durationMin);
    const result = await this.ridesService.estimateFare({
      type,
      distanceKm: Number.isFinite(dist) ? dist : 5,
      durationMin: Number.isFinite(dur) ? dur : 10,
    });
    return { ok: true, ...result };
  }

  // ─── RIDER endpoints ──────────────────────────────────────────────────────────
  @Roles(UserRole.RIDER)
  @Post('rides')
  async createRide(@Req() req: any, @Body() body: any) {
    return { ok: true, ride: await this.ridesService.createRide(req.dbUser, body) };
  }

  @Roles(UserRole.RIDER)
  @Get('rides/active')
  async getActiveRide(@Req() req: any) {
    return { ok: true, ride: await this.ridesService.getActiveRideForRider(req.dbUser) ?? null };
  }

  @Roles(UserRole.RIDER)
  @Post('rides/:id/cancel')
  async cancelRide(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.cancelRide(req.dbUser, id) };
  }

  @Roles(UserRole.RIDER)
  @Get('rides/history')
  async riderHistory(
    @Req() req: any,
    @Query('page') page = '1',
    @Query('limit') limit = '20',
  ) {
    return this.ridesService.getRideHistory(req.dbUser.id, UserRole.RIDER, +page, +limit);
  }

  // ─── CAPTAIN endpoints ────────────────────────────────────────────────────────
  @Roles(UserRole.CAPTAIN)
  @Get('captain/rides/open')
  async listOpenRides(@Req() req: any, @Query('rideType') rideType?: string) {
    return { ok: true, rides: await this.ridesService.listOpenRides(req.dbUser, rideType) };
  }

  @Roles(UserRole.CAPTAIN)
  @Get('captain/rides/active')
  async getActiveRideForCaptain(@Req() req: any) {
    return { ok: true, ride: await this.ridesService.getActiveRideForCaptain(req.dbUser) ?? null };
  }

  @Roles(UserRole.CAPTAIN)
  @Get('captain/rides/history')
  async captainHistory(
    @Req() req: any,
    @Query('page') page = '1',
    @Query('limit') limit = '20',
  ) {
    return this.ridesService.getRideHistory(req.dbUser.id, UserRole.CAPTAIN, +page, +limit);
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/accept')
  async acceptRide(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.acceptRide(req.dbUser, id) };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/arrive')
  async arrive(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.captainArrive(req.dbUser, id) };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/start')
  async start(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.captainStart(req.dbUser, id) };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/complete')
  async complete(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.captainComplete(req.dbUser, id) };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/confirm-transfer')
  async confirmTransfer(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.confirmTransferPayment(req.dbUser, id) };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/cancel/captain')
  async cancelByCaptain(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return { ok: true, ride: await this.ridesService.cancelRideByCaptain(req.dbUser, id) };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/refuse')
  async refuse(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    await this.ridesService.markRideRefused(req.dbUser, id);
    return { ok: true };
  }

  @Roles(UserRole.CAPTAIN)
  @Post('rides/:id/expire')
  async expire(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    await this.ridesService.markRideExpired(req.dbUser, id);
    return { ok: true };
  }
}
