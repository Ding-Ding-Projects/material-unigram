# Teamgram server (unofficial, open-source MTProto server), built from a pinned commit.
ARG TEAMGRAM_COMMIT=8adf26bc071159c12a62c22ad49625a73e922e79

FROM golang:1.23 AS build
ARG TEAMGRAM_COMMIT
RUN git clone https://github.com/teamgram/teamgram-server.git /app \
 && git -C /app checkout --quiet "${TEAMGRAM_COMMIT}"
WORKDIR /app
RUN ./build.sh && test -d teamgramd/bin

FROM ubuntu:24.04
ARG TEAMGRAM_COMMIT
LABEL org.opencontainers.image.title="material-unigram-fullserver" \
      org.opencontainers.image.description="Teamgram MTProto server for the Material Unigram full-server option" \
      org.opencontainers.image.source="https://github.com/Ding-Ding-Projects/material-unigram" \
      material-unigram.teamgram-commit="${TEAMGRAM_COMMIT}"
RUN apt-get update -y && apt-get install -y --no-install-recommends ffmpeg psmisc ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/teamgramd/ /app/
# The shipped key is public (it is in the source), so it is removed: every install uses its own.
RUN find /app -name 'server_pkcs1.key' -delete
COPY teamgram-start.sh /usr/local/bin/teamgram-start.sh
RUN chmod +x /usr/local/bin/teamgram-start.sh
ENV TEAMGRAM_COMMIT=${TEAMGRAM_COMMIT}
ENTRYPOINT ["/usr/local/bin/teamgram-start.sh"]
