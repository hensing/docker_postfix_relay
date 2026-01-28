# Use a specific version of the official Certbot image as a base
FROM certbot/certbot:v5.2.2

# Install a specific version of the RFC 2136 DNS plugin and avoid caching
RUN pip install --no-cache-dir certbot-dns-rfc2136==5.2.2
