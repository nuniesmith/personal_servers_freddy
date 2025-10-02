#!/bin/bash
# Certificate renewal script for Docker nginx
# This script updates certificates and refreshes them in the docker volume

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local level="$1"; shift
    case "$level" in
        INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $*" ;;
    esac
}

DOMAIN="7gram.xyz"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
DOCKER_CERT_PATH="/opt/ssl/$DOMAIN"

# Function to copy certificates to docker location
update_docker_certs() {
    log INFO "Updating certificates for Docker..."
    
    # Create docker cert directory if it doesn't exist
    sudo mkdir -p "$DOCKER_CERT_PATH"
    
    # Use -L to follow symbolic links and copy
    if sudo cp -L "$CERT_PATH/fullchain.pem" "$DOCKER_CERT_PATH/fullchain.pem" 2>/dev/null && \
       sudo cp -L "$CERT_PATH/privkey.pem" "$DOCKER_CERT_PATH/privkey.pem" 2>/dev/null; then
        sudo chmod 644 "$DOCKER_CERT_PATH/fullchain.pem"
        sudo chmod 600 "$DOCKER_CERT_PATH/privkey.pem"
        log INFO "Certificates updated successfully"
        return 0
    else
        log ERROR "Failed to copy certificate files from $CERT_PATH"
        return 1
    fi
}

# Function to reload nginx
reload_nginx() {
    log INFO "Reloading nginx..."
    if docker exec nginx nginx -s reload >/dev/null 2>&1; then
        log INFO "Nginx reloaded successfully"
    else
        log WARN "Failed to reload nginx, trying restart..."
        docker restart nginx
    fi
}

# Main execution
case "${1:-}" in
    "renew")
        log INFO "Attempting certificate renewal..."
        if sudo certbot renew --quiet; then
            log INFO "Certificate renewal completed"
            update_docker_certs && reload_nginx
        else
            log WARN "Certificate renewal not needed or failed"
        fi
        ;;
    "update")
        log INFO "Updating Docker certificates from existing Let's Encrypt certs..."
        update_docker_certs && reload_nginx
        ;;
    "obtain")
        log INFO "Obtaining new certificate for $DOMAIN..."
        sudo certbot certonly --webroot -w /var/www/html -d "$DOMAIN" -d "*.$DOMAIN" --email "nunie.smith01@gmail.com" --agree-tos --non-interactive
        update_docker_certs
        ;;
    *)
        echo "Usage: $0 {renew|update|obtain}"
        echo "  renew  - Renew existing certificates"
        echo "  update - Copy existing certificates to docker location"  
        echo "  obtain - Obtain new certificates (requires webroot setup)"
        exit 1
        ;;
esac