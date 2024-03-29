ARG NODE_IMAGE_TAG=17.5.0-alpine3.15

# Install dependencies only when needed
FROM node:$NODE_IMAGE_TAG AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY ./emiweb/package.json ./emiweb/package-lock.json ./
RUN npm ci --only-production

# Rebuild the source code only when needed
FROM node:$NODE_IMAGE_TAG AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY ./emiweb/ ./

RUN npm run build

# Production image, copy all the files and run next
FROM node:$NODE_IMAGE_TAG AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 13000

ENV PORT=13000 \
    NEXT_TELEMETRY_DISABLED=1 \
    EMIWEB_EMIGATE_URL=http://localhost:12000 \
    EMIWEB_COOKIE_DOMAIN=localhost

CMD ["node", "server.js"]
