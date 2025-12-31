ARG BASE_VERSION=15
FROM ghcr.io/daemonless/base:${BASE_VERSION} AS builder

# Install Node.js and build dependencies for native modules
# (FreeBSD-base repo is already configured in base image for dev headers)
RUN pkg update && \
    pkg install -y \
    FreeBSD-clibs-dev \
    coreutils \
    node24 \
    npm-node24 \
    python311 \
    gcc \
    gmake \
    git \
    sqlite3 \
    postgresql17-client \
    ca_root_nss && \
    ln -sf /usr/local/bin/python3.11 /usr/local/bin/python && \
    ln -sf /usr/local/bin/python3.11 /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/gcc /usr/local/bin/cc && \
    ln -sf /usr/local/bin/g++ /usr/local/bin/c++ && \
    for cmd in printf touch cat mkdir rm cp mv ln basename dirname head tail wc tr cut sort uniq tee; do \
    ln -sf /usr/local/bin/g$cmd /usr/local/bin/$cmd 2>/dev/null || true; \
    done

# Install n8n globally and capture version
ENV npm_config_python=/usr/local/bin/python3.11
RUN npm install -g n8n && \
    mkdir -p /app && npm list -g n8n --depth=0 | grep n8n | sed 's/.*@//' > /app/version

# Production image
FROM ghcr.io/daemonless/base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG PACKAGES="node24 sqlite3 postgresql17-client git ca_root_nss"
ARG UPSTREAM_URL="https://registry.npmjs.org/n8n/latest"
ARG UPSTREAM_SED="s/.*\"version\":\"\\([^\"]*\\)\".*/\\1/p"

LABEL org.opencontainers.image.title="n8n" \
    org.opencontainers.image.description="n8n workflow automation on FreeBSD" \
    org.opencontainers.image.source="https://github.com/daemonless/n8n" \
    org.opencontainers.image.url="https://n8n.io/" \
    org.opencontainers.image.documentation="https://docs.n8n.io/" \
    org.opencontainers.image.licenses="Sustainable-Use-1.0" \
    org.opencontainers.image.vendor="daemonless" \
    org.opencontainers.image.authors="daemonless" \
    io.daemonless.port="5678" \
    io.daemonless.arch="${FREEBSD_ARCH}" \
    io.daemonless.wip="true" \
    io.daemonless.category="Utilities" \
    io.daemonless.upstream-url="${UPSTREAM_URL}" \
    io.daemonless.upstream-sed="${UPSTREAM_SED}" \
    io.daemonless.packages="${PACKAGES}"

# Install runtime dependencies
RUN pkg update && \
    pkg install -y \
    ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Copy C++ runtime library from builder (needed for native modules)
COPY --from=builder /usr/local/lib/gcc13/libstdc++.so.6 /usr/local/lib/
COPY --from=builder /usr/local/lib/gcc13/libgcc_s.so.1 /usr/local/lib/

# Copy n8n from builder and fix permissions for non-root execution
COPY --from=builder /app/version /app/version
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN chmod -R o+rX /usr/local/lib/node_modules/n8n && \
    ln -sf /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    ldconfig -m /usr/local/lib && \
    # Fix SQLite migration bug: double quotes in SQL should be single quotes for string literals
    # FreeBSD SQLite treats double-quoted strings as column identifiers (ANSI SQL mode)
    # Use sed to patch the compiled JavaScript migration files
    for f in /usr/local/lib/node_modules/n8n/node_modules/@n8n/db/dist/migrations/sqlite/*.js; do \
    # Fix table name references in WHERE clauses (handles ${tablePrefix} interpolation)
    sed -i '' 's/WHERE NAME = "\\${tablePrefix}/WHERE NAME = '"'"'${tablePrefix}/g' "$f"; \
    sed -i '' 's/execution_entity";/execution_entity'"'"';/g' "$f"; \
    # Fix VALUES with role names
    sed -i '' 's/VALUES ("owner"/VALUES ('"'"'owner'"'"'/g' "$f"; \
    sed -i '' 's/VALUES ("member"/VALUES ('"'"'member'"'"'/g' "$f"; \
    sed -i '' 's/VALUES ("user"/VALUES ('"'"'user'"'"'/g' "$f"; \
    sed -i '' 's/VALUES ("editor"/VALUES ('"'"'editor'"'"'/g' "$f"; \
    # Fix scope values in INSERT/comparisons
    sed -i '' 's/, "global"/, '"'"'global'"'"'/g' "$f"; \
    sed -i '' 's/, "workflow"/, '"'"'workflow'"'"'/g' "$f"; \
    sed -i '' 's/, "credential"/, '"'"'credential'"'"'/g' "$f"; \
    sed -i '' 's/, "project"/, '"'"'project'"'"'/g' "$f"; \
    sed -i '' 's/= "workflow"/= '"'"'workflow'"'"'/g' "$f"; \
    sed -i '' 's/= "global"/= '"'"'global'"'"'/g' "$f"; \
    sed -i '' 's/= "credential"/= '"'"'credential'"'"'/g' "$f"; \
    sed -i '' 's/= "project"/= '"'"'project'"'"'/g' "$f"; \
    done

# Create config directory (bsd user created by base image)
RUN mkdir -p /config && \
    chown -R bsd:bsd /config

# Copy service definitions and init scripts
COPY root/ /

# Make scripts executable
RUN chmod +x /etc/services.d/*/run /etc/cont-init.d/* 2>/dev/null || true

# Set up s6 service links

# Environment
ENV N8N_USER_FOLDER=/config \
    N8N_PORT=5678 \
    N8N_PROTOCOL=http \
    NODE_ENV=production

EXPOSE 5678
VOLUME /config


