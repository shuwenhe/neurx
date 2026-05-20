FROM alpine:3.20

RUN apk add --no-cache bash coreutils socat

WORKDIR /app/service
COPY app/service ./

EXPOSE 18080
CMD ["bash", "http_server.sh"]
