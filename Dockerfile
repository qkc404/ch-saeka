FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl wget unzip ca-certificates gnupg lsb-release haproxy git netcat-openbsd \
    && mkdir -p /etc/apt/keyrings /usr/share/keyrings \
    && curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list \
    && curl -fsSL https://apt.envoyproxy.io/signing.key | gpg --dearmor -o /etc/apt/keyrings/envoy-keyring.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/envoy-keyring.gpg] https://apt.envoyproxy.io $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/envoy.list \
    && apt-get update && apt-get install -y openresty envoy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Extract Xray and route assets correctly
RUN wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip -q Xray-linux-64.zip -d /tmp/xray/ \
    && mv /tmp/xray/xray /usr/local/bin/xray \
    && mkdir -p /usr/local/share/xray/ \
    && mv /tmp/xray/geosite.dat /usr/local/share/xray/ \
    && mv /tmp/xray/geoip.dat /usr/local/share/xray/ \
    && chmod +x /usr/local/bin/xray \
    && rm -rf /tmp/xray/ Xray-linux-64.zip

RUN mkdir -p /etc/xray /etc/envoy /etc/haproxy /usr/local/openresty/nginx/conf /usr/local/openresty/nginx/html

COPY config.json /etc/xray/config.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY envoy.yaml /etc/envoy/envoy.yaml
COPY haproxy.cfg /etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh
COPY index.html /usr/local/openresty/nginx/html/index.html

RUN /usr/local/bin/xray run -test -config /etc/xray/config.json \
    || (echo "FATAL: /etc/xray/config.json failed validation" && exit 1)

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
