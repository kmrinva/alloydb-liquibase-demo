#!/usr/bin/env bash
set -euo pipefail

# This script expects these ENV VARS at runtime:
#   INSTANCE_URI  (AlloyDB instance URI)
#   DB_NAME       (database name)
#   DB_USER       (database user)
#   DB_PASSWORD   (database password)
# Optional:
#   PROXY_PORT=5432
#   LB_CHANGELOG_FILE (default: /workspace/liquibase/changelog.xml)
#   LB_PROPERTIES    (default: /workspace/liquibase/liquibase.properties)

PROXY_PORT="${PROXY_PORT:-5432}"
LB_PROPERTIES="${LB_PROPERTIES:-/workspace/liquibase/liquibase.properties}"
LB_CHANGELOG_FILE="${LB_CHANGELOG_FILE:-/workspace/liquibase/changelog.xml}"

echo "[setup] Installing tools..."
apt-get update -y
apt-get install -y --no-install-recommends curl ca-certificates tar openjdk-17-jre-headless
rm -rf /var/lib/apt/lists/*

LB_VER="4.29.2"
echo "[setup] Installing Liquibase ${LB_VER}..."
curl -fsSL "https://github.com/liquibase/liquibase/releases/download/v${LB_VER}/liquibase-${LB_VER}.tar.gz" \
  | tar -xz -C /usr/local
ln -sf /usr/local/liquibase/liquibase /usr/local/bin/liquibase

PVER="1.13.6"
echo "[setup] Installing AlloyDB Auth Proxy ${PVER}..."
curl -fsSL "https://storage.googleapis.com/alloydb-auth-proxy/v${PVER}/alloydb-auth-proxy.linux.amd64" \
  -o /usr/local/bin/alloydb-auth-proxy
chmod +x /usr/local/bin/alloydb-auth-proxy

echo "[proxy] Starting AlloyDB Auth Proxy on :${PROXY_PORT}..."
nohup alloydb-auth-proxy --port "${PROXY_PORT}" "${INSTANCE_URI}" >/tmp/proxy.log 2>&1 &
sleep 3

echo "[liquibase] Applying changesets..."
liquibase \
  --defaultsFile="${LB_PROPERTIES}" \
  --url="jdbc:postgresql://127.0.0.1:${PROXY_PORT}/${DB_NAME}" \
  --username="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  --changeLogFile="${LB_CHANGELOG_FILE}" \
  update

echo "[done] Liquibase update finished."
