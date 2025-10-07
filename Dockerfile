# Dockerfile
FROM debian:bookworm-slim

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
