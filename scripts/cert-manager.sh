#!/usr/bin/env bash

# Certificate Manager for FREDDY Server
# Manages SSL certificates - detects self-signed vs Let's Encrypt, requests new certs if needed

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DOMAIN="7gram.xyz"
EMAIL="nunie.smith01@gmail.com"
CERT_DIR="/opt/ssl/7gram.xyz"
LETSENCRYPT_DIR="/etc/letsencrypt/live/7gram.xyz"
CLOUDFLARE_CREDS="/etc/letsencrypt/cloudflare.ini"

# Logging
log() {
	local level="$1"; shift
	case "$level" in
		INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
		WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
		ERROR) echo -e "${RED}[ERROR]${NC} $*" ;;
		DEBUG) echo -e "${BLUE}[DEBUG]${NC} $*" ;;
		CERT)  echo -e "${CYAN}[CERT]${NC} $*" ;;
	esac
}

# Check if running as root
check_root() {
	if [[ $EUID -ne 0 ]]; then
		log ERROR "This script must be run as root (use sudo)"
		exit 1
	fi
}

# Check if certbot is installed
check_certbot() {
	if ! command -v certbot >/dev/null 2>&1; then
		log WARN "Certbot not found, installing..."
		dnf install -y certbot python3-certbot-dns-cloudflare
		log INFO "Certbot installed"
	fi
}

# Detect certificate type
detect_cert_type() {
	if [[ ! -f "$CERT_DIR/fullchain.pem" ]]; then
		echo "none"
		return
	fi
	
	local issuer subject
	issuer=$(openssl x509 -in "$CERT_DIR/fullchain.pem" -noout -issuer 2>/dev/null || echo "")
	subject=$(openssl x509 -in "$CERT_DIR/fullchain.pem" -noout -subject 2>/dev/null || echo "")
	
	if [[ -z "$issuer" ]]; then
		echo "invalid"
	elif echo "$issuer" | grep -qi "Let's Encrypt"; then
		echo "letsencrypt"
	elif [[ "$issuer" == "$subject" ]] || echo "$issuer" | grep -qi "7gram.xyz"; then
		# Self-signed if issuer equals subject or contains the domain
		echo "self-signed"
	else
		echo "unknown"
	fi
}

# Show certificate info
show_cert_info() {
	log CERT "Current certificate information:"
	if [[ -f "$CERT_DIR/fullchain.pem" ]]; then
		echo ""
		openssl x509 -in "$CERT_DIR/fullchain.pem" -noout -issuer -subject -dates 2>/dev/null | sed 's/^/  /'
		echo ""
	else
		log WARN "No certificate found at $CERT_DIR/fullchain.pem"
	fi
}

# Setup Cloudflare credentials
setup_cloudflare_creds() {
	if [[ -f "$CLOUDFLARE_CREDS" ]]; then
		log INFO "Cloudflare credentials already exist"
		return 0
	fi
	
	log INFO "Setting up Cloudflare DNS credentials..."
	echo ""
	echo "📋 Get your Cloudflare API credentials from:"
	echo "   https://dash.cloudflare.com/profile/api-tokens"
	echo ""
	echo "   You can use either:"
	echo "   1. Global API Key (easier setup)"
	echo "   2. API Token with Zone:DNS:Edit permissions (more secure)"
	echo ""
	
	read -p "Cloudflare Email: " cloudflare_email
	read -p "Cloudflare Global API Key (or leave empty to use token): " cloudflare_api_key
	
	if [[ -n "$cloudflare_api_key" ]]; then
		# Using Global API Key
		cat > "$CLOUDFLARE_CREDS" <<EOF
# Cloudflare API credentials using Global API Key
dns_cloudflare_email = $cloudflare_email
dns_cloudflare_api_key = $cloudflare_api_key
EOF
	else
		# Using API Token
		read -p "Cloudflare API Token: " cloudflare_token
		cat > "$CLOUDFLARE_CREDS" <<EOF
# Cloudflare API credentials using API Token
dns_cloudflare_api_token = $cloudflare_token
EOF
	fi
	
	chmod 600 "$CLOUDFLARE_CREDS"
	log INFO "Cloudflare credentials saved to $CLOUDFLARE_CREDS"
}

