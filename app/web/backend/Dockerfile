FROM alpine:3.20

RUN apk add --no-cache bash coreutils socat

WORKDIR /app/backend
COPY app/web/backend ./

EXPOSE 18080
CMD ["bash", "http_server.sh"]
