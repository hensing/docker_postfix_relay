#!/bin/bash
set -e

# --- Configuration Setup ---
# Copy the mounted config templates to the active config directories
cp -r /config.template/* /etc/postfix/

# Create sasl2 directory and copy smtpd.conf if it exists
mkdir -p /etc/sasl2
if [ -f /etc/postfix/smtpd.conf ]; then
    cp /etc/postfix/smtpd.conf /etc/sasl2/smtpd.conf
fi

# Ensure all config files are owned by root, correcting for host mount permissions
chown -R root:root /etc/postfix
if [ -d /etc/sasl2 ]; then
    chown -R root:root /etc/sasl2
fi

# --- Environment Variable Checks ---
if [ -z "$DOMAIN" ] || [ -z "$MYHOSTNAME" ] || [ -z "$RELAY_HOST" ]; then
  echo "Error: DOMAIN, MYHOSTNAME, and RELAY_HOST environment variables must be set."
  exit 1
fi

# --- Dynamic Configuration ---
echo "Configuring Postfix with environment variables..."
/usr/sbin/postconf -e "myhostname = ${MYHOSTNAME}"
/usr/sbin/postconf -e "mydomain = ${DOMAIN}"
/usr/sbin/postconf -e "relayhost = ${RELAY_HOST}"
/usr/sbin/postconf -e "mynetworks = ${MYNETWORKS}"
/usr/sbin/postconf -e "smtp_tls_loglevel = ${SMTP_TLS_LOGLEVEL}"
/usr/sbin/postconf -e "smtpd_tls_loglevel = ${SMTPD_TLS_LOGLEVEL}"
/usr/sbin/postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/${MYHOSTNAME}/fullchain.pem"
/usr/sbin/postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/${MYHOSTNAME}/privkey.pem"

# --- SASL Password Setup ---
if [ -f /etc/postfix/sasl_passwd ]; then
    echo "Updating sasl_passwd.db..."
    postmap /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
fi

# --- SASL User Database Setup ---
echo "Regenerating SASL database from users.txt..."
rm -f /etc/sasldb2
if [ -f /etc/postfix/users.txt ]; then
    while IFS=: read -r username password; do
      if [[ -z "${username}" || "${username}" =~ ^#.* ]]; then continue; fi
      echo "Creating user: ${username}@${DOMAIN}"
      echo "${password}" | saslpasswd2 -c -p -u "${DOMAIN}" "${username}@${DOMAIN}"
    done < /etc/postfix/users.txt
fi
if [ -f /etc/sasldb2 ]; then
    chown postfix:sasl /etc/sasldb2
    chmod 640 /etc/sasldb2
fi

# --- Final Checks and Execution ---
echo "Running postfix check..."
postfix check

# Ensure the log file is writable by the postfix user
chown postfix:postfix /var/log/mail.log

echo "Starting Postfix in foreground..."
# This command starts the master process as root, which in turn starts the worker
# processes as the 'postfix' user. This is the intended and secure way to run Postfix.
exec postfix start-fg