# Request Let's Encrypt certificate
request_letsencrypt() {
	local force_renew="${1:-no}"
	log CERT "Requesting Let's Encrypt certificate for $DOMAIN and *.$DOMAIN"
	
	# Ensure Cloudflare credentials exist
	setup_cloudflare_creds
	
	# Build certbot command
	local certbot_args=(
		certonly
		--dns-cloudflare
		--dns-cloudflare-credentials "$CLOUDFLARE_CREDS"
		--dns-cloudflare-propagation-seconds 60
		-d "$DOMAIN"
		-d "*.$DOMAIN"
		--agree-tos
		--email "$EMAIL"
		--non-interactive
		--expand
	)
	
	# Add force-renewal flag if requested
	if [[ "$force_renew" == "yes" ]]; then
		log INFO "Forcing certificate renewal..."
		certbot_args+=(--force-renewal)
	fi
	
	# Request certificate
	certbot "${certbot_args[@]}" || {
		log ERROR "Failed to obtain Let's Encrypt certificate"
		return 1
	}
	
	log INFO "Certificate obtained successfully"
	copy_letsencrypt_certs
}

# Copy Let's Encrypt certs to nginx directory
copy_letsencrypt_certs() {
	if [[ ! -d "$LETSENCRYPT_DIR" ]]; then
		log ERROR "Let's Encrypt directory not found: $LETSENCRYPT_DIR"
		return 1
	fi
	
	log INFO "Copying Let's Encrypt certificates to $CERT_DIR"
	mkdir -p "$CERT_DIR"
	
	cp -L "$LETSENCRYPT_DIR/fullchain.pem" "$CERT_DIR/"
	cp -L "$LETSENCRYPT_DIR/privkey.pem" "$CERT_DIR/"
	
	chmod 644 "$CERT_DIR/fullchain.pem"
	chmod 600 "$CERT_DIR/privkey.pem"
	
	log INFO "Certificates copied successfully"
}

# Generate self-signed certificate (fallback)
generate_self_signed() {
	log WARN "Generating self-signed certificate (for testing only)"
	
	mkdir -p "$CERT_DIR"
	
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout "$CERT_DIR/privkey.pem" \
		-out "$CERT_DIR/fullchain.pem" \
		-subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$DOMAIN/subjectAltName=DNS:*.$DOMAIN" \
		-addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN" 2>/dev/null || {
			log ERROR "Failed to generate self-signed certificate"
			return 1
		}
	
	chmod 644 "$CERT_DIR/fullchain.pem"
	chmod 600 "$CERT_DIR/privkey.pem"
	
	log INFO "Self-signed certificate generated"
}

# Reload nginx container
reload_nginx() {
	if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
		log INFO "Reloading nginx..."
		docker exec nginx nginx -s reload 2>/dev/null || docker restart nginx
		log INFO "Nginx reloaded"
	fi
}

# Setup automatic renewal
setup_renewal() {
	log INFO "Setting up automatic certificate renewal..."
	
	# Create renewal script
	cat > /usr/local/bin/renew-freddy-certs.sh <<'EOF'
#!/bin/bash
# Automatic certificate renewal for FREDDY server

CERT_DIR="/opt/ssl/7gram.xyz"
LETSENCRYPT_DIR="/etc/letsencrypt/live/7gram.xyz"

# Renew certificates
certbot renew --quiet

# Copy renewed certificates if they exist
if [[ -f "$LETSENCRYPT_DIR/fullchain.pem" ]]; then
    cp -L "$LETSENCRYPT_DIR/fullchain.pem" "$CERT_DIR/"
    cp -L "$LETSENCRYPT_DIR/privkey.pem" "$CERT_DIR/"
    chmod 644 "$CERT_DIR/fullchain.pem"
    chmod 600 "$CERT_DIR/privkey.pem"
    
    # Reload nginx if running
    if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
        docker exec nginx nginx -s reload 2>/dev/null || true
    fi
    
    logger "FREDDY certificates renewed and nginx reloaded"
fi
EOF
	
	chmod +x /usr/local/bin/renew-freddy-certs.sh
	
	# Create systemd service
	cat > /etc/systemd/system/freddy-cert-renewal.service <<EOF
[Unit]
Description=FREDDY Certificate Renewal
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/renew-freddy-certs.sh
User=root
EOF
	
	# Create systemd timer
	cat > /etc/systemd/system/freddy-cert-renewal.timer <<EOF
[Unit]
Description=Run FREDDY certificate renewal twice daily
Requires=freddy-cert-renewal.service

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF
	
	# Enable timer
	systemctl daemon-reload
	systemctl enable freddy-cert-renewal.timer
	systemctl start freddy-cert-renewal.timer
	
	log INFO "Automatic renewal configured (runs at 00:00 and 12:00 daily)"
}

