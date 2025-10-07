#!/bin/bash
set -e

# Script to generate Postfix configuration files from templates
# Usage: ./generate-configs.sh [MYDOMAIN] [MYHOSTNAME] [CERT_FILE] [KEY_FILE] [RELAYHOST] [MYNETWORKS] [SMTP_TLS_LOGLEVEL] [SMTPD_TLS_LOGLEVEL]

# Default values
MYDOMAIN="${1:-example.com}"
MYHOSTNAME="${2:-smtp.${MYDOMAIN}}"
CERT_FILE="${3:-/etc/letsencrypt/live/${MYHOSTNAME}/fullchain.pem}"
KEY_FILE="${4:-/etc/letsencrypt/live/${MYHOSTNAME}/privkey.pem}"
RELAYHOST="${5:-[smtp-relay.gmail.com]:587}"
MYNETWORKS="${6:-127.0.0.0/8 [::1]/128 172.24.0.0/16 [fd31:444d:df93:2::]/64}"
SMTP_TLS_LOGLEVEL="${7:-1}"
SMTPD_TLS_LOGLEVEL="${8:-1}"

echo "Generating Postfix configuration files..."
echo "Domain: $MYDOMAIN"
echo "Hostname: $MYHOSTNAME"
echo "Cert file: $CERT_FILE"
echo "Key file: $KEY_FILE"
echo "Relay host: $RELAYHOST"
echo "My networks: $MYNETWORKS"
echo "SMTP TLS loglevel: $SMTP_TLS_LOGLEVEL"
echo "SMTPD TLS loglevel: $SMTPD_TLS_LOGLEVEL"

# Replaces placeholders in configuration templates with actual values
generate_from_template() {
    local template="$1"
    local output="$2"
    sed \
        -e "s|{{MYDOMAIN}}|$MYDOMAIN|g" \
        -e "s|{{MYHOSTNAME}}|$MYHOSTNAME|g" \
        -e "s|{{CERT_FILE}}|$CERT_FILE|g" \
        -e "s|{{KEY_FILE}}|$KEY_FILE|g" \
        -e "s|{{RELAYHOST}}|$RELAYHOST|g" \
        -e "s|{{MYNETWORKS}}|$MYNETWORKS|g" \
        -e "s|{{SMTP_TLS_LOGLEVEL}}|$SMTP_TLS_LOGLEVEL|g" \
        -e "s|{{SMTPD_TLS_LOGLEVEL}}|$SMTPD_TLS_LOGLEVEL|g" \
        "$template" > "$output"
}

# Generate main.cf
if [ -f config/templates/main.cf ]; then
    echo "Generating config/main.cf from template..."
    generate_from_template config/templates/main.cf config/main.cf
else
    echo "Error: config/templates/main.cf not found!"
    exit 1
fi

# Generate sender_login_map.pcre
if [ -f config/templates/sender_login_map.pcre ]; then
    echo "Generating config/sender_login_map.pcre from template..."
    generate_from_template config/templates/sender_login_map.pcre config/sender_login_map.pcre
else
    echo "Error: config/templates/sender_login_map.pcre not found!"
    exit 1
fi

# Copy other configs from examples if they don't exist
configs_to_copy=(
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

echo "Configuration generation complete!"
echo "Please edit the generated config files with your actual values:"
echo "- config/main.cf"
echo "- config/sender_login_map.pcre"
echo "- config/users.txt"
echo "- config/sasl_passwd"
echo "- config/rfc2136.ini"