import {
  BadRequestException, ConflictException, ForbiddenException,
  Injectable, Logger, NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RideStatus, UserRole, RideType, PaymentMethod, TxType, TxStatus, PayoutStatus } from '@prisma/client';
import { FirestoreBridgeService } from '../firestore/firestore-bridge.service';
import { NotificationService } from '../notifications/notification.service';

type DbUser = { id: number; role: UserRole };
const TERMINAL: RideStatus[] = [RideStatus.COMPLETED, RideStatus.CANCELED];

function assertNotTerminal(s: RideStatus) {
  if (TERMINAL.includes(s)) throw new ConflictException('TERMINAL_RIDE');
}

function toNum(v: any): number | null {
  if (v === null || v === undefined) return null;
  const n = typeof v === 'string' ? Number(v.trim().replace(',', '.')) : Number(v);
  return Number.isFinite(n) ? n : null;
}

function byPath(obj: any, p: string): any {
  return p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
}

function firstNum(obj: any, paths: string[]): number | null {
  for (const p of paths) { const n = toNum(byPath(obj, p)); if (n !== null) return n; }
  return null;
}

function normalizeType(input: any): RideType {
  const raw = (input?.type ?? input?.rideType ?? input?.ride_type ?? '').toString().trim().toUpperCase();
  const map: Record<string, RideType> = {
    FAIR_VALUE: RideType.FAIR_VALUE, FAIRVALUE: RideType.FAIR_VALUE,
    PREMIUM: RideType.PREMIUM,
    CUTE_CAR: RideType.CUTE_CAR, CUTECAR: RideType.CUTE_CAR,
    ECONOMIC: RideType.CUTE_CAR, ECONOMY: RideType.CUTE_CAR, // legacy maps to CUTE_CAR
    SCOOTER: RideType.SCOOTER,
  };
  return map[raw] ?? RideType.FAIR_VALUE;
}

@Injectable()
export class RidesService {
  private readonly logger = new Logger(RidesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bridge: FirestoreBridgeService,
    private readonly notificationService: NotificationService,
  ) {}

  // ─── FARE ESTIMATE ───────────────────────────────────────────────────────────
  async estimateFare(input: { type: string; distanceKm: number; durationMin: number }) {
    const config = await this.prisma.appConfig.findUnique({ where: { key: 'pricing' } });
    const pricing: any = config?.data ?? {};

    const typeKey = input.type.toUpperCase();
    const p = pricing[typeKey] ?? {};

    const base    = p.baseFare    ?? this._defaultBase(typeKey);
    const perKm   = p.perKm      ?? this._defaultPerKm(typeKey);
    const perMin  = p.perMin     ?? 0.5;
    const minFare = p.minFare    ?? 10;

    const surge = pricing.surgeEnabled ? (pricing.surgeMultiplier ?? 1.0) : 1.0;
    const raw   = (base + perKm * input.distanceKm + perMin * input.durationMin) * surge;
    const fare  = Math.max(minFare, Math.round(raw * 100) / 100);

    return { fare, base, perKm, perMin, surge, minFare, type: typeKey };
  }

  private _defaultBase(type: string): number {
    return { PREMIUM: 15, SCOOTER: 5, CUTE_CAR: 8, FAIR_VALUE: 10 }[type] ?? 10;
  }
  private _defaultPerKm(type: string): number {
    return { PREMIUM: 8, SCOOTER: 3, CUTE_CAR: 4, FAIR_VALUE: 5 }[type] ?? 5;
  }

