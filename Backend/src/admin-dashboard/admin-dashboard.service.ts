import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { getFirebaseAuth } from '../firebase/firebase-admin.provider';
import { CreateDashboardUserDto } from './dto/create-dashboard-user.dto';
import { UpdateDashboardUserDto } from './dto/update-dashboard-user.dto';

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async me(firebaseUid: string) {
    const user = await this.prisma.dashboardUser.findUnique({
      where: { firebaseUid },
      include: { permissions: true },
    });

    if (!user) throw new ForbiddenException('Not a dashboard user');

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      isActive: user.isActive,
      permissions: user.permissions.map((p) => p.key),
    };
  }

  async listUsers() {
    const users = await this.prisma.dashboardUser.findMany({
      orderBy: [{ role: 'asc' }, { id: 'desc' }],
      include: { permissions: true },
    });

    return users.map((u) => ({
      id: u.id,
      email: u.email,
      name: u.name,
      role: u.role,
      isActive: u.isActive,
      permissions: u.permissions.map((p) => p.key),
      createdAt: u.createdAt,
      updatedAt: u.updatedAt,
    }));
  }

  // Function to update Firebase role claims
  async setRoleInFirebase(firebaseUid: string, role: string) {
    const auth = getFirebaseAuth();
    
    if (!firebaseUid || !role) {
      throw new BadRequestException('Firebase UID and role must be provided.');
    }

    try {
      await auth.setCustomUserClaims(firebaseUid, { role }); // Update role as custom claim in Firebase
    } catch (error) {
      throw new Error(`Error setting custom claim: ${error.message}`);
    }
  }

  // Only one updateUser function here
  async updateUser(
    id: number,
    dto: UpdateDashboardUserDto,
    actorRole: 'SUPER_ADMIN' | 'DASHBOARD_USER',
  ) {
    if (actorRole !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only SUPER_ADMIN can edit users');
    }

    const existing = await this.prisma.dashboardUser.findUnique({
      where: { id },
      include: { permissions: true },
    });
    if (!existing) throw new NotFoundException('Dashboard user not found');

    // Update Firebase Role after validating
    if (existing.firebaseUid && dto.role) {
      await this.setRoleInFirebase(existing.firebaseUid, dto.role); // Update Firebase custom claim role
    }

    // Proceed with your Prisma updates or other logic
    const updated = await this.prisma.dashboardUser.update({
      where: { id },
      data: {
        email: dto.email ? dto.email.toLowerCase() : undefined,
        name: dto.name !== undefined ? (dto.name ?? null) : undefined,
        isActive: dto.isActive,
        role: dto.role as any,
        permissions: dto.permissions
          ? {
              deleteMany: {},
              create: dto.permissions.map((key) => ({ key })),
            }
          : undefined,
      },
      include: { permissions: true },
    });

    return {
      id: updated.id,
      email: updated.email,
      name: updated.name,
      role: updated.role,
      isActive: updated.isActive,
      permissions: updated.permissions.map((p) => p.key),
      updatedAt: updated.updatedAt,
    };
  }

  async getUser(id: number) {
    const user = await this.prisma.dashboardUser.findUnique({
      where: { id },
      include: { permissions: true },
    });
    if (!user) throw new NotFoundException('Dashboard user not found');

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      isActive: user.isActive,
      permissions: user.permissions.map((p) => p.key),
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  async createUser(dto: CreateDashboardUserDto, actorRole: 'SUPER_ADMIN' | 'DASHBOARD_USER') {
    // Only super admin can create dashboard users
    if (actorRole !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only SUPER_ADMIN can create users');
    }

    const auth = getFirebaseAuth();

    // Create firebase user first
    let fbUser;
    try {
      fbUser = await auth.createUser({
        email: dto.email,
        password: dto.password,
        displayName: dto.name ?? undefined,
        disabled: false,
      });
    } catch (e: any) {
      throw new BadRequestException(`Firebase createUser failed: ${e?.message ?? 'unknown'}`);
    }

    // Create DB row + permissions
    const roleToSet = dto.role ?? 'DASHBOARD_USER';
    if (roleToSet === 'SUPER_ADMIN' && actorRole !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only SUPER_ADMIN can assign SUPER_ADMIN');
    }

    try {
      const created = await this.prisma.dashboardUser.create({
        data: {
          firebaseUid: fbUser.uid,
          email: dto.email.toLowerCase(),
          name: dto.name ?? null,
          role: roleToSet,
          isActive: true,
          permissions: dto.permissions?.length
            ? {
                create: dto.permissions.map((key) => ({ key })),
              }
            : undefined,
        },
        include: { permissions: true },
      });

      return {
        id: created.id,
        email: created.email,
        name: created.name,
        role: created.role,
        isActive: created.isActive,
        permissions: created.permissions.map((p) => p.key),
      };
    } catch (e: any) {
      // If DB fails, rollback firebase user to avoid orphan
      await auth.deleteUser(fbUser.uid).catch(() => undefined);
      throw new BadRequestException(`DB create failed: ${e?.message ?? 'unknown'}`);
    }
  }

  async deleteUser(id: number, actorRole: 'SUPER_ADMIN' | 'DASHBOARD_USER') {
    if (actorRole !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Only SUPER_ADMIN can delete users');
    }

    const existing = await this.prisma.dashboardUser.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Dashboard user not found');

    if (existing.role === 'SUPER_ADMIN') {
      const superCount = await this.prisma.dashboardUser.count({
        where: { role: 'SUPER_ADMIN', isActive: true },
      });
      if (superCount <= 1) {
        throw new BadRequestException('Cannot delete the last SUPER_ADMIN');
      }
    }

    // Disable firebase user first (safer than delete)
    const auth = getFirebaseAuth();
    await auth.updateUser(existing.firebaseUid, { disabled: true }).catch(() => undefined);

    // Delete DB row (permissions cascade)
    await this.prisma.dashboardUser.delete({ where: { id } });

    return { ok: true };
  }
}