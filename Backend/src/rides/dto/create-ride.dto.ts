import { IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateRideDto {
  @IsNumber() pickupLat: number;
  @IsNumber() pickupLng: number;
  @IsNumber() dropLat: number;
  @IsNumber() dropLng: number;

  @IsOptional() @IsString() pickupAddr?: string;
  @IsOptional() @IsString() dropAddr?: string;
  @IsOptional() @IsString() type?: string;
  @IsOptional() @IsString() paymentMethod?: string;
  @IsOptional() @IsNumber() distanceKm?: number;
  @IsOptional() @IsNumber() durationMin?: number;
}
