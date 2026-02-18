ARG BUILD_FROM=ghcr.io/hassio-addons/base:20.0.1
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Copy root filesystem
COPY rootfs /

# Ensure all scripts are executable
RUN chmod +x \
    /etc/s6-overlay/s6-rc.d/init-hcloud/run \
    /etc/s6-overlay/s6-rc.d/hcloud-ddns/run \
    /etc/s6-overlay/s6-rc.d/hcloud-ddns/finish \
    /etc/s6-overlay/s6-rc.d/hcloud-ddns-api/run \
    /usr/bin/hcloud-ddns.sh \
    /usr/bin/hcloud-ddns-api.py

# Setup base
# Install required packages for DNS operations and API calls
RUN apk add --no-cache \
    bind-tools \
    coreutils \
    curl \
    jq \
    python3

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="prindom" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="prindom" \
    org.opencontainers.image.authors="prindom" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
