#!/usr/bin/env bash
set -euo pipefail

# Required env (already provided via Job env or your workflow update step):
#   INSTANCE_URI, DB_NAME, DB_USER, DB_PASSWORD
# Optional:
#   PROXY_PORT=5432
#   LB_CHANGELOG_FILE (default: /workspace/liquibase/changelog.xml)
#   LB_PROPERTIES    (default: /workspace/liquibase/liquibase.properties)

PROXY_PORT="${PROXY_PORT:-5432}"
LB_PROPERTIES="${LB_PROPERTIES:-/workspace/liquibase/liquibase.properties}"
LB_CHANGELOG_FILE="${LB_CHANGELOG_FILE:-/workspace/liquibase/changelog.xml}"

# Writable scratch locations in Cloud Run
TOOLS_DIR="/tmp/tools"
JRE_DIR="/tmp/jre"
LB_DIR="/tmp/liquibase"
PROXY_BIN="/tmp/alloydb-auth-proxy"

mkdir -p "${TOOLS_DIR}" "${JRE_DIR}" "${LB_DIR}"

echo "[setup] Downloading portable JRE 17 to ${JRE_DIR}..."
# Temurin JRE 17 (Linux x64). If this URL ever 404s, swap to another vendor JRE.
JRE_TGZ_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jre_x64_linux_hotspot_17.0.12_7.tar.gz"

python3 - <<'PY'
import urllib.request, tarfile, os, sys
url = os.environ.get("JRE_TGZ_URL")
dst = "/tmp/jre.tgz"
print(f"Downloading JRE from {url} ...")
urllib.request.urlretrieve(url, dst)
print("Extracting JRE ...")
with tarfile.open(dst, "r:gz") as t:
    t.extractall("/tmp")
print("done")
PY

# Pick the extracted directory (pattern: jdk-17*/ or jre-17*/)
JRE_HOME=$(find /tmp -maxdepth 1 -type d -name "jdk-17*" -o -name "jre-17*" | head -n1)
if [[ -z "${JRE_HOME}" ]]; then
  echo "ERROR: JRE extraction not found."
  exit 1
fi
export JAVA_HOME="${JRE_HOME}"
export PATH="${JAVA_HOME}/bin:${PATH}"

echo "[setup] Downloading Liquibase CLI to ${LB_DIR}..."
LB_VER="4.29.2"
LB_TGZ_URL="https://github.com/liquibase/liquibase/releases/download/v${LB_VER}/liquibase-${LB_VER}.tar.gz"

python3 - <<'PY'
import urllib.request, tarfile, os
url = os.environ.get("LB_TGZ_URL")
dst = "/tmp/liquibase.tgz"
print(f"Downloading Liquibase from {url} ...")
urllib.request.urlretrieve(url, dst)
print("Extracting Liquibase ...")
import tarfile
with tarfile.open(dst, "r:gz") as t:
    t.extractall("/tmp/liquibase-extract")
print("done")
PY

# Symlink liquibase runner
if [[ -x /tmp/liquibase-extract/liquibase/liquibase ]]; then
  ln -sf /tmp/liquibase-extract/liquibase/liquibase "${LB_DIR}/liquibase"
else
  echo "ERROR: liquibase binary not found after extract."
  exit 1
fi
chmod +x "${LB_DIR}/liquibase"

echo "[setup] Downloading AlloyDB Auth Proxy to ${PROXY_BIN}..."
PROXY_VER="1.13.6"
PROXY_URL="https://storage.googleapis.com/alloydb-auth-proxy/v${PROXY_VER}/alloydb-auth-proxy.linux.amd64"

python3 - <<'PY'
import urllib.request, os
url = os.environ.get("PROXY_URL")
dst = os.environ.get("PROXY_BIN")
print(f"Downloading AlloyDB Auth Proxy from {url} ...")
urllib.request.urlretrieve(url, dst)
print("done")
PY
chmod +x "${PROXY_BIN}"

echo "[proxy] Starting AlloyDB Auth Proxy on :${PROXY_PORT} ..."
nohup "${PROXY_BIN}" --port "${PROXY_PORT}" "${INSTANCE_URI}" >/tmp/proxy.log 2>&1 &
sleep 3

echo "[liquibase] Running update..."
"${LB_DIR}/liquibase" \
  --defaultsFile="${LB_PROPERTIES}" \
  --url="jdbc:postgresql://127.0.0.1:${PROXY_PORT}/${DB_NAME}" \
  --username="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  --changeLogFile="${LB_CHANGELOG_FILE}" \
  update

echo "[done] Liquibase update finished."

