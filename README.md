# Dockerized Postfix Relay with Let's Encrypt

[![Lint and Build](https://github.com/hensing/docker_postfix_relay/actions/workflows/build.yml/badge.svg)](https://github.com/hensing/docker_postfix_relay/actions/workflows/build.yml)
[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-sa/4.0/)

This project provides a complete, production-ready setup for a Dockerized Postfix mail relay. It is designed to send emails through an external SMTP relay (like Gmail) and includes a robust mechanism for obtaining and renewing TLS certificates from Let's Encrypt using the DNS-01 challenge with RFC 2136 dynamic updates.

**Author:** [Dr. Henning Dickten](https://github.com/hensing)

## Features

- **Postfix SMTP Relay:** Forwards all mail to a configured external SMTP provider.
- **SASL Authentication:** Allows clients to securely authenticate before sending emails.
- **Let's Encrypt Integration:** Automatic certificate acquisition and renewal using Certbot.
- **DNS-01 Challenge (RFC 2136):** Obtains certificates without needing to expose port 80/443. This setup uses the RFC 2136 mechanism, but Certbot supports many other DNS providers. For a list of available plugins, see the [official Certbot documentation](https://certbot.eff.org/docs/using.html#dns-plugins).

## Prerequisites

- Docker and `docker-compose` installed on your host machine.
- A domain name.
- An external SMTP relay service (e.g., a Google account with an App Password).
- A DNS server that supports dynamic updates via RFC 2136 and a configured TSIG key.

## Environment Variables

The container is configured using the following environment variables:

| Variable             | Description                                                                 | Default Value                     |
| -------------------- | --------------------------------------------------------------------------- | --------------------------------- |
| `DOMAIN`             | Your primary domain name.                                                   | (none)                            |
| `MYHOSTNAME`         | The FQDN of your mail server.                                               | (none)                            |
| `RELAY_HOST`         | The address and port of the external SMTP relay.                            | `[smtp-relay.gmail.com]:587`      |
| `MYNETWORKS`         | The list of trusted networks.                                               | `127.0.0.0/8 [::1]/128`           |
| `SMTP_TLS_LOGLEVEL`  | The TLS log level for outgoing mail.                                        | `1`                               |
| `SMTPD_TLS_LOGLEVEL` | The TLS log level for incoming mail.                                        | `1`                               |

### TLS Log Levels
- **0:** Disable TLS logging.
- **1:** Summary (recommended for production). Includes TLS handshake summary, protocol, and cipher information.
- **2:** Add certificate details. Includes information from level 1 plus peer certificate details.
- **3+:** Verbose debug. Includes all information from previous levels plus low-level TLS details.

## Setup Instructions

### 1. Clone the Repository

Clone this repository to your server.

### 2. Initialize the Environment

Run the initialization script. This will create the `data` directory, empty log files, and copy example configuration files if they don't exist.

```bash
chmod +x init.sh
./init.sh
```

### 3. Generate Configuration Files

Generate the main configuration files from templates. You can use the provided script or Makefile:

**Using the script:**
```bash
chmod +x generate-configs.sh
./generate-configs.sh yourdomain.com smtp.yourdomain.com
```

**Using Make:**
```bash
make configs MYDOMAIN=yourdomain.com MYHOSTNAME=smtp.yourdomain.com
```

This will generate:
- `config/main.cf` with your domain and hostname
- `config/sender_login_map.pcre` with domain-specific policies

### 4. Configure Secrets and Credentials

Edit the generated or copied configuration files with your actual values:

- **`.env`**: Set your domain and relay host details (copied from `.env.example`).

- **`config/sasl_passwd`**: Credentials for your external SMTP relay.
  - **Important:** Set permissions to `600`: `chmod 600 config/sasl_passwd`.

- **`config/users.txt`**: Usernames and passwords for SMTP clients.

- **`config/rfc2136.ini`**: DNS server details and TSIG key for Let's Encrypt.
  - **Important:** Set permissions to `600`: `chmod 600 config/rfc2136.ini`.

- **`config/main.cf`**: Review and adjust any additional settings.

- **`config/sender_login_map.pcre`**: Customize sender login mappings if needed.

### 4. Obtain the Initial Certificate

Before starting the Postfix service, you need to obtain the TLS certificate from Let's Encrypt.

- **Edit `compose.yml`:** Open `compose.yml` and replace `DEINE_EMAIL_HIER@example.com` with your actual email address for Let's Encrypt notifications.
- **Run the script:**
  ```bash
  chmod +x get-cert.sh
  ./get-cert.sh
  ```
This will build the custom Certbot image and run it to get your certificate.

### 5. Start the Postfix Service

Once you have the certificate, you can start the Postfix relay service.

```bash
docker compose up -d postfix-relay
```

Your SMTP relay is now running and available on port 587.

## Usage

Configure your email clients to use the following settings:
- **SMTP Host:** `smtp.yourdomain.com` (or whatever you configured)
- **Port:** `587`
- **Encryption:** `STARTTLS`
- **Authentication:** Use the username and password you defined in `config/users.txt`.

## Implementation Notes

### Non-Root Execution

An attempt was made to run the container with a non-root user. However, the Postfix master process must be started as root to have sufficient permissions to open privileged ports and manage its child processes. The child processes then drop privileges and run as the `postfix` user. This is the standard and expected behavior for Postfix.

## Contributing

Contributions are welcome! If you have ideas for improvements or find a bug, please feel free to open an issue or submit a pull request.

## Automatic Certificate Renewal

A script is provided to handle automatic certificate renewal. You should run this script from a cron job on your host machine.

1.  **Edit the script:** Open `renew_certs.sh` and set the `PROJECT_DIR` variable to the absolute path of this project directory.
2.  **Make it executable:** `chmod +x renew_certs.sh`
3.  **Create a cron job:** Add a line to your crontab to run the script daily.
    ```cron
    # Run certificate renewal check every day at 3:30 AM
    30 3 * * * /path/to/your/project/renew_certs.sh >> /var/log/cert_renewal.log 2>&1
    ```

This will ensure your certificate is always up-to-date and that Postfix is reloaded automatically after a successful renewal.

## Configuration Templates and Generation

This project uses templates to generate configuration files, making it easy to set up the mail relay for different domains and environments.

### Template Files
- `config/templates/main.cf`: Template for the main Postfix configuration with placeholders like `{{MYDOMAIN}}`, `{{MYHOSTNAME}}`, etc.
- `config/templates/sender_login_map.pcre`: Template for sender login mappings with domain placeholders.

### Example Files
- Other `.example` files for secrets and credentials (e.g., `config/sasl_passwd.example`, `config/users.txt.example`)

### Generating Configurations
Use the provided tools to generate configurations:

```bash
# Using the script directly
./generate-configs.sh yourdomain.com smtp.yourdomain.com /etc/letsencrypt/live/smtp.yourdomain.com/fullchain.pem /etc/letsencrypt/live/smtp.yourdomain.com/privkey.pem

# Using Make with variables
make configs MYDOMAIN=yourdomain.com MYHOSTNAME=smtp.yourdomain.com CERT_FILE=/path/to/cert KEY_FILE=/path/to/key

# Using Make with defaults (will use example.com)
make configs
```

### Customization
After generation, edit the configuration files to match your specific requirements. The generated files are ignored by Git, so your customizations are preserved.
