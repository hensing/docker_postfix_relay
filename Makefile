.PHONY: help init configs clean test

# Default target
help:
	@echo "Available targets:"
	@echo "  init     - Initialize the project (create directories and copy example configs)"
	@echo "  configs  - Generate configuration files from templates"
	@echo "  clean    - Remove generated configuration files"
	@echo "  test     - Test Postfix configuration"
	@echo ""
	@echo "Usage examples:"
	@echo "  make init"
	@echo "  make configs MYDOMAIN=yourdomain.com"
	@echo "  make configs MYDOMAIN=yourdomain.com MYHOSTNAME=mail.yourdomain.com"

# Initialize project
init:
	./init.sh

# Generate configs with default values
configs:
	./generate-configs.sh $(MYDOMAIN) $(MYHOSTNAME) $(CERT_FILE) $(KEY_FILE) $(RELAYHOST) $(MYNETWORKS) $(SMTP_TLS_LOGLEVEL) $(SMTPD_TLS_LOGLEVEL)

# Clean generated configs
clean:
	rm -f config/main.cf config/sender_login_map.pcre

# Test Postfix configuration
test:
	@if [ -f config/main.cf ]; then \
		echo "Testing Postfix configuration..."; \
		docker run --rm -v $(PWD)/config:/etc/postfix:ro debian:bookworm-slim sh -c "apt-get update && apt-get install -y postfix && postfix check"; \
	else \
		echo "Error: config/main.cf not found. Run 'make configs' first."; \
		exit 1; \
	fi