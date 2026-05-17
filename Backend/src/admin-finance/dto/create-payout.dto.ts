import { IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreatePayoutDto {
  @IsInt()
  captainId: number;

  @IsNumber()
  amount: number;

  @IsOptional()
  @IsString()
  method?: string;

  @IsOptional()
  @IsString()
  reference?: string;

  @IsOptional()
  @IsString()
  proofUrl?: string;

  @IsOptional()
  @IsString()
  note?: string;
}