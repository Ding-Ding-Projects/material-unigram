# MySQL with Teamgram's schema from the same pinned commit, applied on first start.
ARG TEAMGRAM_COMMIT=8adf26bc071159c12a62c22ad49625a73e922e79

FROM alpine/git:2.47.2 AS sql
ARG TEAMGRAM_COMMIT
RUN git clone https://github.com/teamgram/teamgram-server.git /src \
 && git -C /src checkout --quiet "${TEAMGRAM_COMMIT}"

FROM mysql:8.0.40
COPY --from=sql /src/teamgramd/deploy/sql/ /docker-entrypoint-initdb.d/
