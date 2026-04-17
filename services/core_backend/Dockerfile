FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
# Strip Windows CRLFs from package files and validate JSON before installing.
# This prevents EJSONPARSE in the container if files have CRLF/BOM issues.
RUN sed -i 's/\r$//' package.json package-lock.json || true \
 && node -e "try{JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('package.json OK');}catch(e){console.error('package.json JSONPARSE ERROR:', e.message); process.exit(1)}" \
 && npm ci

FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./
USER appuser
EXPOSE 3000
CMD ["node", "src/server.js"]
