#!/bin/sh
# Puts this install's own server key and generated passwords into Teamgram's service configs,
# then starts every Teamgram service. Keys come from the shared /keys volume, made by the
# dashboard's key step before this container starts.
set -eu

KEY=/keys/server_pkcs1.key
FINGERPRINT_FILE=/keys/server_fingerprint.txt
if [ ! -s "$KEY" ] || [ ! -s "$FINGERPRINT_FILE" ]; then
  echo "teamgram: the server key is missing from /keys; the key step must run first" >&2
  exit 66
fi
IFS= read -r FINGERPRINT < "$FINGERPRINT_FILE"

: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"
: "${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
: "${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"

for config in /app/etc2/*.yaml; do
  sed -i \
    -e "s#KeyFingerprint: \"[0-9]*\"#KeyFingerprint: \"$FINGERPRINT\"#g" \
    -e "s#teamgram:teamgram@tcp(mysql:3306)#teamgram:${MYSQL_PASSWORD}@tcp(mysql:3306)#g" \
    -e "s#AccessKeyID: minio\$#AccessKeyID: ${MINIO_ROOT_USER}#g" \
    -e "s#SecretAccessKey: miniostorage#SecretAccessKey: ${MINIO_ROOT_PASSWORD}#g" \
    -e "s#Endpoint: jaeger:4317#Endpoint: \"\"#g" \
    "$config"
done

# Every service that loads the key reads it as ./server_pkcs1.key from /app/bin.
install -m 600 "$KEY" /app/bin/server_pkcs1.key
echo "teamgram: using this install's key, fingerprint $FINGERPRINT"

cd /app/bin
./runall-docker.sh
exec tail -f /dev/null
