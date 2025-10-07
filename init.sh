#!/bin/bash

# This script performs one-time initialization for the Postfix relay project.
# It ensures that necessary directories and files exist before starting the services.

echo "--- Initializing Postfix Relay Environment ---"

# Create the data directory if it doesn't exist
mkdir -p ./data
echo "Ensuring ./data directory exists."

# Create empty log files if they don't exist to prevent Docker from creating directories
touch ./data/mail.log
echo "Ensuring ./data/mail.log file exists."

touch ./data/letsencrypt.log
echo "Ensuring ./data/letsencrypt.log file exists."

echo "--- Initialization Complete ---"
echo "You can now run './get-cert.sh' to obtain your initial certificate,"
echo "and then 'docker compose up -d' to start the Postfix service."
