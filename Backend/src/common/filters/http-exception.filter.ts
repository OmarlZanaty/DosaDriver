import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Response } from 'express';

const AR_MESSAGES: Record<number, string> = {
  400: 'بيانات غير صالحة',
  401: 'غير مصرح لك بالوصول',
  403: 'ليس لديك صلاحية',
  404: 'العنصر غير موجود',
  409: 'تعارض في البيانات',
  422: 'بيانات غير قابلة للمعالجة',
  429: 'طلبات كثيرة، يرجى الانتظار',
  500: 'خطأ في الخادم، يرجى المحاولة لاحقاً',
};

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx  = host.switchToHttp();
    const res  = ctx.getResponse<Response>();

    const status = exception instanceof HttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;

    const raw = exception instanceof HttpException ? exception.getResponse() : null;

    // FIX: Never leak stack traces or internal details to client
    const devMessage = typeof raw === 'string'
      ? raw
      : (raw as any)?.message ?? 'Internal server error';

    const arabicMessage = AR_MESSAGES[status] ?? 'حدث خطأ غير متوقع';

    if (status >= 500) {
      this.logger.error(`[${status}] ${devMessage}`, exception instanceof Error ? exception.stack : '');
    }

    res.status(status).json({
      ok:      false,
      status,
      message: arabicMessage,
      detail:  process.env.NODE_ENV === 'development' ? devMessage : undefined,
    });
  }
}
