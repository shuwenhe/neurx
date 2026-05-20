FROM node:20-alpine AS deps
WORKDIR /app/web
COPY app/web/package.json ./
RUN npm install

FROM node:20-alpine AS builder
WORKDIR /app/web
COPY --from=deps /app/web/node_modules ./node_modules
COPY app/web ./
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app/web
ENV NODE_ENV=production
ENV PORT=3000
COPY --from=builder /app/web/.next/standalone ./
COPY --from=builder /app/web/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "server.js"]
