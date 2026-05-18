import { Injectable, Logger } from '@nestjs/common';
import { getFirebaseAdminApp } from '../auth/firebase-admin';
import { PrismaService } from '../prisma/prisma.service';

type RideLike = {
  id: number; status: any; stateVersion?: number;
  riderId: number; captainId: number | null;
  pickupLat: number; pickupLng: number; pickupAddr: string | null;
  dropLat: number; dropLng: number; dropAddr: string | null;
  createdAt: Date; updatedAt: Date;
  suggestedFare?: number | null; finalFare?: number | null;
  type?: any; paymentMethod?: any;
  transferProofUrl?: string | null;
  transferConfirmedAt?: Date | null;
};

type CaptainInfo = { firebaseUid: string | null; phone: string | null; name: string | null };
type RiderInfo = { firebaseUid: string | null };

@Injectable()
export class FirestoreBridgeService {
  private readonly logger = new Logger(FirestoreBridgeService.name);
  constructor(private readonly prisma: PrismaService) {}

  private firestore() { return getFirebaseAdminApp().firestore(); }

  /**
   * FIX: Removed direct Firestore writes from client apps.
   * Backend is the SOLE writer to rides/{rideId} — eliminates dual-write race.
   */
  async safeUpsertRideMirror(ride: RideLike, extra?: { price?: number; rideType?: string }): Promise<void> {
    try {
      let captainUid: string | null = null;
      let captainPhone: string | null = null;
      let captainName: string | null = null;
      let riderFirebaseUid: string | null = null;

      if (ride.captainId) {
        const captain = await this.prisma.user.findUnique({ where: { id: ride.captainId } });
        captainUid   = captain?.firebaseUid ?? null;
        captainPhone = captain?.phone ?? null;
        captainName  = captain?.name  ?? null;
      }

      const rider = await this.prisma.user.findUnique({ where: { id: ride.riderId } });
      riderFirebaseUid = rider?.firebaseUid ?? null;

      const status = String(ride.status ?? '').toUpperCase();
      const terminal = status === 'COMPLETED' || status === 'CANCELED';
      const fare = (ride as any).finalFare ?? ride.suggestedFare ?? extra?.price ?? null;

      const payload: Record<string, any> = {
        id: ride.id,
        status,
        stateVersion: (ride as any).stateVersion ?? 0,
        terminal,
        backendExists: true,
        lastBackendSyncAt: Date.now(),
        captainUid,
        captainPhone,
        captainName,
        riderFirebaseUid,
        riderId:   ride.riderId,
        captainId: ride.captainId ?? null,
        pickup: { lat: ride.pickupLat, lng: ride.pickupLng, addr: ride.pickupAddr ?? null },
        drop:   { lat: ride.dropLat,   lng: ride.dropLng,   addr: ride.dropAddr   ?? null },
        price:    fare,
        rideType: extra?.rideType ?? String(ride.type ?? ''),
        paymentMethod: String((ride as any).paymentMethod ?? 'CASH'),
        transferProofUrl:    (ride as any).transferProofUrl ?? null,
        transferConfirmedAt: (ride as any).transferConfirmedAt
          ? new Date((ride as any).transferConfirmedAt).toISOString()
          : null,
        createdAt:   ride.createdAt?.toISOString?.() ?? null,
        updatedAt:   ride.updatedAt?.toISOString?.() ?? null,
        source: 'backend_v2',
      };

      await this.firestore().collection('rides').doc(String(ride.id)).set(payload, { merge: true });
    } catch (err: any) {
      this.logger.error(`Firestore mirror failed ride=${ride?.id}: ${err?.message}`);
      // FIX: Enqueue for retry instead of silently dropping
      await this._enqueueRetry(ride.id, String(ride.status), err.message).catch(() => {});
    }
  }

  private async _enqueueRetry(rideId: number, status: string, error: string) {
    await this.prisma.firestoreSyncQueue.create({
      data: {
        rideId,
        status,
        lastError: error.slice(0, 500),
        nextRetry: new Date(Date.now() + 30_000), // retry in 30s
      },
    });
  }

  async mirrorRideRating(
    rideId: number,
    rating: number,
    comment: string,
    captainFirebaseUid: string | null,
  ): Promise<void> {
    try {
      const ratedAt = new Date().toISOString();
      await this.firestore().collection('rides').doc(String(rideId)).set(
        { clientRating: rating, clientComment: comment, ratedAt },
        { merge: true },
      );
      await this.firestore().collection('ride_ratings').add({
        rideId: String(rideId),
        rating,
        comment,
        captainUid: captainFirebaseUid,
        createdAt: ratedAt,
      });
    } catch (err: any) {
      this.logger.error(`mirrorRideRating failed ride=${rideId}: ${err?.message}`);
    }
  }
}
