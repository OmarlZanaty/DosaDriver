import { Injectable, Logger } from '@nestjs/common';
import { getFirebaseAdminApp } from '../auth/firebase-admin';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(private readonly prisma: PrismaService) {}

  private get messaging() {
    return getFirebaseAdminApp().messaging();
  }

  async sendToTokens(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, any> = {},
  ) {
    const valid = tokens.filter(Boolean);
    if (!valid.length) return;

    const message = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      tokens: valid,
    };

    try {
      const res = await this.messaging.sendEachForMulticast(message);
      // FIX: Handle partial FCM failures, clean up stale tokens
      const stale: string[] = [];
      res.responses.forEach((r, i) => {
        if (!r.success) {
          this.logger.warn(`FCM fail token[${i}]: ${r.error?.message}`);
          if (r.error?.code === 'messaging/registration-token-not-registered') {
            stale.push(valid[i]);
          }
        }
      });
      if (stale.length) await this._cleanStaleTokens(stale);
    } catch (e) {
      this.logger.error(`FCM multicast failed: ${e}`);
    }
  }

  private async _cleanStaleTokens(tokens: string[]) {
    try {
      await this.prisma.user.updateMany({
        where: { pushToken: { in: tokens } },
        data: { pushToken: null },
      });
    } catch (_) {}
  }

  async notifyRideStatus(ride: any, status: string) {
    const rider = await this.prisma.user.findUnique({ where: { id: ride.riderId } });
    if (!rider?.pushToken) return;

    const msgs: Record<string, [string, string]> = {
      ACCEPTED:  ['تم قبول رحلتك ✅', 'الكابتن في طريقه إليك'],
      ARRIVED:   ['الكابتن وصل 📍',   'توجه إلى السيارة الآن'],
      STARTED:   ['بدأت رحلتك 🚗',    'استمتع بالرحلة'],
      COMPLETED: ['اكتملت الرحلة 🎉', 'شكراً لاستخدامك DosaDriver'],
      CANCELED:  ['تم إلغاء الرحلة ❌','يمكنك طلب رحلة جديدة'],
    };

    const [title, body] = msgs[status] ?? ['تحديث الرحلة', ''];
    await this.sendToTokens([rider.pushToken], title, body, {
      rideId: String(ride.id), status,
    });
  }

  async notifyNewRide(ride: any) {
    // Notify all online captains with matching ride type
    const captains = await this.prisma.user.findMany({
      where: { role: 'CAPTAIN', pushToken: { not: null } },
      select: { pushToken: true },
    });
    const tokens = captains.map(c => c.pushToken!).filter(Boolean);
    if (!tokens.length) return;

    await this.sendToTokens(
      tokens,
      'طلب رحلة جديد 🚕',
      `رحلة جديدة قريبة منك — ${ride.type}`,
      { rideId: String(ride.id), type: 'NEW_RIDE' },
    );
  }
}
