# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./

# --- Runtime stage ---
FROM node:20-alpine
WORKDIR /app

# Non-root user for defense in depth
RUN addgroup -S formflow && adduser -S formflow -G formflow

COPY --from=build /app /app

# Build-time metadata only — this is version info, not a secret.
# Actual secrets (DB_PASSWORD, JWT_SECRET) are injected at `docker run`/compose time via env_file.
ARG GIT_SHA=unknown
ARG BUILD_VERSION=dev
ARG BUILT_AT=unknown
ENV GIT_SHA=${GIT_SHA} \
    BUILD_VERSION=${BUILD_VERSION} \
    BUILT_AT=${BUILT_AT} \
    PORT=3000

USER formflow
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
