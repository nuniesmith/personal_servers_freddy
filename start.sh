#!/usr/bin/env bash

# FREDDY stack startup script
# Simple single compose file and .env approach
# Config files organized under services/

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env"

# List of services in dependency order (DB services first)
SERVICES=("photoprism-postgres" "nextcloud-postgres" "authelia-postgres" "redis" "authelia" "nginx" "nextcloud" "photoprism" "homeassistant")

COMPOSE_CMD=""

log() {
	local level="$1"; shift
	case "$level" in
		INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
		WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
		ERROR) echo -e "${RED}[ERROR]${NC} $*" ;;
		DEBUG) echo -e "${BLUE}[DEBUG]${NC} $*" ;;
	esac
}

detect_environment() {
	# Cloud/container markers
	if [[ -f /etc/cloud-id || -f /var/lib/cloud/data/instance-id || -n "${AWS_INSTANCE_ID:-}" || -n "${GCP_PROJECT:-}" || -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
		echo cloud; return
	fi
	if [[ -f /.dockerenv || -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
		echo container; return
	fi
	# Memory check
	if command -v free >/dev/null 2>&1; then
		local mem; mem=$(free -m | awk '/^Mem:/{print $2}')
		if [[ -n "$mem" && "$mem" -lt 2048 ]]; then echo resource_constrained; return; fi
	fi
	# Hostname heuristic
	local hn; hn=$(hostname || true)
	if [[ "$hn" =~ (dev|staging|cloud|vps|server) ]]; then echo dev_server; return; fi
	# Markers
	if [[ -f "$HOME/.laptop" || -f "$PROJECT_ROOT/.local" ]]; then echo laptop; return; fi
	echo laptop
}

DETECTED_ENV=$(detect_environment)

check_prerequisites() {
	log INFO "Checking prerequisites..."
	if ! command -v docker >/dev/null 2>&1; then
		log ERROR "Docker is not installed"; exit 1
	fi
	if ! docker info >/dev/null 2>&1; then
		log ERROR "Docker daemon is not running"; exit 1
	fi
	if command -v docker-compose >/dev/null 2>&1; then
		COMPOSE_CMD="docker-compose"
	elif docker compose version >/dev/null 2>&1; then
		COMPOSE_CMD="docker compose"
	else
		log ERROR "Docker Compose is not available"; exit 1
	fi
	log INFO "Prerequisites OK"
}



create_env_file() {
	if [[ -f "$ENV_FILE" ]]; then
		log INFO ".env already exists"
		return
	fi

	log INFO "Creating .env file..."

	local tz ip puid pgid
	tz="${TZ:-America/Toronto}"
	ip=$(hostname -I 2>/dev/null | awk '{print $1}')
	ip=${ip:-192.168.1.100}
	# Use original user's UID/GID even when running with sudo
	if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
		puid=$SUDO_UID
		pgid=$SUDO_GID
	else
		puid=$(id -u)
		pgid=$(id -g)
	fi

	# Generate secure passwords once, share where needed
	local authelia_db_pw nextcloud_db_pw photoprism_db_pw photoprism_admin_pw authelia_jwt authelia_session authelia_encryption authelia_admin_pw
	if command -v openssl >/dev/null 2>&1; then
		authelia_db_pw="$(openssl rand -hex 16)"
		nextcloud_db_pw="$(openssl rand -hex 16)"
		photoprism_db_pw="$(openssl rand -hex 16)"
		photoprism_admin_pw="$(openssl rand -hex 16)"
		authelia_jwt="$(openssl rand -hex 32)"
		authelia_session="$(openssl rand -hex 32)"
		authelia_encryption="$(openssl rand -hex 32)"
		authelia_admin_pw="$(openssl rand -hex 16)"
	else
		authelia_db_pw="changeme"
		nextcloud_db_pw="changeme"
		photoprism_db_pw="changeme"
		photoprism_admin_pw="pleasechange"
		authelia_jwt="changeme"
		authelia_session="changeme"
		authelia_encryption="changeme"
		authelia_admin_pw="changeme"
		log WARN "openssl not found; using insecure defaults"
	fi

	# Database and user names (constants)
	local NEXTCLOUD_DB_NAME="nextcloud"
	local NEXTCLOUD_DB_USER="nextcloud"
	local PHOTOPRISM_DB_USER="photoprism"

	# Create comprehensive .env file
	cat > "$ENV_FILE" <<EOF
# FREDDY Stack Environment Configuration
# Generated $(date)

# User/Group IDs
PUID=$puid
PGID=$pgid

# Timezone
TZ=$tz

# Domain and SSL settings
DOMAIN=7gram.xyz
EMAIL=nunie.smith01@gmail.com
SUBDOMAINS=wildcard
VALIDATION=http
ONLY_SUBDOMAINS=false
STAGING=false

# Photos path
PHOTOS_PATH=/mnt/1tb/photos

# Watchtower settings
WATCHTOWER_SCHEDULE="0 2 * * *"
WATCHTOWER_NOTIFICATIONS=
WATCHTOWER_NOTIFICATION_URL=
WATCHTOWER_MONITOR_ONLY=false

# ============================================================================
# DATABASE CREDENTIALS
# ============================================================================

# Authelia Database
AUTHELIA_DB_NAME=authelia
AUTHELIA_DB_USER=authelia
AUTHELIA_DB_PASSWORD=$authelia_db_pw

# Nextcloud Database
NEXTCLOUD_DB_NAME=$NEXTCLOUD_DB_NAME
NEXTCLOUD_DB_USER=$NEXTCLOUD_DB_USER
NEXTCLOUD_DB_PASSWORD=$nextcloud_db_pw

# Photoprism Database
PHOTOPRISM_DB_NAME=photoprism
PHOTOPRISM_DB_USER=$PHOTOPRISM_DB_USER
PHOTOPRISM_DB_PASSWORD=$photoprism_db_pw

# ============================================================================
# APPLICATION CREDENTIALS
# ============================================================================

# Authelia Secrets
AUTHELIA_JWT_SECRET=$authelia_jwt
AUTHELIA_SESSION_SECRET=$authelia_session
AUTHELIA_STORAGE_ENCRYPTION_KEY=$authelia_encryption
AUTHELIA_ADMIN_PASSWORD=$authelia_admin_pw

# Photoprism Settings
PHOTOPRISM_ADMIN_PASSWORD=$photoprism_admin_pw
PHOTOPRISM_SITE_URL=http://localhost:2342/
PHOTOPRISM_DATABASE_DRIVER=postgres
PHOTOPRISM_DATABASE_SERVER=photoprism-postgres:5432
PHOTOPRISM_DATABASE_NAME=photoprism
PHOTOPRISM_DATABASE_USER=$PHOTOPRISM_DB_USER
PHOTOPRISM_UID=$puid
PHOTOPRISM_GID=$pgid

# Nextcloud Settings
POSTGRES_HOST=nextcloud-postgres
POSTGRES_DB=$NEXTCLOUD_DB_NAME
POSTGRES_USER=$NEXTCLOUD_DB_USER
POSTGRES_PASSWORD=$nextcloud_db_pw
EOF

	log INFO ".env created at $ENV_FILE"
	
	# Log generated credentials
	log INFO "Generated credentials (store securely):"
	log INFO "Authelia DB: user=authelia, password=$authelia_db_pw"
	log INFO "Nextcloud DB: user=nextcloud, password=$nextcloud_db_pw"
	log INFO "Photoprism DB: user=photoprism, password=$photoprism_db_pw"
	log INFO "Photoprism Admin: password=$photoprism_admin_pw"
	log INFO "Authelia Admin: username=admin, password=$authelia_admin_pw"
}

generate_authelia_configs() {
    local config_dir="/mnt/1tb/authelia/config"
    local config_file="$config_dir/configuration.yml"
    local users_file="$config_dir/users_database.yml"

    if [[ -f "$config_file" ]] && [[ -f "$users_file" ]]; then
        log INFO "Authelia configs already exist"
        return
    fi

    # Load env vars
    source "$ENV_FILE"

    # Generate hash for admin password
    local hash
    hash=$(docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$AUTHELIA_ADMIN_PASSWORD" | sed 's/^Digest: //')
    if [[ -z "$hash" ]]; then
        log ERROR "Failed to generate password hash for Authelia"
        exit 1
    fi

    # Generate users_database.yml if missing
    if [[ ! -f "$users_file" ]]; then
        cat > "$users_file" <<EOF
users:
  admin:
    displayname: "Admin User"
    password: "$hash"
    email: admin@example.com
    groups:
      - admins
EOF
        log INFO "Generated $users_file with admin user"
    fi

    # Generate configuration.yml if missing
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" <<EOF
server:
  address: tcp://0.0.0.0:9091

log:
  level: info

authentication_backend:
  file:
    path: /config/users_database.yml
  password_reset:
    disable: true

access_control:
  default_policy: two_factor
  rules:
    - domain: "*.7gram.xyz"
      policy: two_factor

session:
  name: authelia_session
  secret: \${AUTHELIA_SESSION_SECRET}
  expiration: 1h
  inactivity: 5m
  cookies:
    - domain: 7gram.xyz
      authelia_url: https://auth.7gram.xyz
      same_site: lax
  redis:
    host: redis
    port: 6379

storage:
  encryption_key: \${AUTHELIA_STORAGE_ENCRYPTION_KEY}
  postgres:
    address: authelia-postgres:5432
    database: authelia
    username: authelia
    password: \${AUTHELIA_DB_PASSWORD}

notifier:
  filesystem:
    filename: /config/notification.txt

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

theme: dark
EOF
        log INFO "Generated $config_file"
    fi
}

show_environment_info() {
	echo "Detected environment: $DETECTED_ENV"
	echo "Compose: ${COMPOSE_CMD:-not detected}"
	echo "System: hostname=$(hostname) user=$USER"
	if command -v free >/dev/null 2>&1; then
		echo "Memory: $(free -m | awk '/^Mem:/{print $2}') MB"
	fi
}

docker_network_sanity() {
	log INFO "Checking Docker networking..."
	if ! docker network ls >/dev/null 2>&1; then
		log ERROR "Docker not accessible"; exit 1
	fi
	local testnet="freddy-net-check-$$"
	if docker network create "$testnet" >/dev/null 2>&1; then
		docker network rm "$testnet" >/dev/null 2>&1 || true
		log INFO "Docker networking OK"
	else
		log WARN "Docker networking check failed; continuing"
	fi
}

create_directories() {
    local target_services=("${@}")
    log INFO "Creating missing data directories for ${target_services[*]}..."
    local dirs=()
    for service in "${target_services[@]}"; do
        case "$service" in
            photoprism-postgres)
                dirs+=("/mnt/1tb/photoprism/postgres")
                ;;
            nextcloud-postgres)
                dirs+=("/mnt/1tb/nextcloud/postgres")
                ;;
            authelia-postgres)
                dirs+=("/mnt/1tb/authelia/postgres")
                ;;
            redis)
                dirs+=("/mnt/1tb/authelia/redis")
                ;;
            authelia)
                dirs+=("/mnt/1tb/authelia/config")
                ;;
            nginx)
                dirs+=("/mnt/1tb/nginx/config")
                ;;
            nextcloud)
                dirs+=("/mnt/1tb/nextcloud/config" "/mnt/1tb/nextcloud/data")
                ;;
            photoprism)
                dirs+=("/mnt/1tb/photos" "/mnt/1tb/photoprism/storage")
                ;;
            homeassistant)
                dirs+=("/mnt/1tb/homeassistant")
                ;;
        esac
    done

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || log WARN "Failed to create $dir"
            log INFO "Created $dir"
        else
            log INFO "$dir already exists"
        fi
        # Set permissions if root
        if [[ $EUID -eq 0 ]]; then
            local puid pgid
            puid=$(grep '^PUID=' "$ENV_FILE" | cut -d= -f2)
            pgid=$(grep '^PGID=' "$ENV_FILE" | cut -d= -f2)
            chown -R "$puid:$pgid" "$dir" || log WARN "Failed to chown $dir"
        else
            log WARN "Skipping chown for $dir (not root)"
        fi
    done

    # Generate Authelia configs after dir creation
    if [[ " ${target_services[*]} " =~ " authelia " ]]; then
        generate_authelia_configs
    fi
}



