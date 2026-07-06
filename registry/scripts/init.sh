#!/bin/sh
set -e

REGISTRY_IP="${REGISTRY_IP:-localhost}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-changeme}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$REGISTRY_DIR/certs"
AUTH_DIR="$REGISTRY_DIR/auth"

mkdir -p "$CERTS_DIR" "$AUTH_DIR"

if echo "$REGISTRY_IP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  SAN="IP:$REGISTRY_IP,DNS:localhost"
else
  SAN="DNS:$REGISTRY_IP,DNS:localhost"
fi

if [ ! -f "$CERTS_DIR/registry.crt" ] || [ "$FORCE" = "1" ]; then
  echo "Генерация TLS-сертификата для $REGISTRY_IP (SAN: $SAN)..."
  openssl req -x509 -newkey rsa:4096 \
    -keyout "$CERTS_DIR/registry.key" \
    -out "$CERTS_DIR/registry.crt" \
    -days 365 -nodes \
    -subj "/CN=$REGISTRY_IP" \
    -addext "subjectAltName=$SAN"
fi

echo "Создание htpasswd для пользователя $REGISTRY_USER..."
if command -v htpasswd >/dev/null 2>&1; then
  htpasswd -Bbn "$REGISTRY_USER" "$REGISTRY_PASSWORD" > "$AUTH_DIR/htpasswd"
elif docker info >/dev/null 2>&1; then
  docker run --rm httpd:2.4-alpine htpasswd -Bbn "$REGISTRY_USER" "$REGISTRY_PASSWORD" > "$AUTH_DIR/htpasswd"
else
  HASH="$(openssl passwd -apr1 "$REGISTRY_PASSWORD")"
  printf '%s:%s\n' "$REGISTRY_USER" "$HASH" > "$AUTH_DIR/htpasswd"
fi

echo "Готово:"
echo "  certs: $CERTS_DIR/registry.crt"
echo "  auth:  $AUTH_DIR/htpasswd"
echo ""
echo "Доверие сертификату на клиенте (Linux/VPS):"
echo "  sudo mkdir -p /etc/docker/certs.d/${REGISTRY_IP}:5000"
echo "  sudo cp $CERTS_DIR/registry.crt /etc/docker/certs.d/${REGISTRY_IP}:5000/ca.crt"
echo "  sudo systemctl restart docker"
