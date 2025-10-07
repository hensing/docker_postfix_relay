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

### 2. Configure the Relay

Create the necessary configuration files by copying the `.example` files in the `config/` directory.

- **`cp .env.example .env`**
  - Edit `.env` to set your domain and relay host details.

- **`cp config/sasl_passwd.example config/sasl_passwd`**
  - Edit `config/sasl_passwd` with the credentials for your external SMTP relay.
  - **Important:** Set the file permissions to `600` to protect your credentials: `chmod 600 config/sasl_passwd`.

- **`cp config/users.txt.example config/users.txt`**
  - Edit `config/users.txt` to add the usernames and passwords for your SMTP clients.

- **`cp config/rfc2136.ini.example config/rfc2136.ini`**
  - Edit `config/rfc2136.ini` with the details of your DNS server and TSIG key.
  - **Important:** Set the file permissions to `600`: `chmod 600 config/rfc2136.ini`.

- **`(Optional) cp config/sender_access_map_regexp.example config/sender_login_map.pcre`**
  - This file allows you to restrict which authenticated users can send from which email addresses.
  - Edit `config/sender_login_map.pcre` to define your policies. If this file is not created, a default permissive setting is used.

### 3. Initialize the Environment

Run the initialization script. This will create the `data` directory and empty log files, which is crucial to prevent Docker from creating directories instead of files on the first run.

```bash
chmod +x init.sh
./init.sh
```

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
docker compose up -d postfix
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
