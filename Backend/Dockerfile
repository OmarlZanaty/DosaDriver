# =========================
# Build stage
# =========================
FROM node:20-bookworm-slim AS build
WORKDIR /app

RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci

COPY . .

RUN npx prisma generate
RUN npm run build


# =========================
# Runtime stage
# =========================
FROM node:20-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma

RUN addgroup --system appgroup && adduser --system --no-create-home appuser --ingroup appgroup
USER appuser

EXPOSE 8080

# ✅ IMPORTANT: do NOT run migrations here (it can block startup on Cloud Run)
CMD ["node", "dist/src/main.js"]