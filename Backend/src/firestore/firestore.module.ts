import { Module } from '@nestjs/common';
import { FirestoreBridgeService } from './firestore-bridge.service';
import { FirestoreSyncConsumerService } from './firestore-sync-consumer.service';

@Module({
  providers: [FirestoreBridgeService, FirestoreSyncConsumerService],
  exports: [FirestoreBridgeService],
})
export class FirestoreModule {}
