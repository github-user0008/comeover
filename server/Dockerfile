# syntax=docker/dockerfile:1

# The build context is the REPO ROOT (CI uses `context: .` + `file:
# server/Dockerfile`), so every server path below is prefixed with `server/`.
FROM node:22-alpine AS build
WORKDIR /app
COPY server/package*.json ./
RUN npm ci
COPY server/tsconfig.json ./
COPY server/src ./src
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8787 \
    HOST=0.0.0.0 \
    COMEOVER_WEB_DIR=/app/web

COPY server/package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

# The Flutter web client arrives as an additional build context (web-src)
# provided by CI (or manually via --build-context web-src=<app>/build/web).
# Without it the build fails loudly; the previous bundled-in-placeholder
# approach proved fragile with subdirectory Dockerfiles.
COPY --from=web-src . ./web

EXPOSE 8787
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "dist/index.js"]
