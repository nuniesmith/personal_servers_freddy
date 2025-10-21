#!/bin/bash

# =============================================================================
# Authentik Setup Script for FREDDY
# Creates necessary directories and sets up environment for Authentik SSO
# =============================================================================

set -e  # Exit on error

echo "=========================================="
echo "Authentik SSO Setup for FREDDY"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then 
    SUDO=""
else
    SUDO="sudo"
fi

# Step 1: Create volume directories
echo -e "${YELLOW}Step 1: Creating volume directories...${NC}"
$SUDO mkdir -p /mnt/1tb/authentik/{postgres,redis}
echo -e "${GREEN}✓ Created /mnt/1tb/authentik/{postgres,redis}${NC}"

# Step 2: Set ownership (adjust PUID/PGID as needed)
PUID=${PUID:-1000}
PGID=${PGID:-1000}
echo -e "${YELLOW}Step 2: Setting ownership to ${PUID}:${PGID}...${NC}"
$SUDO chown -R ${PUID}:${PGID} /mnt/1tb/authentik
echo -e "${GREEN}✓ Ownership set${NC}"

# Step 3: Check if .env exists
echo -e "${YELLOW}Step 3: Checking environment configuration...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}! .env file not found. Creating from template...${NC}"
    cp .env.example .env
    echo -e "${RED}⚠ IMPORTANT: Edit .env and set the following:${NC}"
    echo -e "${RED}  - AUTHENTIK_SECRET_KEY (generate with: openssl rand -hex 32)${NC}"
    echo -e "${RED}  - AUTHENTIK_POSTGRES_PASSWORD${NC}"
    echo -e "${RED}  - EMAIL_* settings${NC}"
    echo ""
    read -p "Press Enter after you've updated .env..."
else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi

# Step 4: Validate required environment variables
echo -e "${YELLOW}Step 4: Validating environment variables...${NC}"
source .env

if [ -z "$AUTHENTIK_SECRET_KEY" ] || [ "$AUTHENTIK_SECRET_KEY" = "changeme_generate_with_openssl_rand_hex_32" ]; then
    echo -e "${RED}✗ AUTHENTIK_SECRET_KEY not set or still default${NC}"
    echo "Generate one with: openssl rand -hex 32"
    exit 1
fi

if [ -z "$AUTHENTIK_POSTGRES_PASSWORD" ] || [ "$AUTHENTIK_POSTGRES_PASSWORD" = "changeme_secure_password" ]; then
    echo -e "${RED}✗ AUTHENTIK_POSTGRES_PASSWORD not set or still default${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Environment variables validated${NC}"

# Step 5: Pull Docker images
echo -e "${YELLOW}Step 5: Pulling Docker images...${NC}"
docker compose pull authentik-postgres authentik-redis authentik-server authentik-worker
echo -e "${GREEN}✓ Images pulled${NC}"

# Step 6: Start database services
echo -e "${YELLOW}Step 6: Starting database services...${NC}"
docker compose up -d authentik-postgres authentik-redis
echo "Waiting for databases to be ready..."
sleep 10
echo -e "${GREEN}✓ Database services started${NC}"

# Step 7: Run migrations
echo -e "${YELLOW}Step 7: Running initial migrations...${NC}"
docker compose run --rm authentik-server migrate
echo -e "${GREEN}✓ Migrations completed${NC}"

# Step 8: Start Authentik services
echo -e "${YELLOW}Step 8: Starting Authentik server and worker...${NC}"
docker compose up -d authentik-server authentik-worker
echo -e "${GREEN}✓ Authentik services started${NC}"

# Step 9: Wait for services to be healthy
echo -e "${YELLOW}Step 9: Waiting for services to be healthy...${NC}"
echo "This may take up to 90 seconds..."
sleep 30

# Check health status
for i in {1..6}; do
    if docker compose ps | grep -q "authentik-server.*healthy"; then
        echo -e "${GREEN}✓ Authentik is healthy!${NC}"
        break
    else
        echo "Still waiting... ($i/6)"
        sleep 10
    fi
done

# Final status
echo ""
echo "=========================================="
echo -e "${GREEN}Authentik Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Access Authentik at:"
echo "  HTTP:  http://freddy:9000"
echo "  HTTPS: https://freddy:9443 (self-signed cert)"
echo ""
echo "Next steps:"
echo "  1. Access the web UI and complete initial setup"
echo "  2. Create your admin user"
echo "  3. Configure Nginx reverse proxy (Task 3)"
echo "  4. Set up LDAP/OIDC providers (Tasks 4-5)"
echo ""
echo "Logs: docker compose logs -f authentik-server authentik-worker"
echo ""
