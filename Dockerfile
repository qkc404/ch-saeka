FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, OpenResty, HAProxy, Envoy & Xray
RUN apt-get update && apt-get install -y \
    curl wget unzip ca-certificates gnupg lsb-release haproxy \
    && curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list \
    && curl -ptL https://apt.envoyproxy.io/signing.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/envoy.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/etc/apt/trusted.gpg.d/envoy.gpg] https://apt.envoyproxy.io $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/envoy.list \
    && apt-get update && apt-get install -y openresty envoy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Xray-core
RUN wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip Xray-linux-64.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -f Xray-linux-64.zip

# Create config directories
RUN mkdir -p /etc/xray /etc/envoy /etc/haproxy /usr/local/openresty/nginx/conf

# Copy configurations
COPY config.json /etc/xray/config.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY envoy.yaml /etc/envoy/envoy.yaml
COPY haproxy.cfg /etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh
COPY index.html /var/www/html/index.html

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
