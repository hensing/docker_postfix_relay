#!/bin/bash
set -e

# Project initialization script
# Ensures required directories and basic configurations exist.

echo "--- Initializing Postfix Relay Environment ---"

# Create persistence directory
mkdir -p ./data
echo "Ensuring ./data directory exists."

# Initialize log files to prevent Docker from creating them as directories
touch ./data/mail.log
echo "Ensuring ./data/mail.log exists."

touch ./data/letsencrypt.log
echo "Ensuring ./data/letsencrypt.log exists."

# Setup initial configuration files from examples if missing
echo "Setting up configuration files..."

configs_to_copy=(
    "config/master.cf:config/templates/master.cf"
    "config/smtpd.conf:config/smtpd.conf"
    "config/users.txt:config/users.txt.example"
    "config/sasl_passwd:config/sasl_passwd.example"
    "config/rfc2136.ini:config/rfc2136.ini.example"
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
echo "2. Run './get-cert.sh' to obtain SSL certificates."
echo "3. Run 'docker-compose up -d' to start the services."
