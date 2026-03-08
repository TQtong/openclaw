# OpenClaw Docker Image
# Multi-stage build for minimal runtime image
#
# Build:   docker build -t openclaw:local .
# Run:     docker-compose up -d
#
# Options:
#   --build-arg OPENCLAW_VARIANT=slim    Use slim base image (~100MB smaller)
#   --build-arg OPENCLAW_INSTALL_BROWSER=1    Pre-install Chromium for browser automation

ARG OPENCLAW_VARIANT=default

# ── Stage 1: Build ──────────────────────────────────────────────
FROM node:22-bookworm AS build

RUN corepack enable

WORKDIR /app

# Cache dependencies
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

COPY . .

RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ── Runtime base images ─────────────────────────────────────────
FROM node:22-bookworm AS base-default
LABEL org.opencontainers.image.base.name="docker.io/library/node:22-bookworm"

FROM node:22-bookworm-slim AS base-slim
LABEL org.opencontainers.image.base.name="docker.io/library/node:22-bookworm-slim"

# ── Stage 2: Runtime ────────────────────────────────────────────
FROM base-${OPENCLAW_VARIANT}
ARG OPENCLAW_VARIANT

LABEL org.opencontainers.image.source="https://github.com/openclaw/openclaw" \
      org.opencontainers.image.title="OpenClaw" \
      org.opencontainers.image.description="OpenClaw gateway and CLI runtime"

WORKDIR /app

# Install system utilities
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      procps hostname curl git openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN chown node:node /app

# Copy build artifacts
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/package.json .
COPY --from=build --chown=node:node /app/openclaw.mjs .
COPY --from=build --chown=node:node /app/skills ./skills
COPY --from=build --chown=node:node /app/docs ./docs

# Optional: Install Chromium for browser automation
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      mkdir -p /home/node/.cache/ms-playwright && \
      PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      chown -R node:node /home/node/.cache/ms-playwright && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# CLI symlink
RUN ln -sf /app/openclaw.mjs /usr/local/bin/openclaw && \
    chmod 755 /app/openclaw.mjs

ENV NODE_ENV=production

# Run as non-root
USER node

# Health check
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Default command
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
