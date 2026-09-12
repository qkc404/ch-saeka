FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server openssh-client nginx python3 cmake build-essential git wget curl ca-certificates \
    openssl unzip jq netcat-openbsd dnsutils iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Build BadVPN UDPGW for Gaming UDP Support
RUN git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn \
    && cd /tmp/badvpn && mkdir build && cd build \
    && cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 \
    && make install && rm -rf /tmp/badvpn

# Install XRAY Core
RUN mkdir -p /etc/xray && \
    wget -q https://github.com/XTLS/Xray-core/releases/download/v1.8.7/Xray-linux-64.zip -O /tmp/xray.zip && \
    unzip -q /tmp/xray.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/xray && \
    rm /tmp/xray.zip

# Setup SSH and Saeka User
RUN mkdir -p /var/run/sshd
RUN useradd -m -s /bin/bash saeka && echo 'saeka:saeka' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
RUN sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
RUN echo "AllowAgentForwarding yes" >> /etc/ssh/sshd_config
RUN echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
RUN echo "GatewayPorts yes" >> /etc/ssh/sshd_config
RUN echo "PermitTunnel yes" >> /etc/ssh/sshd_config

# Add Custom Aesthetic Banner
COPY banner.txt /etc/ssh/banner.txt
RUN echo "Banner /etc/ssh/banner.txt" >> /etc/ssh/sshd_config

COPY nginx.conf /etc/nginx/nginx.conf
COPY xray-config.json /etc/xray/config.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080 22 10086 10087

ENTRYPOINT ["/entrypoint.sh"]