  // ─── CREATE RIDE ─────────────────────────────────────────────────────────────
  async createRide(rider: DbUser, input: any) {
    if (rider.role !== UserRole.RIDER) throw new ForbiddenException('Only RIDER can create rides');

    const pickupLat = firstNum(input, ['pickupLat','pickup.lat','pickup.latitude']);
    const pickupLng = firstNum(input, ['pickupLng','pickup.lng','pickup.longitude']);
    const dropLat   = firstNum(input, ['dropLat','destinationLat','drop.lat','destination.lat']);
    const dropLng   = firstNum(input, ['dropLng','destinationLng','drop.lng','destination.lng']);

    if (pickupLat === null || pickupLng === null || dropLat === null || dropLng === null ||
        Math.abs(pickupLat) > 90 || Math.abs(dropLat) > 90 ||
        Math.abs(pickupLng) > 180 || Math.abs(dropLng) > 180) {
      throw new BadRequestException('مختصرات الموقع غير صالحة');
    }

    // Prevent multiple active rides
    const existing = await this.prisma.ride.findFirst({
      where: { riderId: rider.id, status: { in: [RideStatus.REQUESTED, RideStatus.ACCEPTED, RideStatus.ARRIVED, RideStatus.STARTED] } },
    });
    if (existing) throw new BadRequestException('لديك رحلة نشطة بالفعل');

    const rideType    = normalizeType(input);
    const pickupAddr  = input?.pickupAddr ?? input?.pickupAddress ?? input?.pickup?.address ?? null;
    const dropAddr    = input?.dropAddr   ?? input?.dropAddress   ?? input?.drop?.address   ?? null;
    const payMethod   = this._parsePayment(input?.paymentMethod);

    // FIX: Calculate fare server-side, ignore client suggestedFare for actual billing
    const clientDistKm  = firstNum(input, ['distanceKm','distance_km']) ?? 5;
    const clientDurMin  = firstNum(input, ['durationMin','duration_min']) ?? 10;
    const fareResult    = await this.estimateFare({ type: rideType, distanceKm: clientDistKm, durationMin: clientDurMin });

    const ride = await this.prisma.ride.create({
      data: {
        rider:        { connect: { id: rider.id } },
        pickupLat, pickupLng, pickupAddr,
        dropLat, dropLng, dropAddr,
        type:          rideType,
        status:        RideStatus.REQUESTED,
        suggestedFare: fareResult.fare,
        paymentMethod: payMethod,
        distanceKm:    clientDistKm,
        durationSec:   clientDurMin * 60,
      },
    });

    await this.notificationService.notifyNewRide(ride).catch(e => this.logger.warn('FCM notify failed: ' + e.message));
    await this.bridge.safeUpsertRideMirror(ride, { price: fareResult.fare, rideType: rideType.toString() });

    return ride;
  }

  private _parsePayment(raw?: string): PaymentMethod {
    if (!raw) return PaymentMethod.CASH;
    const v = raw.toUpperCase();
    if (v === 'INSTAPAY') return PaymentMethod.INSTAPAY;
    if (v === 'VODAFONE_CASH') return PaymentMethod.VODAFONE_CASH;
    if (v === 'CARD') return PaymentMethod.CARD;
    if (v === 'WALLET') return PaymentMethod.WALLET;
    return PaymentMethod.CASH;
  }

  // ─── GET ACTIVE RIDE (RIDER) ─────────────────────────────────────────────────
  async getActiveRideForRider(rider: DbUser) {
    if (rider.role !== UserRole.RIDER) throw new ForbiddenException('Only RIDER');
    return this.prisma.ride.findFirst({
      where: { riderId: rider.id, status: { in: [RideStatus.REQUESTED, RideStatus.ACCEPTED, RideStatus.ARRIVED, RideStatus.STARTED] } },
      orderBy: { id: 'desc' },
    });
  }

