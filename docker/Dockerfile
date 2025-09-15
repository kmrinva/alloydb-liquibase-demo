# Minimal, predictable image with everything we need
FROM debian:stable-slim

ARG LIQUIBASE_VERSION=4.29.2
ARG AUTH_PROXY_VERSION=1.13.6

# Install required tools once at build time (not runtime)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar procps tzdata openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Liquibase CLI
RUN mkdir -p /opt/liquibase \
 && curl -fsSL "https://github.com/liquibase/liquibase/releases/download/v${LIQUIBASE_VERSION}/liquibase-${LIQUIBASE_VERSION}.tar.gz" \
    | tar -xz -C /opt/liquibase \
 && ln -s /opt/liquibase/liquibase /usr/local/bin/liquibase

# AlloyDB Auth Proxy
RUN curl -fsSL "https://storage.googleapis.com/alloydb-auth-proxy/v${AUTH_PROXY_VERSION}/alloydb-auth-proxy.linux.amd64" \
    -o /usr/local/bin/alloydb-auth-proxy \
 && chmod +x /usr/local/bin/alloydb-auth-proxy

# App files
WORKDIR /workspace
COPY liquibase/ ./liquibase/
COPY bin/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Defaults used by entrypoint (you can override via env on the Job)
ENV LB_CHANGELOG_FILE=/workspace/liquibase/changelog.xml
ENV LB_PROPERTIES=/workspace/liquibase/liquibase.properties

# Non-root (Cloud Run requirement is fine with root too, but non-root is safer)
RUN useradd -m runner
USER runner

ENTRYPOINT ["/entrypoint.sh"]
