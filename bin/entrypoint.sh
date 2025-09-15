#!/usr/bin/env bash
set -euo pipefail

# Required env:
# INSTANCE_URI, DB_NAME, DB_USER, DB_PASSWORD
PROXY_PORT="${PROXY_PORT:-5432}"
LB_PROPERTIES="${LB_PROPERTIES:-/workspace/liquibase/liquibase.properties}"
LB_CHANGELOG_FILE="${LB_CHANGELOG_FILE:-/workspace/liquibase/changelog.xml}"

echo "[proxy] Starting AlloyDB Auth Proxy on :${PROXY_PORT} ..."
nohup alloydb-auth-proxy --port "${PROXY_PORT}" "${INSTANCE_URI}" >/tmp/proxy.log 2>&1 &
sleep 3

echo "[liquibase] Running update..."
liquibase \
  --defaultsFile="${LB_PROPERTIES}" \
  --url="jdbc:postgresql://127.0.0.1:${PROXY_PORT}/${DB_NAME}" \
  --username="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  --changeLogFile="${LB_CHANGELOG_FILE}" \
  update

echo "[done] Liquibase update finished."
