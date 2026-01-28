#!/bin/bash

# This script renews Let's Encrypt certificates and reloads Postfix if a renewal occurred.
# It is intended to be run from a cron job.

# --- IMPORTANT ---
# Set the absolute path to the directory containing your docker-compose.yml file.
# For example: PROJECT_DIR="/opt/stacks/postfix"
PROJECT_DIR="/opt/stacks/postfix"

# --- Script Body ---
# Ensure the script exits if any command fails
set -e

# Check if the project directory exists.
if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Project directory not found at $PROJECT_DIR"
  echo "Please edit this script and set the PROJECT_DIR variable."
  exit 1
fi

# Navigate to the project directory.
cd "$PROJECT_DIR"

echo "--- Starting Certificate Renewal Check at $(date) ---"

# Run the certbot renew command.
# We capture the output to check if a renewal actually happened.
# The --quiet flag reduces the output unless there is an error or a renewal.
RENEWAL_OUTPUT=$(docker compose run --rm certbot renew --no-random-sleep --quiet)

# Check if the output contains "Congratulations" which indicates a successful renewal.
if echo "$RENEWAL_OUTPUT" | grep -q "Congratulations"; then
  echo "A certificate was renewed. Reloading Postfix..."
  docker compose exec postfix postfix reload
  echo "Postfix reloaded successfully."
else
  echo "No certificates were due for renewal."
fi

echo "--- Certificate Renewal Check Finished ---"
