import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { UsersModule } from '../users/users.module';
import { RidesController } from './rides.controller';
import { RidesService } from './rides.service';
import { FirestoreBridgeService } from '../firestore/firestore-bridge.service';
import { FirestoreModule } from '../firestore/firestore.module';
import { NotificationModule } from '../notifications/notification.module';


@Module({
  imports: [PrismaModule, UsersModule,FirestoreModule,NotificationModule],
  controllers: [RidesController],
  providers: [RidesService, FirestoreBridgeService], // ✅ add here

  exports: [RidesService],
})
export class RidesModule {}