# Test renewal
test_renewal() {
	log INFO "Testing certificate renewal (dry run)..."
	certbot renew --dry-run
}

# Main function
main() {
	local action="${1:-check}"
	
	case "$action" in
		check)
			log INFO "Checking certificate status..."
			local cert_type
			cert_type=$(detect_cert_type)
			
			case "$cert_type" in
				none)
					log WARN "No certificate found"
					show_cert_info
					echo ""
					log INFO "Recommendation: Run 'sudo $0 request' to get Let's Encrypt certificate"
					;;
				self-signed)
					log WARN "Self-signed certificate detected"
					show_cert_info
					echo ""
					log INFO "Recommendation: Run 'sudo $0 upgrade' to upgrade to Let's Encrypt"
					;;
				letsencrypt)
					log INFO "✓ Let's Encrypt certificate is active"
					show_cert_info
					;;
				invalid|unknown)
					log ERROR "Invalid or unknown certificate type"
					show_cert_info
					;;
			esac
			;;
			
		request)
			check_root
			check_certbot
			log INFO "Requesting new Let's Encrypt certificate..."
			request_letsencrypt
			setup_renewal
			reload_nginx
			show_cert_info
			log INFO "✓ Certificate setup complete!"
			;;
			
		upgrade)
			check_root
			check_certbot
			local cert_type
			cert_type=$(detect_cert_type)
			
			if [[ "$cert_type" == "letsencrypt" ]]; then
				log INFO "Already using Let's Encrypt certificate"
				show_cert_info
				exit 0
			fi
			
			log INFO "Upgrading from $cert_type to Let's Encrypt..."
			
			# Backup existing cert
			if [[ -f "$CERT_DIR/fullchain.pem" ]]; then
				log INFO "Backing up existing certificate..."
				cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem.backup.$(date +%Y%m%d_%H%M%S)"
				cp "$CERT_DIR/privkey.pem" "$CERT_DIR/privkey.pem.backup.$(date +%Y%m%d_%H%M%S)"
			fi
			
			# Force renewal to ensure we get a fresh Let's Encrypt certificate
			request_letsencrypt "yes"
			setup_renewal
			reload_nginx
			show_cert_info
			
			log INFO "✓ Successfully upgraded to Let's Encrypt!"
			log INFO "💡 Certificate active and nginx reloaded"
			;;
			
		renew)
			check_root
			log INFO "Renewing certificates..."
			/usr/local/bin/renew-freddy-certs.sh
			log INFO "✓ Renewal complete"
			;;
			
		test-renewal)
			check_root
			test_renewal
			;;
			
		self-signed)
			check_root
			log WARN "Generating self-signed certificate (for testing only)"
			generate_self_signed
			reload_nginx
			show_cert_info
			;;
			
		info)
			show_cert_info
			;;
			
		*)
			cat <<USAGE
FREDDY Certificate Manager

Usage: $0 [command]

Commands:
  check         Check current certificate status (default)
  request       Request new Let's Encrypt certificate
  upgrade       Upgrade from self-signed to Let's Encrypt
  renew         Manually renew certificates
  test-renewal  Test renewal process (dry run)
  self-signed   Generate self-signed certificate (fallback)
  info          Show certificate information

Examples:
  sudo $0 check          # Check current certificate
  sudo $0 upgrade        # Upgrade to Let's Encrypt
  sudo $0 test-renewal   # Test renewal process

Files:
  Certificates:    $CERT_DIR/
  Let's Encrypt:   $LETSENCRYPT_DIR/
  Cloudflare API:  $CLOUDFLARE_CREDS

USAGE
			;;
	esac
}

main "$@"