pull_images() {
    local target_services=("${@}")
	log INFO "Pulling images for ${target_services[*]}..."
	if [[ ${#target_services[@]} -eq 0 || "${target_services[0]}" == "all" ]]; then
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull --ignore-pull-failures || true
	else
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull "${target_services[@]}" --ignore-pull-failures || true
	fi
}

start_stack() {
    local target_services=("${@}")
    create_directories "${target_services[@]}"
	log INFO "Starting FREDDY services: ${target_services[*]}..."
	if [[ ${#target_services[@]} -eq 0 || "${target_services[0]}" == "all" ]]; then
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
	else
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d "${target_services[@]}"
	fi
	log INFO "Waiting for services to initialize..."
	sleep 10
	$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
}

stop_stack() {
    local target_services=("${@}")
	log INFO "Stopping FREDDY services: ${target_services[*]}..."
	if [[ ${#target_services[@]} -eq 0 || "${target_services[0]}" == "all" ]]; then
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans
	else
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop "${target_services[@]}"
		$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" rm -f "${target_services[@]}"
	fi
}

health_checks() {
    local target_services=("${@}")
	log INFO "Running quick health checks for ${target_services[*]}..."
	for service in "${target_services[@]}"; do
		case "$service" in
			homeassistant)
				if curl -fsS http://localhost:8123/api/ >/dev/null 2>&1; then
					log INFO "Home Assistant: http://localhost:8123"
				else
					log WARN "Home Assistant not reachable yet"
				fi
				;;
			nextcloud)
				if curl -fsS -k https://localhost:8443/status.php >/dev/null 2>&1; then
					log INFO "Nextcloud: https://localhost:8443"
				else
					log WARN "Nextcloud not reachable yet"
				fi
				;;
			photoprism)
				if curl -fsS http://localhost:2342/api/v1/status >/dev/null 2>&1; then
					log INFO "Photoprism: http://localhost:2342"
				else
					log WARN "Photoprism not reachable yet"
				fi
				;;
			authelia)
				if curl -fsS http://localhost:9091/api/state >/dev/null 2>&1; then
					log INFO "Authelia: http://localhost:9091"
				else
					log WARN "Authelia not reachable yet"
				fi
				;;
			nginx)
				if curl -fsS http://localhost >/dev/null 2>&1; then
					log INFO "Nginx: http://localhost"
				else
					log WARN "Nginx not reachable yet"
				fi
				;;
			photoprism-postgres)
				if docker exec photoprism-postgres pg_isready -U photoprism >/dev/null 2>&1; then
					log INFO "Photoprism Postgres: healthy"
				else
					log WARN "Photoprism Postgres not ready yet"
				fi
				;;
			nextcloud-postgres)
				if docker exec nextcloud-postgres pg_isready -U nextcloud >/dev/null 2>&1; then
					log INFO "Nextcloud Postgres: healthy"
				else
					log WARN "Nextcloud Postgres not ready yet"
				fi
				;;
			authelia-postgres)
				if docker exec authelia-postgres pg_isready -U authelia >/dev/null 2>&1; then
					log INFO "Authelia Postgres: healthy"
				else
					log WARN "Authelia Postgres not ready yet"
				fi
				;;
			redis)
				if docker exec redis redis-cli ping >/dev/null 2>&1; then
					log INFO "Redis: healthy"
				else
					log WARN "Redis not ready yet"
				fi
				;;
		esac
	done
}