  // ─── CANCEL (RIDER) ──────────────────────────────────────────────────────────
  async cancelRide(rider: DbUser, rideId: number) {
    if (rider.role !== UserRole.RIDER) throw new ForbiddenException('Only RIDER');

    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة');
    assertNotTerminal(ride.status);
    if (ride.riderId !== rider.id) throw new ForbiddenException('NOT_YOUR_RIDE');
    if (ride.status === RideStatus.STARTED) throw new BadRequestException('لا يمكن إلغاء رحلة جارية');

    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: RideStatus.CANCELED, stateVersion: { increment: 1 } },
    });
    await this.bridge.safeUpsertRideMirror(updated);
    return updated;
  }

  // ─── CANCEL (CAPTAIN) ────────────────────────────────────────────────────────
  async cancelRideByCaptain(captain: DbUser, rideId: number) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة');
    assertNotTerminal(ride.status);
    if (ride.captainId !== captain.id) throw new ForbiddenException('NOT_YOUR_RIDE');
    if (!([RideStatus.ACCEPTED, RideStatus.ARRIVED] as RideStatus[]).includes(ride.status)) {
      throw new BadRequestException('لا يمكن الإلغاء في هذه المرحلة');
    }
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: RideStatus.CANCELED, stateVersion: { increment: 1 } },
    });
    await this.notificationService.notifyRideStatus(updated, 'CANCELED').catch(() => {});
    await this.bridge.safeUpsertRideMirror(updated);
    return updated;
  }

  // ─── LIST OPEN RIDES ─────────────────────────────────────────────────────────
  async listOpenRides(captain: DbUser, rideType?: string) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');
    const where: any = { status: RideStatus.REQUESTED };
    if (rideType && rideType.trim()) where.type = normalizeType({ type: rideType });

    const rides = await this.prisma.ride.findMany({
      where, orderBy: { id: 'asc' }, take: 50,
    });
    return rides.map(r => ({ ...r, price: r.suggestedFare ?? 0, rideType: r.type }));
  }

  // ─── ACCEPT RIDE (with optimistic locking) ───────────────────────────────────
  async acceptRide(captain: DbUser, rideId: number) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');

    const updated = await this.prisma.$transaction(async (tx) => {
      // FIX: Use updateMany with stateVersion for optimistic lock (prevents double-captain)
      const ride = await tx.ride.findUnique({ where: { id: rideId } });
      if (!ride) throw new NotFoundException('الرحلة غير موجودة');
      if (ride.status !== RideStatus.REQUESTED) throw new BadRequestException('الرحلة غير متاحة للقبول');

      const result = await tx.ride.updateMany({
        where: { id: rideId, status: RideStatus.REQUESTED, captainId: null, stateVersion: ride.stateVersion },
        data:  { status: RideStatus.ACCEPTED, captainId: captain.id, stateVersion: { increment: 1 } },
      });
      if (result.count === 0) throw new ConflictException('تم قبول الرحلة من كابتن آخر');

      return tx.ride.findUnique({ where: { id: rideId } });
    });

    if (!updated) throw new NotFoundException('خطأ في تحديث الرحلة');
    await this.notificationService.notifyRideStatus(updated, 'ACCEPTED').catch(() => {});
    await this.bridge.safeUpsertRideMirror(updated);
    return updated;
  }

  // ─── CAPTAIN STATUS TRANSITIONS ──────────────────────────────────────────────
  async captainArrive(captain: DbUser, rideId: number) {
    return this._captainTransition(captain, rideId, RideStatus.ACCEPTED, RideStatus.ARRIVED);
  }
  async captainStart(captain: DbUser, rideId: number) {
    return this._captainTransition(captain, rideId, RideStatus.ARRIVED, RideStatus.STARTED);
  }
  async captainComplete(captain: DbUser, rideId: number) {
    return this._captainTransition(captain, rideId, RideStatus.STARTED, RideStatus.COMPLETED);
  }

  // ─── CONFIRM TRANSFER ────────────────────────────────────────────────────────
  async confirmTransferPayment(captain: DbUser, rideId: number) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة');
    if (ride.captainId !== captain.id) throw new ForbiddenException('NOT_YOUR_RIDE');
    if (ride.status !== RideStatus.STARTED) throw new BadRequestException('الرحلة ليست جارية');

    const captainUser = await this.prisma.user.findUnique({ where: { id: captain.id } });
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: {
        transferConfirmedBy: captainUser?.firebaseUid ?? null,
        transferConfirmedAt: new Date(),
      },
    });
    await this.bridge.safeUpsertRideMirror(updated);
    return updated;
  }

  // ─── ACTIVE RIDE (CAPTAIN) ───────────────────────────────────────────────────
  async getActiveRideForCaptain(captain: DbUser) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');
    return this.prisma.ride.findFirst({
      where: { captainId: captain.id, status: { in: [RideStatus.ACCEPTED, RideStatus.ARRIVED, RideStatus.STARTED] } },
      orderBy: { id: 'desc' },
    });
  }

  async markRideRefused(captain: DbUser, rideId: number) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');
    await (this.prisma as any).rideVisibility.upsert({
      where: { rideId_captainId: { rideId, captainId: captain.id } },
      create: { rideId, captainId: captain.id, state: 'refused' },
      update: { state: 'refused' },
    }).catch((e: any) => this.logger.warn('rideVisibility upsert refused: ' + (e?.message ?? '')));
  }

  async markRideExpired(captain: DbUser, rideId: number) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');
    await (this.prisma as any).rideVisibility.upsert({
      where: { rideId_captainId: { rideId, captainId: captain.id } },
      create: { rideId, captainId: captain.id, state: 'expired' },
      update: { state: 'expired' },
    }).catch((e: any) => this.logger.warn('rideVisibility upsert expired: ' + (e?.message ?? '')));
  }

  // ─── RIDER: RATE COMPLETED RIDE ─────────────────────────────────────────────
  async rateRide(rider: DbUser, rideId: number, rating: number, comment?: string) {
    if (rider.role !== UserRole.RIDER) throw new ForbiddenException('Only RIDER');
    if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('التقييم يجب أن يكون بين 1 و 5');
    }

    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة');
    if (ride.riderId !== rider.id) throw new ForbiddenException('NOT_YOUR_RIDE');
    if (ride.status !== RideStatus.COMPLETED) {
      throw new BadRequestException('يمكن التقييم بعد اكتمال الرحلة فقط');
    }

    let captainFirebaseUid: string | null = null;
    if (ride.captainId) {
      const captain = await this.prisma.user.findUnique({ where: { id: ride.captainId } });
      captainFirebaseUid = captain?.firebaseUid ?? null;
    }

    await this.bridge.mirrorRideRating(rideId, rating, (comment ?? '').trim(), captainFirebaseUid);
    return { ok: true, rideId, rating };
  }

  // ─── RIDER: SUBMIT TRANSFER PAYMENT PROOF ───────────────────────────────────
  async submitTransferProof(rider: DbUser, rideId: number, proofUrl: string) {
    if (rider.role !== UserRole.RIDER) throw new ForbiddenException('Only RIDER');
    const url = (proofUrl ?? '').trim();
    if (!url.startsWith('http')) throw new BadRequestException('رابط الإيصال غير صالح');

    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة');
    if (ride.riderId !== rider.id) throw new ForbiddenException('NOT_YOUR_RIDE');
    if (!([RideStatus.ACCEPTED, RideStatus.ARRIVED, RideStatus.STARTED] as RideStatus[]).includes(ride.status)) {
      throw new BadRequestException('لا يمكن رفع الإيصال في هذه الحالة');
    }

    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { transferProofUrl: url },
    });
    await this.bridge.safeUpsertRideMirror(updated);
    return updated;
  }

  // ─── CAPTAIN: EARNINGS SUMMARY (Postgres source of truth) ───────────────────
  async getCaptainEarnings(captain: DbUser) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');

    const [earnedAgg, paidAgg, pendingAgg, completedTrips] = await Promise.all([
      this.prisma.transaction.aggregate({
        where: { captainId: captain.id, type: TxType.CAPTAIN_EARNING, status: TxStatus.POSTED },
        _sum: { amount: true },
      }),
      this.prisma.payout.aggregate({
        where: { captainId: captain.id, status: PayoutStatus.PAID },
        _sum: { amount: true },
      }),
      this.prisma.payout.aggregate({
        where: { captainId: captain.id, status: PayoutStatus.PENDING },
        _sum: { amount: true },
      }),
      this.prisma.ride.count({
        where: { captainId: captain.id, status: RideStatus.COMPLETED },
      }),
    ]);

    const totalGross = earnedAgg._sum.amount ?? 0;
    const paidOut = paidAgg._sum.amount ?? 0;
    const pendingPayout = pendingAgg._sum.amount ?? 0;
    const availableBalance = Math.max(0, Math.round((totalGross - paidOut - pendingPayout) * 100) / 100);

    const weekStart = new Date();
    weekStart.setDate(weekStart.getDate() - 6);
    weekStart.setHours(0, 0, 0, 0);

    const weekTx = await this.prisma.transaction.findMany({
      where: {
        captainId: captain.id,
        type: TxType.CAPTAIN_EARNING,
        status: TxStatus.POSTED,
        createdAt: { gte: weekStart },
      },
      select: { amount: true, createdAt: true },
    });

    const dailyEarnings = Array.from({ length: 7 }, () => 0);
    let weeklyEarnings = 0;
    for (const tx of weekTx) {
      const amt = tx.amount ?? 0;
      weeklyEarnings += amt;
      const dayIndex = tx.createdAt.getDay();
      dailyEarnings[dayIndex] += amt;
    }

    return {
      ok: true,
      availableBalance,
      pendingPayout,
      totalGross,
      totalTrips: completedTrips,
      weeklyEarnings: Math.round(weeklyEarnings * 100) / 100,
      dailyEarnings,
    };
  }

  // ─── RIDE HISTORY ────────────────────────────────────────────────────────────
  async getRideHistory(userId: number, role: UserRole, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const where = role === UserRole.RIDER
      ? { riderId: userId, status: { in: [RideStatus.COMPLETED, RideStatus.CANCELED] } }
      : { captainId: userId, status: { in: [RideStatus.COMPLETED, RideStatus.CANCELED] } };

    const [rides, total] = await Promise.all([
      this.prisma.ride.findMany({ where, orderBy: { createdAt: 'desc' }, skip, take: limit }),
      this.prisma.ride.count({ where }),
    ]);
    return { rides, total, page, pages: Math.ceil(total / limit) };
  }

  // ─── PRIVATE: CAPTAIN TRANSITION ─────────────────────────────────────────────
  private async _captainTransition(
    captain: DbUser, rideId: number,
    from: RideStatus, to: RideStatus,
  ) {
    if (captain.role !== UserRole.CAPTAIN) throw new ForbiddenException('Only CAPTAIN');

    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة');
    assertNotTerminal(ride.status);
    if (ride.captainId !== captain.id) throw new ForbiddenException('NOT_YOUR_RIDE');
    if (ride.status !== from) throw new BadRequestException(`يجب أن تكون الرحلة في حالة ${from}`);

    const result = await this.prisma.ride.updateMany({
      where: { id: rideId, captainId: captain.id, status: from, stateVersion: ride.stateVersion },
      data:  { status: to, stateVersion: { increment: 1 } },
    });
    if (result.count === 0) throw new ConflictException('RIDE_STATE_CONFLICT');

    let updated = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!updated) throw new NotFoundException('خطأ في جلب الرحلة');

    // FIX: Post finance AFTER status update in separate try/catch — never blocks completion
    if (to === RideStatus.COMPLETED) {
      try {
        await this._postFinance(rideId);
        updated = await this.prisma.ride.findUnique({ where: { id: rideId } }) ?? updated;
      } catch (e) {
        this.logger.error(`Finance post failed for ride ${rideId}: ${e.message}`);
        // Don't throw — ride is still COMPLETED, finance will be reconciled manually
      }
    }

    await this.bridge.safeUpsertRideMirror(updated, {
      price: (updated as any).finalFare ?? (updated as any).suggestedFare ?? null,
      rideType: String((updated as any).type ?? ''),
    });
    await this.notificationService.notifyRideStatus(updated, to).catch(() => {});
    return updated;
  }

  // ─── PRIVATE: POST FINANCE ───────────────────────────────────────────────────
  private async _postFinance(rideId: number) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || ride.status !== RideStatus.COMPLETED) return;
    if ((ride as any).paidAt != null) return; // idempotent

    // Load commission rate from config
    const config = await this.prisma.appConfig.findUnique({ where: { key: 'pricing' } }).catch(() => null);
    const commissionRate = (config?.data as any)?.commissionPercent
      ? (config!.data as any).commissionPercent / 100
      : 0.15;

    const finalFare       = (ride as any).finalFare ?? (ride as any).suggestedFare ?? 0;
    const commissionAmount = Math.round(finalFare * commissionRate * 100) / 100;
    const captainEarning   = Math.round((finalFare - commissionAmount) * 100) / 100;

    await this.prisma.$transaction(async (tx) => {
      const fresh = await tx.ride.findUnique({ where: { id: rideId } });
      if (!fresh || (fresh as any).paidAt != null) return;

      const already = await tx.transaction.count({
        where: { rideId, type: { in: [TxType.RIDE_FARE, TxType.PLATFORM_COMMISSION, TxType.CAPTAIN_EARNING] } },
      });
      if (already > 0) return;

      await tx.ride.update({
        where: { id: rideId },
        data: { finalFare, commissionRate, commissionAmount, captainEarning, paidAt: new Date() },
      });

      await tx.transaction.createMany({
        data: [
          { type: TxType.RIDE_FARE,           amount: finalFare,        rideId, riderId: fresh.riderId, captainId: fresh.captainId },
          { type: TxType.PLATFORM_COMMISSION, amount: commissionAmount,  rideId, riderId: fresh.riderId, captainId: fresh.captainId },
          { type: TxType.CAPTAIN_EARNING,     amount: captainEarning,   rideId, riderId: fresh.riderId, captainId: fresh.captainId },
        ],
      });
    });
  }
}
