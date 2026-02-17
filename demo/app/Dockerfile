# Multi-stage Dockerfile for the demo Node.js microservice
# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Stage 2: Final production image
FROM node:20-alpine AS runner
WORKDIR /app

# Security: run as non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nodeuser

# Copy production dependencies and source
COPY --from=deps /app/node_modules ./node_modules
COPY --chown=nodeuser:nodejs . .

USER nodeuser

# Expose the service port
EXPOSE 3000

# Health check for Docker
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "index.js"]
