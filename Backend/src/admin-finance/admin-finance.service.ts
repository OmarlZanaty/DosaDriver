import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

function parseRange(from?: string, to?: string) {
  const now = new Date();
  const fromD = from ? new Date(from) : new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const toD = to ? new Date(to) : now;

  if (isNaN(fromD.getTime()) || isNaN(toD.getTime())) {
    throw new BadRequestException('Invalid date range');
  }

  return { from: fromD, to: toD };
}

@Injectable()
export class AdminFinanceService {
  constructor(private readonly prisma: PrismaService) {}

  async overview({ from, to }: { from?: string; to?: string }) {
    const r = parseRange(from, to);

    const rides = await this.prisma.ride.findMany({
      where: {
        status: 'COMPLETED',
        paidAt: { gte: r.from, lte: r.to },
      },
      select: {
        finalFare: true,
        commissionAmount: true,
        captainEarning: true,
        paymentMethod: true,
      },
    });

    let gross = 0;
    let commission = 0;
    let captain = 0;
    let cash = 0;
    let card = 0;

    for (const ride of rides) {
      gross += ride.finalFare ?? 0;
      commission += ride.commissionAmount ?? 0;
      captain += ride.captainEarning ?? 0;

      if (ride.paymentMethod === 'CASH') cash += ride.finalFare ?? 0;
      if (ride.paymentMethod === 'CARD') card += ride.finalFare ?? 0;
    }

    return {
      ok: true,
      completedTrips: rides.length,
      grossRevenue: gross,
      platformCommission: commission,
      captainEarnings: captain,
      cashRevenue: cash,
      cardRevenue: card,
      netRevenue: commission,
    };
  }

  async listRides(params: any) {
    const r = parseRange(params.from, params.to);

    const where: any = {
      paidAt: { gte: r.from, lte: r.to },
    };

    if (params.status) where.status = params.status;
    if (params.paymentMethod) where.paymentMethod = params.paymentMethod;

    if (params.q) {
      const q = params.q.trim();
      const idNum = Number(q);

      where.OR = [
        ...(Number.isFinite(idNum) ? [{ id: idNum }] : []),
        { rider: { name: { contains: q, mode: 'insensitive' } } },
        { captain: { name: { contains: q, mode: 'insensitive' } } },
      ];
    }

    const page = Math.max(1, params.page || 1);
    const limit = Math.min(100, Math.max(10, params.limit || 30));
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      this.prisma.ride.findMany({
        where,
        skip,
        take: limit,
        orderBy: { paidAt: 'desc' },
        include: { rider: true, captain: true },
      }),
      this.prisma.ride.count({ where }),
    ]);

    return {
      ok: true,
      total,
      page,
      items,
    };
  }

  async listCaptains({ q, page, limit }: any) {
    const where: any = { role: 'CAPTAIN' };

    if (q) {
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q } },
      ];
    }

    const skip = (page - 1) * limit;

    const captains = await this.prisma.user.findMany({
      where,
      skip,
      take: limit,
      orderBy: { id: 'desc' },
    });

    return {
      ok: true,
      items: captains,
    };
  }

  async listPayouts({ status, page, limit }: any) {
    const where: any = {};
    if (status) where.status = status;

    const skip = (page - 1) * limit;

    const payouts = await this.prisma.payout.findMany({
      where,
      skip,
      take: limit,
      orderBy: { id: 'desc' },
      include: { captain: true },
    });

    return {
      ok: true,
      items: payouts,
    };
  }

  async createPayout(actor: any, dto: any) {
    const payout = await this.prisma.payout.create({
      data: {
        captainId: dto.captainId,
        amount: dto.amount,
        method: dto.method ?? 'MANUAL',
        reference: dto.reference ?? null,
        proofUrl: dto.proofUrl ?? null,
        note: dto.note ?? null,
      },
    });

    await this.prisma.transaction.create({
      data: {
        type: 'PAYOUT',
        amount: dto.amount,
        captainId: dto.captainId,
        meta: { createdBy: actor?.email ?? 'unknown' },
      },
    });

    return { ok: true, payout };
  }

  async createAdjustment(actor: any, dto: any) {
    const tx = await this.prisma.transaction.create({
      data: {
        type: dto.type,
        amount: dto.amount,
        captainId: dto.captainId ?? null,
        rideId: dto.rideId ?? null,
        meta: { note: dto.note ?? null, createdBy: actor?.email ?? 'unknown' },
      },
    });

    return { ok: true, tx };
  }
}