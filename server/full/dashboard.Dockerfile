# Dashboard and key step for the full server. Build context: the server/ folder.
FROM node:22-bookworm-slim
COPY dashboard /opt/dashboard
ENV DASHBOARD_MODE=full DASHBOARD_PORT=8080 KEYS_DIR=/keys
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:8080/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
CMD ["node", "/opt/dashboard/server.js"]
