FROM node:20-alpine AS deps
WORKDIR /app/frontend
COPY app/web/frontend/package.json ./
RUN npm install

FROM node:20-alpine AS builder
WORKDIR /app/frontend
COPY --from=deps /app/frontend/node_modules ./node_modules
COPY app/web/frontend ./
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app/frontend
ENV NODE_ENV=production
ENV PORT=3000
COPY --from=builder /app/frontend/.next/standalone ./
COPY --from=builder /app/frontend/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "server.js"]
