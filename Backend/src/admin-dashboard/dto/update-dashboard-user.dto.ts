import { IsArray, IsBoolean, IsEmail, IsOptional, IsString } from 'class-validator';

export class UpdateDashboardUserDto {
  @IsOptional()
  @IsEmail()
  email?: string; // If you want to allow changing email; optional.

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  permissions?: string[];

  @IsOptional()
  @IsString()
  role?: 'SUPER_ADMIN' | 'DASHBOARD_USER';
}