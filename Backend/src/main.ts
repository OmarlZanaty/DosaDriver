import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // FIX: Explicit CORS whitelist — never use '*' on credentialed API
  const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);

  const defaultOrigins = [
    'https://dosadriver.firebaseapp.com',
    'https://dosadriver.web.app',
    'http://localhost:3000',
    'http://localhost:5173',
    'http://localhost:8080',
  ];

  app.enableCors({
    origin: [...defaultOrigins, ...allowedOrigins],
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-email', 'x-admin-password'],
    credentials: true,
  });

  app.setGlobalPrefix('v1');
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: false, transform: true }),
  );

  const port = Number(process.env.PORT) || 8080;
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 DosaDriver API listening on port ${port}`);
}

bootstrap();
