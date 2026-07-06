#!/bin/bash
set -e

# Project initialization script
# Ensures required directories and basic configurations exist.

echo "--- Initializing Postfix Relay Environment ---"

# Create persistence directory (mounted as the container's /var/log/postfix,
# holding mail.log and its rotated mail.log.N siblings)
mkdir -p ./data
echo "Ensuring ./data directory exists."

# Create default TLS certificate mount point (populated by your ACME client, e.g. Caddy)
mkdir -p ./certs
echo "Ensuring ./certs directory exists."

# Setup initial configuration files from examples if missing
echo "Setting up configuration files..."

configs_to_copy=(
    "config/master.cf:config/templates/master.cf"
    "config/smtpd.conf:config/smtpd.conf"
    "config/users.txt:config/users.txt.example"
    "config/sasl_passwd:config/sasl_passwd.example"
)

for config_pair in "${configs_to_copy[@]}"; do
    config_file="${config_pair%%:*}"
    example_file="${config_pair#*:}"
    if [ ! -f "$config_file" ] && [ -f "$example_file" ]; then
        echo "Copying $example_file to $config_file..."
        cp "$example_file" "$config_file"
    fi
done

echo "--- Initialization Complete ---"
echo "Next steps:"
echo "1. Run './generate-configs.sh yourdomain.com' to customize configuration."
echo "2. Point CERTS_DIR (see .env.example) at a directory with your TLS certificate + key,"
echo "   obtained via your own ACME client (e.g. Caddy). See README 'TLS Certificates'."
echo "3. Run 'docker compose up -d' to start the service."
