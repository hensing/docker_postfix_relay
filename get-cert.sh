#!/bin/bash

# This script obtains the initial Let's Encrypt certificate.
# It should be run once after the initial setup.

echo "--- Obtaining Initial Let's Encrypt Certificate ---"

# Check if docker is available
if ! command -v docker &> /dev/null
then
    echo "Error: docker could not be found. Please ensure it is installed and in your PATH."
    exit 1
fi

echo "Running Certbot container to obtain certificate..."
if docker compose run --rm certbot certonly; then
  echo "Certificate obtained successfully."
  echo "Reloading Postfix to apply the new certificate..."
  docker compose exec postfix postfix reload
  echo "Postfix reloaded."
else
  echo "Error: Certificate acquisition failed. Please check the logs above."
  exit 1
fi

echo "--- Certificate Acquisition Process Complete ---"
