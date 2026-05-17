import { IsIn, IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateAdjustmentDto {
  @IsIn(['BONUS', 'PENALTY', 'REFUND'])
  type: 'BONUS' | 'PENALTY' | 'REFUND';

  @IsNumber()
  amount: number;

  @IsOptional()
  @IsInt()
  captainId?: number;

  @IsOptional()
  @IsInt()
  rideId?: number;

  @IsOptional()
  @IsString()
  note?: string;
}