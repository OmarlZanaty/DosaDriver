import { Body, Controller, Post, UseGuards, Req, BadRequestException } from '@nestjs/common';
import { NotificationService } from './notification.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@prisma/client';
import { UsersService } from '../users/users.service';

@Controller('notifications')
export class NotificationController {
  constructor(
    private readonly notificationService: NotificationService,
    private readonly usersService: UsersService,
  ) {}

  // register device token for current user
  @UseGuards(FirebaseAuthGuard)
  @Post('register')
  async registerToken(@Body() body: { token: string }, @Req() req: any) {
    const token = (body?.token ?? '').trim();
    if (!token) throw new BadRequestException('رمز الإشعارات مطلوب');
    await this.usersService.setPushToken(req.dbUser.id, token);
    return { ok: true };
  }

  // admin broadcast endpoint
  @UseGuards(FirebaseAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @Post('broadcast')
  async adminBroadcast(@Body() body: { role?: UserRole; title: string; body: string }) {
    const { role, title, body: msg } = body;
    const targetRole = role ?? null;
    await this.notificationService.notifyAdminBroadcast(targetRole, title, msg);
    return { ok: true };
  }
}
