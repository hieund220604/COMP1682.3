# === Stage 1: Build TypeScript ===
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/

# Tăng RAM cho tsc để tránh OOM
RUN NODE_OPTIONS=--max-old-space-size=1024 npm run build

# === Stage 2: Production (chỉ chứa code đã compile) ===
FROM node:20-alpine
WORKDIR /app

# Security: chạy với user non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy code đã compile từ stage 1
COPY --from=builder /app/dist ./dist

# Tạo thư mục uploads
RUN mkdir -p uploads && chown -R appuser:appgroup /app

USER appuser
EXPOSE 8080

CMD ["node", "dist/index.js"]
