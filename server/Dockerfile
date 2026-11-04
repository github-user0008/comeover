# syntax=docker/dockerfile:1

FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8787 \
    HOST=0.0.0.0 \
    COMEOVER_WEB_DIR=/app/web

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

# The Flutter web client, built by CI (or manually, see deploy/umbrel/README.md)
# into server/web-dist/ before this image is assembled. When web-dist only has
# the placeholder, the relay serves the API/dashboard as before.
COPY web-dist ./web

EXPOSE 8787
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "dist/index.js"]
