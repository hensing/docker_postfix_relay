# Use a specific version of the official Certbot image as a base
FROM certbot/certbot:v2.10.0

# Install a specific version of the RFC 2136 DNS plugin and avoid caching
RUN pip install --no-cache-dir certbot-dns-rfc2136==2.10.0
