FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --prefer-offline --no-audit

COPY . .

RUN npm run build

FROM node:18-alpine

WORKDIR /app

RUN npm install -g http-server

COPY --from=builder /app/dist /app/dist

EXPOSE 3000

CMD ["http-server", "dist", "-p", "3000", "-c-1", "-a", "0.0.0.0"]