usage() {
	cat <<USAGE
FREDDY startup script - Single compose file approach

Usage: $(basename "$0") [options] [service]
	service: all (default) or specific service names like:
	         photoprism-postgres, nextcloud-postgres, authelia-postgres, 
	         redis, authelia, nginx, nextcloud, photoprism, homeassistant

Options:
	--show-env        Print environment info and exit
	--stop            Stop and remove services
	--status          Show compose status
	--logs            Tail logs (Ctrl+C to exit)
	--no-pull         Do not pull images before start
	-h, --help        Show this help

Files:
	docker-compose.yml    Main compose file
	.env                  Environment variables
	services/             Configuration files organized by service
USAGE
}

main() {
	local do_pull=1 action=start target_service="all"
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--show-env) action=showenv; shift ;;
			--stop)     action=stop; shift ;;
			--status)   action=status; shift ;;
			--logs)     action=logs; shift ;;
			--no-pull)  do_pull=0; shift ;;
			-h|--help)  usage; exit 0 ;;
			*) 
				if [[ " ${SERVICES[*]} all " =~ " $1 " ]]; then
					target_service="$1"; shift
				else
					log WARN "Unknown arg: $1"; usage; exit 1
				fi
				;;
		esac
	done

	check_prerequisites
	case "$action" in
		showenv)
			show_environment_info; exit 0 ;;
	esac

	cd "$PROJECT_ROOT"
	create_env_file

	local target_services=()
	if [[ "$target_service" == "all" ]]; then
		target_services=("${SERVICES[@]}")
	else
		target_services=("$target_service")
	fi

	# Clean and sanity check
	$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans >/dev/null 2>&1 || true
	docker_network_sanity

	log INFO "Ensuring shared networks exist..."
	docker network create backend || true
	docker network create frontend || true

	case "$action" in
		stop)
			stop_stack "${target_services[@]}"; exit 0 ;;
		status)
			$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps; exit 0 ;;
		logs)
			if [[ ${#target_services[@]} -eq 0 || "${target_services[0]}" == "all" ]]; then
				$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f
			else
				$COMPOSE_CMD -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f "${target_services[@]}"
			fi
			exit 0 ;;
	esac

	(( do_pull )) && pull_images "${target_services[@]}"
	start_stack "${target_services[@]}"
	health_checks "${target_services[@]}"

	log INFO "Done. Common endpoints:"
	echo "  Home Assistant: http://localhost:8123"
	echo "  Nextcloud:      https://localhost:8443"
	echo "  Photoprism:     http://localhost:2342"
	# Add more as needed
}

main "$@"