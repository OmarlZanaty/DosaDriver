import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FirestoreBridgeService } from './firestore-bridge.service';

@Injectable()
export class FirestoreSyncConsumerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(FirestoreSyncConsumerService.name);
  private _timer: ReturnType<typeof setInterval> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly bridge: FirestoreBridgeService,
  ) {}

  onModuleInit() {
    this.logger.log('FirestoreSyncQueue consumer started (poll every 30s)');
    this._timer = setInterval(() => this._processQueue(), 30_000);
    this._processQueue();
  }

  onModuleDestroy() {
    if (this._timer) clearInterval(this._timer);
  }

  private async _processQueue() {
    try {
      const now = new Date();
      const entries = await this.prisma.firestoreSyncQueue.findMany({
        where: { nextRetry: { lte: now } },
        take: 20,
        orderBy: { nextRetry: 'asc' },
      });

      for (const entry of entries) {
        await this._retry(entry);
      }
    } catch (err: any) {
      this.logger.error(`Queue poll error: ${err.message}`);
    }
  }

  private async _retry(entry: { id: number; rideId: number; attempts: number }) {
    try {
      const ride = await this.prisma.ride.findUnique({ where: { id: entry.rideId } });
      if (!ride) {
        await this.prisma.firestoreSyncQueue.delete({ where: { id: entry.id } });
        return;
      }

      await this.bridge.safeUpsertRideMirror(ride);
      await this.prisma.firestoreSyncQueue.delete({ where: { id: entry.id } });
      this.logger.log(`Retry succeeded ride=${entry.rideId} (attempt=${entry.attempts + 1})`);
    } catch (err: any) {
      const nextDelay = Math.min(30_000 * Math.pow(2, entry.attempts), 3_600_000);
      await this.prisma.firestoreSyncQueue.update({
        where: { id: entry.id },
        data: {
          attempts: { increment: 1 },
          lastError: err.message?.slice(0, 500) ?? 'unknown',
          nextRetry: new Date(Date.now() + nextDelay),
        },
      });
      this.logger.warn(`Retry failed ride=${entry.rideId} (attempt=${entry.attempts + 1}, next=${nextDelay}ms)`);
    }
  }
}
