FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget unzip ca-certificates gnupg2 lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Download Xray with error checking
RUN mkdir -p /tmp/xray && cd /tmp/xray && \
    wget -q -O Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    if [ ! -f Xray-linux-64.zip ]; then echo "Failed to download Xray"; exit 1; fi && \
    unzip -q Xray-linux-64.zip && \
    chmod +x xray && \
    ls -la

# =====================================
# PRODUCTION IMAGE FOR GOOGLE CLOUD RUN
# =====================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PROXY_ENGINE=openresty \
    TZ=UTC \
    PORT=8080

# Install core dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg2 \
    lsb-release \
    netcat-openbsd \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Add OpenResty repository & install
RUN apt-get update && \
    mkdir -p /usr/share/keyrings /etc/apt/keyrings && \
    curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | \
    tee /etc/apt/sources.list.d/openresty.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openresty && \
    rm -rf /var/lib/apt/lists/*

# Add Envoy repository & install
RUN apt-get update && \
    curl -fsSL https://apt.envoyproxy.io/signing.key | gpg --dearmor -o /etc/apt/keyrings/envoy-keyring.gpg && \
    echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/envoy-keyring.gpg] https://apt.envoyproxy.io $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/envoy.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends envoy && \
    rm -rf /var/lib/apt/lists/*

# Install HAProxy
RUN apt-get update && \
    apt-get install -y --no-install-recommends haproxy && \
    rm -rf /var/lib/apt/lists/*

# Copy Xray from builder
COPY --from=builder /tmp/xray/xray /usr/local/bin/xray
COPY --from=builder /tmp/xray/geosite.dat /usr/local/share/xray/geosite.dat
COPY --from=builder /tmp/xray/geoip.dat /usr/local/share/xray/geoip.dat

RUN chmod +x /usr/local/bin/xray && \
    chmod 644 /usr/local/share/xray/*.dat

# Create directory structure
RUN mkdir -p \
    /etc/xray \
    /etc/envoy \
    /etc/haproxy \
    /usr/local/openresty/nginx/conf \
    /usr/local/openresty/nginx/html \
    /tmp/xray-logs

# Copy configuration files
COPY config.json /etc/xray/config.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY envoy.yaml /etc/envoy/envoy.yaml
COPY haproxy.cfg /etc/haproxy/haproxy.cfg
COPY index.html /usr/local/openresty/nginx/html/index.html
COPY entrypoint.sh /entrypoint.sh

# Fix permissions
RUN chmod +x /entrypoint.sh && \
    chmod 644 /etc/xray/config.json /etc/envoy/envoy.yaml /etc/haproxy/haproxy.cfg

# Health check for Cloud Run
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Runtime optimizations
ENV MALLOC_TRIM_THRESHOLD_=262144 \
    MALLOC_MMAP_MAX_=65536 \
    MALLOC_MMAP_THRESHOLD_=262144

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
