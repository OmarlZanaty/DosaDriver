import { Injectable, Logger } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import * as admin from 'firebase-admin';

type FirebaseDecoded = admin.auth.DecodedIdToken;

/** 
 * FIX: Role is read ONLY from Firebase Custom Claims.
 * Never from Firestore docs (prevents role escalation attack).
 */
function parseRoleFromClaims(decoded: FirebaseDecoded): UserRole {
  const claim = (decoded as any).role ?? (decoded as any).claims?.role ?? null;
  if (!claim) return UserRole.RIDER;
  const r = String(claim).trim().toUpperCase();
  if (r === 'CAPTAIN') return UserRole.CAPTAIN;
  if (r === 'ADMIN') return UserRole.ADMIN;
  if (r === 'SUPER_ADMIN') return UserRole.ADMIN;
  return UserRole.RIDER;
}

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(private readonly prisma: PrismaService) {}

  async upsertFromFirebase(decoded: FirebaseDecoded) {
    const uid = decoded.uid;
    const roleFromClaims = parseRoleFromClaims(decoded);

    let user = await this.prisma.user.findUnique({ where: { firebaseUid: uid } });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          firebaseUid: uid,
          role: roleFromClaims,
          name: decoded.name ?? null,
          phone: decoded.phone_number ?? null,
        },
      });
    } else if (user.role !== roleFromClaims && roleFromClaims !== UserRole.RIDER) {
      // Only update role if custom claim explicitly says CAPTAIN or ADMIN
      user = await this.prisma.user.update({
        where: { firebaseUid: uid },
        data: { role: roleFromClaims },
      });
    }

    return user;
  }

  async setPushToken(userId: number, token: string) {
    return this.prisma.user.update({ where: { id: userId }, data: { pushToken: token } });
  }

  async findByFirebaseUid(firebaseUid: string) {
    return this.prisma.user.findUnique({ where: { firebaseUid } });
  }

  /** Called by admin to set role — also sets Firebase Custom Claim */
  async setRole(firebaseUid: string, role: UserRole) {
    await admin.auth().setCustomUserClaims(firebaseUid, { role: role.toString() });
    return this.prisma.user.update({ where: { firebaseUid }, data: { role } });
  }

  async updateProfile(firebaseUid: string, data: { name?: string | null; phone?: string | null }) {
    const phone = data.phone?.trim() || null;
    const name  = data.name?.trim()  || null;

    return this.prisma.$transaction(async (tx) => {
      if (phone) {
        const other = await tx.user.findFirst({ where: { phone, NOT: { firebaseUid } } });
        if (other) await tx.user.update({ where: { id: other.id }, data: { phone: null } });
      }
      return tx.user.update({ where: { firebaseUid }, data: { phone, name } });
    });
  }

  async getConfig(key: string) {
    return this.prisma.appConfig.findUnique({ where: { key } });
  }

  async setConfig(key: string, data: Prisma.InputJsonValue, version?: number) {
    return this.prisma.appConfig.upsert({
      where: { key },
      create: { key, data, version: version ?? 1 },
      update: { data, ...(version != null ? { version } : {}) },
    });
  }
}
