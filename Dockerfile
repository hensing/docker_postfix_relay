# Dockerfile
FROM debian:trixie-slim

LABEL maintainer="Dr. Henning Dickten <hdickten@uni-bonn.de>"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Berlin

# Installs postfix and other dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    postfix \
    postfix-pcre \
    libsasl2-modules \
    sasl2-bin \
    mailutils \
    ca-certificates \
    --no-install-recommends && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections && \
    echo "postfix postfix/mailname string localhost" | debconf-set-selections && \
    apt-get install -y --no-install-recommends postfix && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# The postfix package creates the user and group. We just add the user to the sasl group.
RUN adduser postfix sasl

# The configuration files are mounted via docker-compose, so we don't copy them into the image.

# copies entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EXPOSE 587
EXPOSE 25
