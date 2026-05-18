FROM node:20-alpine

RUN apk add --no-cache bash coreutils

WORKDIR /app/backend
COPY app/web/backend ./

EXPOSE 18080
CMD ["node", "server.mjs"]
