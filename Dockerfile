FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl wget unzip ca-certificates gnupg lsb-release haproxy git \
    && mkdir -p /etc/apt/keyrings /usr/share/keyrings \
    && curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list \
    && curl -fsSL https://apt.envoyproxy.io/signing.key | gpg --dearmor -o /etc/apt/keyrings/envoy-keyring.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/envoy-keyring.gpg] https://apt.envoyproxy.io $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/envoy.list \
    && apt-get update && apt-get install -y openresty envoy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip Xray-linux-64.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -f Xray-linux-64.zip

RUN mkdir -p /etc/xray /etc/envoy /etc/haproxy /usr/local/openresty/nginx/conf /usr/local/openresty/nginx/html

COPY config.json /etc/xray/config.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY envoy.yaml /etc/envoy/envoy.yaml
COPY haproxy.cfg /etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh
COPY index.html /usr/local/openresty/nginx/html/index.html

# Fail the build (instead of silently shipping a broken image) if config.json
# is invalid. This is what let the container "deploy successfully" in the
# past while Xray failed to start and every inbound returned EOF/refused.
RUN /usr/local/bin/xray run -test -config /etc/xray/config.json \
    || (echo "FATAL: /etc/xray/config.json failed validation" && exit 1)

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
