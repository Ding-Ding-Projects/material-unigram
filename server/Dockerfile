# Material Unigram proxy: Telegram's official MTProxy plus a small dashboard.
# Build:  docker build -t material-unigram-proxy server
# Run:    see server/compose.yaml or host.bat at the repository root.

ARG MTPROXY_COMMIT=69f2f083b57bbd94932cb9f4f32155f33e719ff1

FROM debian:bookworm-slim AS build
ARG MTPROXY_COMMIT
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates build-essential libssl-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone https://github.com/TelegramMessenger/MTProxy.git . \
 && git checkout --quiet "${MTPROXY_COMMIT}"
# -fcommon: the sources define the same globals in several files, which GCC 10+ rejects by default.
RUN make -j"$(nproc)" CFLAGS="-O3 -std=gnu11 -Wall -mpclmul -march=core2 -mfpmath=sse -mssse3 -fno-strict-aliasing -fno-strict-overflow -fwrapv -DAES=1 -DCOMMIT=\\\"${MTPROXY_COMMIT}\\\" -D_GNU_SOURCE=1 -D_FILE_OFFSET_BITS=64 -fcommon" \
 && test -x objs/bin/mtproto-proxy

FROM node:22-bookworm-slim
ARG MTPROXY_COMMIT
LABEL org.opencontainers.image.title="material-unigram-proxy" \
      org.opencontainers.image.description="Telegram MTProxy with the Material Unigram dashboard" \
      org.opencontainers.image.source="https://github.com/Ding-Ding-Projects/material-unigram" \
      org.opencontainers.image.licenses="GPL-3.0" \
      material-unigram.mtproxy-commit="${MTPROXY_COMMIT}"
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl libssl3 zlib1g \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy
COPY dashboard /opt/dashboard
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && mkdir -p /data
ENV MTPROXY_COMMIT=${MTPROXY_COMMIT} \
    PROXY_PORT=443 \
    DASHBOARD_PORT=8080 \
    DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 443 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${DASHBOARD_PORT}/healthz" || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
