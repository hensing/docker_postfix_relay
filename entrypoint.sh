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
mkdir -p /var/log/postfix
chown postfix:postfix /var/log/postfix
touch /var/log/postfix/mail.log
chown postfix:postfix /var/log/postfix/mail.log

echo "Starting Postfix system services..."
service postfix start

echo "Container started. Monitoring mail logs. Press Ctrl+C to stop."
MAIL_LOG=/var/log/postfix/mail.log
MAIL_LOG_MAX_BYTES="${MAIL_LOG_MAX_BYTES:-10485760}" # 10 MiB
MAIL_LOG_KEEP="${MAIL_LOG_KEEP:-5}"

rotate_mail_log() {
    local n
    for (( n = MAIL_LOG_KEEP - 1; n >= 1; n-- )); do
        [ -f "${MAIL_LOG}.$n" ] && mv -f "${MAIL_LOG}.$n" "${MAIL_LOG}.$((n + 1))"
    done
    # copytruncate: postlogd keeps its file descriptor open across this, so
    # there's no need to signal/reload postfix to pick up the new (empty) file.
    cp "$MAIL_LOG" "${MAIL_LOG}.1"
    : > "$MAIL_LOG"
}

# Not using `tail -f` here: it relies on inotify, which some bind-mount
# storage backends don't reliably deliver for writes made by another
# process in the container - the file keeps growing but nothing reaches
# `docker logs`. Poll for new bytes instead, which works everywhere, and
# rotate the file ourselves once it grows past MAIL_LOG_MAX_BYTES since
# nothing else in this container does.
(
    offset=0
    while true; do
        if [ -f "$MAIL_LOG" ]; then
            size=$(wc -c < "$MAIL_LOG" 2>/dev/null || echo 0)
            if [ "$size" -lt "$offset" ]; then
                offset=0
            fi
            if [ "$size" -gt "$offset" ]; then
                # Bound the read to exactly [offset, size) so bytes written
                # concurrently, after this size snapshot, aren't consumed
                # here too and printed again next iteration.
                tail -c +"$((offset + 1))" "$MAIL_LOG" | head -c "$((size - offset))"
                offset=$size
            fi
            if [ "$size" -ge "$MAIL_LOG_MAX_BYTES" ]; then
                rotate_mail_log
                offset=0
            fi
        fi
        sleep 1
    done
) & wait $!
