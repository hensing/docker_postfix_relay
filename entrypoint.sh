#!/bin/bash
set -e

# Graceful shutdown handling
cleanup() {
    echo "Stopping Postfix..."
    if postfix status &> /dev/null; then postfix stop; fi
    exit 0
}
trap cleanup SIGTERM SIGINT

# Ensure proper ownership and permissions of mounted configuration files EARLY
# This prevents warnings from Postfix tools called later in the script
echo "Initializing configuration file ownership and permissions..."
chown -R root:root /etc/postfix/ 2>/dev/null || echo "Warning: Could not change ownership of some files in /etc/postfix/"
chown root:root /etc/sasl2/smtpd.conf 2>/dev/null || echo "Warning: Could not change ownership of /etc/sasl2/smtpd.conf"

# Set restrictive permissions for sensitive files
[ -f /etc/postfix/sasl_passwd ] && chmod 600 /etc/postfix/sasl_passwd
[ -f /etc/postfix/users.txt ] && chmod 600 /etc/postfix/users.txt
[ -f /etc/postfix/rfc2136.ini ] && chmod 600 /etc/postfix/rfc2136.ini

# Configure Postfix with runtime environment variables
echo "Configuring Postfix for domain: ${DOMAIN}..."
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string ${DOMAIN}" | debconf-set-selections

# Apply runtime configuration
dpkg-reconfigure -f noninteractive postfix

# Generate SASL password map if the file exists
if [ -f /etc/postfix/sasl_passwd ]; then
    echo "Generating SASL password database..."
    postmap /etc/postfix/sasl_passwd
fi

# Rebuild SASL user database
echo "Initializing SASL user database..."
rm -f /etc/sasldb2
touch /etc/sasldb2
chown root:postfix /etc/sasldb2
chmod 640 /etc/sasldb2

# Process users from users.txt
if [ -f /etc/postfix/users.txt ]; then
    while IFS=: read -r username password; do
      # Trim whitespace and skip comments/empty lines
      username=$(echo "$username" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [[ -z "$username" || "$username" =~ ^# ]]; then continue; fi
      
      echo "Creating SASL user: ${username}@${DOMAIN}"
      echo "${password}" | saslpasswd2 -c -p -u "${DOMAIN}" "${username}@${DOMAIN}"
    done < /etc/postfix/users.txt
fi

echo "Registered SASL users:"
sasldblistusers2 -f /etc/sasldb2

# Final health check and log initialization
echo "Running Postfix configuration check..."
postfix check
touch /var/log/mail.log
chown postfix:postfix /var/log/mail.log

echo "Starting Postfix system services..."
service postfix start

echo "Container started. Monitoring mail logs. Press Ctrl+C to stop."
tail -f /var/log/mail.log & wait $!
