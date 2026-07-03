# Dockerized Postfix Relay

[![Lint and Build](https://github.com/hensing/docker_postfix_relay/actions/workflows/build.yml/badge.svg)](https://github.com/hensing/docker_postfix_relay/actions/workflows/build.yml)
[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-sa/4.0/)

This project provides a hardened, production-ready setup for a Dockerized Postfix mail relay. It is designed to send emails through an external SMTP relay (like Gmail) and accepts authenticated SMTP submission from your own clients/applications.

**Author:** [Dr. Henning Dickten](https://github.com/hensing)

## Features

- **Postfix SMTP Relay:** Forwards all mail to a configured external SMTP provider.
- **SASL Authentication:** Allows clients to securely authenticate before sending emails.
- **Submission-only:** Only the authenticated submission port (587) is enabled; the unauthenticated port 25 listener is disabled by default.
- **Bring-your-own TLS certificate:** No ACME client is bundled or prescribed — point the container at a certificate/key provided by whatever tool you already use (Caddy, Certbot, ...).
- **Hardened by default:** minimal Linux capabilities (`cap_drop: ALL` + a small explicit `cap_add`), `no-new-privileges`, digest-pinned base image, weekly CI vulnerability scan and dependency updates.

## Prerequisites

- Docker and `docker compose` installed on your host machine.
- A domain name.
- An external SMTP relay service (e.g., a Google account with an App Password).
- A TLS certificate + private key for your mail hostname, obtained via any ACME client of your choice (see [TLS Certificates](#tls-certificates) below).

## Environment Variables

The container is configured using the following environment variables (set via `.env`, copied from `.env.example` — see `env_file: .env` in `compose.yml`):

| Variable             | Description                                                                 | Default Value                     |
| -------------------- | --------------------------------------------------------------------------- | --------------------------------- |
| `DOMAIN`             | Your primary domain name.                                                   | (none)                            |
| `MYHOSTNAME`         | The FQDN of your mail server (documentation only, see note below).          | (none)                            |
| `RELAY_HOST`         | The address and port of the external SMTP relay.                            | `[smtp-relay.gmail.com]:587`      |
| `MYNETWORKS`         | The list of trusted networks.                                               | `127.0.0.0/8 [::1]/128`           |
| `CERTS_DIR`          | Host directory with your TLS certificate + key, mounted read-only.          | `./certs`                         |
| `SMTP_TLS_LOGLEVEL`  | The TLS log level for outgoing mail.                                        | `1`                               |
| `SMTPD_TLS_LOGLEVEL` | The TLS log level for incoming mail.                                        | `1`                               |

> `MYHOSTNAME` is not read by the container at runtime — `myhostname` in `main.cf` is fixed at `generate-configs.sh` time. It's kept in `.env` for documentation/consistency only.

### TLS Log Levels
- **0:** Disable TLS logging.
- **1:** Summary (recommended for production). Includes TLS handshake summary, protocol, and cipher information.
- **2:** Add certificate details. Includes information from level 1 plus peer certificate details.
- **3+:** Verbose debug. Includes all information from previous levels plus low-level TLS details.

## Setup Instructions

### 1. Clone the Repository

Clone this repository to your server.

### 2. Initialize the Environment

Run the initialization script. This will create the `data` and `certs` directories, an empty log file, and copy example configuration files if they don't exist.

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

- **`.env`**: Set your domain, relay host, and `CERTS_DIR` (copied from `.env.example`).

- **`config/sasl_passwd`**: Credentials for your external SMTP relay.
  - **Important:** Set permissions to `600`: `chmod 600 config/sasl_passwd`.

- **`config/users.txt`**: Usernames and passwords for SMTP clients.

- **`config/main.cf`**: Review and adjust any additional settings.

- **`config/sender_login_map.pcre`**: Customize sender login mappings if needed.

### 5. Provide a TLS Certificate

See [TLS Certificates](#tls-certificates) below — place (or mount) a certificate and private key under the directory referenced by `CERTS_DIR` before starting the service.

### 6. Start the Postfix Service

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

## TLS Certificates

This project does not run its own ACME client and does not prescribe one. Postfix only needs a certificate and private key at the paths configured via `smtpd_tls_cert_file` / `smtpd_tls_key_file` in `main.cf` (by default `/etc/postfix/certs/fullchain.pem` and `/etc/postfix/certs/privkey.pem`, see `generate-configs.sh`'s `CERT_FILE`/`KEY_FILE` parameters).

`compose.yml` mounts `${CERTS_DIR:-./certs}` read-only into the container at `/etc/postfix/certs`. Point `CERTS_DIR` at wherever your certificate management already lives — for example:
- A directory that your [Caddy](https://caddyserver.com/) instance (or any other ACME client) writes `fullchain.pem`/`privkey.pem` into, shared via a bind mount or Docker volume.
- A directory populated by Certbot, a `cert-manager` export, or a manual/script-based copy — any tool works as long as it produces a certificate and key file at the expected paths.

### Reloading after certificate renewal

Postfix's `smtpd` worker processes read the certificate and private key **once, when the worker process starts** — they are not re-read on every incoming connection. Workers are recycled periodically (after a number of connections / when idle), so a renewed certificate is eventually picked up automatically, but not on a guaranteed schedule.

To make a renewed certificate take effect immediately and reliably, run:

```bash
docker compose exec postfix postfix reload
```

This is a lightweight config reload, **not a restart**: no downtime, no dropped connections. In-flight sessions on already-running workers keep going; only newly spawned workers use the new certificate. Whatever process renews your certificate (Caddy, a cron job, a sync script) should trigger this reload as its last step.

## Security Hardening

This container runs as **root**, which is required by Postfix's own architecture: the `master` process needs root to own the mail queue directories and to `setuid()`/`setgid()` its forked children (`smtpd`, `qmgr`, `pickup`, `cleanup`, ...) down to the unprivileged `postfix` user. This is standard, expected Postfix behavior, not a shortcut taken by this project — a fully rootless Postfix would require fighting the tool's design (pre-baked spool ownership, disabling the `postdrop`/`postqueue` setgid mechanism) for little practical benefit here.

"Running as root" does not mean "running with unrestricted root", though. This container is hardened via:

- **Minimal Linux capabilities:** `cap_drop: [ALL]` plus only `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETGID`, `SETUID`, `KILL` — the specific set the entrypoint and Postfix's privilege-drop mechanism need, nothing more (in particular, no `NET_ADMIN`/`NET_RAW`/`SYS_CHROOT`).
- **`no-new-privileges`:** blocks gaining privileges via setuid/setgid `exec()`. This does not affect Postfix's own internal `setuid()`/`setgid()` privilege drop, but it does mean the setgid `postdrop`/`postqueue` helpers (used for local command-line mail injection via `mail`/`sendmail` inside the container) will not work. This does not affect the SMTP-587 relay path, which never goes through those binaries.
- **Submission-only:** the unauthenticated `smtp:25` listener is disabled in `master.cf`; only `submission:587` (SASL + mandatory TLS) is active.
- **TLS hardening:** `SSLv2`/`SSLv3`/`TLSv1`/`TLSv1.1` and weak ciphers are disabled (`smtpd_tls_protocols`/`smtp_tls_protocols` and `*_ciphers = high` in `config/templates/main.cf`). If you already have an existing `config/main.cf`, re-run `generate-configs.sh` (or apply the equivalent settings by hand) to pick this up — it is not applied automatically to already-generated configs.
- **Digest-pinned, current base image:** `debian:trixie-slim` pinned by digest for reproducible builds, kept fresh via `renovate.json` + a weekly Renovate/CI run (see `.github/workflows/renovate.yml` and `.github/workflows/build.yml`).
- **CI vulnerability scanning:** the image is scanned with Trivy on every build and on a weekly schedule.

Not implemented, intentionally, for this project's scale:
- Secrets (`sasl_passwd`, `users.txt`) are plaintext bind-mounted files, permission-locked to `600` by the entrypoint. Acceptable for a single-operator relay; Docker `secrets:` or an external vault (Vault, SOPS, age) would be the next step if you need more.
- Read-only root filesystem: not currently feasible without a larger refactor (the entrypoint still runs `dpkg-reconfigure` at every start, which needs a writable `dpkg`/`debconf` state).

## Contributing

Contributions are welcome! If you have ideas for improvements or find a bug, please feel free to open an issue or submit a pull request.

## Configuration Templates and Generation

This project uses templates to generate configuration files, making it easy to set up the mail relay for different domains and environments.

### Template Files
- `config/templates/main.cf`: Template for the main Postfix configuration with placeholders like `{{MYDOMAIN}}`, `{{MYHOSTNAME}}`, etc.
- `config/templates/master.cf`: Template for the master process configuration (submission-only by default).
- `config/templates/sender_login_map.pcre`: Template for sender login mappings with domain placeholders.

### Example Files
- Other `.example` files for secrets and credentials (e.g., `config/sasl_passwd.example`, `config/users.txt.example`)

### Generating Configurations
Use the provided tools to generate configurations:

```bash
# Using the script directly
./generate-configs.sh yourdomain.com smtp.yourdomain.com /etc/postfix/certs/fullchain.pem /etc/postfix/certs/privkey.pem

# Using Make with variables
make configs MYDOMAIN=yourdomain.com MYHOSTNAME=smtp.yourdomain.com CERT_FILE=/path/to/cert KEY_FILE=/path/to/key

# Using Make with defaults (will use example.com)
make configs
```

### Customization
After generation, edit the configuration files to match your specific requirements. The generated files are ignored by Git, so your customizations are preserved.
