# Java already included (no apt java install needed)
FROM eclipse-temurin:17-jre-jammy

ARG LIQUIBASE_VERSION=4.29.2
ARG AUTH_PROXY_VERSION=1.13.6

# Install minimal tools we need
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar procps tzdata \
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

# Defaults used by entrypoint (can be overridden via env on the Job)
ENV LB_CHANGELOG_FILE=/workspace/liquibase/changelog.xml
ENV LB_PROPERTIES=/workspace/liquibase/liquibase.properties

# Run as non-root
RUN useradd -m runner
USER runner

ENTRYPOINT ["/entrypoint.sh"]

