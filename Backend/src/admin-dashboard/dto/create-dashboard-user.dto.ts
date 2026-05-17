import { IsArray, IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateDashboardUserDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(6)
  password!: string; // simple approach you asked for

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  permissions?: string[]; // screen keys

  // role is restricted in controller to SUPER_ADMIN only
  @IsOptional()
  @IsString()
  role?: 'SUPER_ADMIN' | 'DASHBOARD_USER';
}