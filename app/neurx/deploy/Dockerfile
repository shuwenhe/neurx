FROM debian:stable-slim
WORKDIR /app
COPY . /app
RUN apt-get update && apt-get install -y --no-install-recommends bash coreutils && rm -rf /var/lib/apt/lists/*
CMD ["/bin/bash", "/app/bin/serve.sh"]
