# Dockerfile
# debian:trixie-slim (Debian 13, current stable as of mid-2026), pinned by digest
# for reproducible builds. Bump via Dependabot (see .github/dependabot.yml) or manually:
#   docker pull debian:trixie-slim && docker inspect --format='{{index .RepoDigests 0}}' debian:trixie-slim
FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

LABEL maintainer="Henning Dickten <hdickten@uni-bonn.de>"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

# Install Postfix and required SASL modules
RUN apt-get update && \
    apt-get install -y \
    postfix \
    postfix-pcre \
    libsasl2-modules \
    sasl2-bin \
    mailutils \
    ca-certificates \
    debconf-utils \
    --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN adduser postfix sasl

# Copy entrypoint script and set permissions
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EXPOSE 587
EXPOSE 25
