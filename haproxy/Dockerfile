FROM ubuntu

FROM ${DOCKER_PREFIX}ubuntu:bionic

ARG URL_P2CLI=https://github.com/wrouesnel/p2cli/releases/download/r5/p2
ARG URL_REVERSE_EXPORTER=https://github.com/wrouesnel/reverse_exporter/releases/download/v0.0.1/reverse_exporter_v0.0.1_linux-amd64.tar.gz
ARG URL_WEBHOOK=https://github.com/adnanh/webhook/releases/download/2.6.9/webhook-linux-amd64.tar.gz
ARG URL_MAKECERTS=https://github.com/wrouesnel/makecerts/releases/download/v0.4/makecerts.x86_64
ARG URL_HAPROXY_EXPORTER=https://github.com/prometheus/haproxy_exporter/releases/download/v0.10.0/haproxy_exporter-0.10.0.linux-amd64.tar.gz
ARG URL_NODEEXPORTER=https://github.com/prometheus/node_exporter/releases/download/v0.17.0/node_exporter-0.17.0.linux-amd64.tar.gz
ARG URL_GETPIP=https://bootstrap.pypa.io/get-pip.py

ARG http_proxy=
ARG https_proxy=

# Static env-vars  - should not be overridden
ENV DATA_DIR=/data \
    SVDIR=/run/services

COPY tree-preinstall/ /

RUN apt-get update && apt-get install --no-install-recommends -y gnupg2 ca-certificates

RUN find -path '/tmp/*.asc' -exec /bin/bash -c 'apt-key add {} && rm -f {}' \;

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        runit \
        syslog-ng-core syslog-ng-mod-json \
        openssl \
        pwgen \
        wget curl dnsutils apache2-utils net-tools iproute2 rsync sudo jq ssl-cert less

RUN DEBIAN_FRONTEND=noninteractive apt update && \
    apt install -y haproxy haproxyctl wget tar && \
    # Templating engine
    wget -O /usr/local/bin/p2 $URL_P2CLI && \
    chmod +x /usr/local/bin/p2 && \
    # SSL certificate helper
    wget -O /usr/local/bin/makecerts $URL_MAKECERTS && \
    chmod +x /usr/local/bin/makecerts && \
    # Prometheus node_exporter
    wget -O - $URL_NODEEXPORTER | tar -xzvf - --strip-components=1 -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/node_exporter && \
    # Prometheus reverse proxy
    wget -O - $URL_REVERSE_EXPORTER | tar -xzvf - --strip-components=1 -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/reverse_exporter && \
    # HAProxy exporter
    wget --progress=dot:giga -O - $URL_HAPROXY_EXPORTER | tar -xzvf - --strip-components=1 -C /usr/local/bin && \
    chmod +x /usr/local/bin/haproxy_exporter && \
    # Webhook engine
    wget --progress=dot:giga -O - $URL_WEBHOOK | tar -xzvf - --strip-components=1 -C /usr/local/bin && \
    chmod +x /usr/local/bin/webhook && \
    # Cleanup    
    apt-get autoremove -y

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        # Need python
        python3 python3-distutils \
        # Need whois for makepassword for haproxy
        whois && \
        wget -O - $URL_GETPIP | python3 && \
        # Install the j2 utility
        pip3 install j2cli[yaml] ruamel.yaml

COPY tree-postinstall/ /

# Install the python components
RUN for r in /usr/local/bin/*.requirements.txt ; do pip3 install -r $r ; done

# Override default TLS behavior in the container.
RUN \
    # Point SSL directory to /run
    mv /etc/ssl /etc/ssl.default && \
    ln -sf /run/ssl /etc/ssl && \
    # Point update-ca-certificates to /run so we can change configuration.
    mv /etc/ca-certificates.conf /etc/ca-certificates.conf.default && \
    ln -sf /run/ca-certificates.conf /etc/ca-certificates.conf && \
    # Point /usr/local/share/ca-certificates to /run
    rm -rf /usr/local/share/ca-certificates && \
    ln -sf /run/ca-certificates /usr/local/share/ca-certificates

ENV \  
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# The entrypoint generates a random password if the DB_USER_PASSWORD is unspecified.
ENV \
    # Number of CPU cores to use for multi-process instances
    CORE_COUNT=1 \
    # Hostname to set inside the container
    HOSTNAME= \
    # Is admin UI authentication turned on?
    ADMIN_AUTH=yes \
    # Admin UI user
    ADMIN_USER=admin \
    # Admin UI password - randomly generated if blank
    ADMIN_PASSWORD= \
    # Web UI SSL parameters. Can be filepaths in the container, literal PEM certificates or blank.
    # Blank causes the container to automatically generate certificates on first run.
    WEBUI_SSL_SERVER_CERT= \
    WEBUI_SSL_SERVER_KEY= \
    # NTP server
    NTP_SERVER=127.0.0.1 \
    # Must be yes to allow certificate generation
    DEV_ALLOW_SELF_SIGNED=no \
    # If yes, allows the container to run with ephemeral /data
    DEV_ALLOW_EPHEMERAL_DATA=no \
    # If yes, allows using global certificates.
    DEV_ALLOW_DEFAULT_TRUST=yes \
    # Enable debugging
    DEV_ENTRYPOINT_DEBUG=no \
    # Path or literal certificates to use as platform trust certificates
    PLATFORM_TLS_TRUST_CERTIFICATES= 

COPY healthcheck.sh /healthcheck.sh
HEALTHCHECK --interval=10s --timeout=10s --retries=3 CMD /healthcheck.sh

ENTRYPOINT [ "/entrypoint.bsh" ]