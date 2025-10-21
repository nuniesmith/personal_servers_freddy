# GitHub Copilot Instructions - FREDDY Server

## Server Overview

**FREDDY** is the lightweight authentication and storage server in the 7gram.xyz homelab infrastructure.

### Primary Functions
- **Authentication**: Authentik SSO (replacing Authelia)
- **Photo Management**: PhotoPrism
- **Cloud Storage**: Nextcloud
- **File Sync**: Syncthing
- **Web Server**: Nginx reverse proxy with SSL

### Server Specifications
- **Role**: Lightweight services, authentication hub
- **Domain**: 7gram.xyz
- **Network**: Tailscale VPN overlay
- **Storage**: /mnt/1tb for persistent data

## Architecture Principles

### Docker Compose Strategy
- **Bind mounts** for configs (git-tracked in ./services/*/config)
- **Named volumes** for databases (protected from pruning)
- **Named volumes** for caches (pruneable)
- **Networks**: frontend (nginx), backend (services), database (postgres/redis)

### Authentication Stack
- **SSO Provider**: Authentik (PostgreSQL + Redis)
- **Auth Methods**: LDAP, OIDC, Forward Auth
- **LDAP Base DN**: dc=7gram,dc=xyz
- **Auth Endpoint**: auth.7gram.xyz

### Volume Management
```yaml
# Config (git-tracked bind mounts)
./services/<service>/config:/config

# Cache (pruneable named volumes)
<service>_cache:/cache

# Database (protected named volumes)
<service>_postgres:/var/lib/postgresql/data
```

## Code Conventions

### Docker Compose Files
- Use `freddy_` prefix for named volumes
- Use `freddy_` prefix for networks
- Mount `/var/run/docker.sock` read-only when needed
- Always specify restart policies (usually `unless-stopped`)
- Group related services with comments

### Environment Variables
- Store secrets in `.env` (git-ignored)
- Provide `.env.example` with dummy values
- Use `${VARIABLE_NAME}` syntax in docker-compose.yml
- Document all required variables

### Nginx Configuration
- One file per subdomain in `services/nginx/conf.d/`
- Forward auth: include `/etc/nginx/conf.d/authentik-authrequest.conf;`
- SSL certs in `/opt/ssl/7gram.xyz/`
- Use proxy_pass to Docker service names on backend network

### Scripts
- All scripts in `./scripts/` directory
- Use bash with error handling (`set -euo pipefail`)
- Include usage/help text
- Log to `/var/log/` when running via systemd
- Make executable with `chmod +x`

## Service-Specific Guidelines

### Authentik
- **Ports**: 9000 (HTTP), 9443 (HTTPS)
- **Database**: PostgreSQL 16
- **Cache**: Redis Alpine
- **Workers**: authentik-server + authentik-worker
- **Migration**: Always run `migrate` before first start
- **Secret**: Generate with `openssl rand -hex 32`

### PhotoPrism
- **Storage**: /mnt/1tb/photoprism_data
- **Database**: PostgreSQL (protected volume)
- **Config**: Bind mount at ./services/photoprism/config

### Nextcloud
- **Database**: PostgreSQL (protected volume)
- **Data**: /mnt/1tb/nextcloud_data
- **LDAP**: Integrate with Authentik after SSO setup

### Nginx
- **Config location**: ./services/nginx/conf.d/
- **Reload**: `docker compose exec nginx nginx -s reload`
- **Test config**: `docker compose exec nginx nginx -t`
- **SSL**: Certbot with DNS challenge (Cloudflare)

## Common Tasks

### Adding a New Service
1. Create `./services/<service>/` directory
2. Add service to docker-compose.yml with:
   - Bind mounts for configs
   - Named volumes for cache/database
   - Appropriate networks (frontend/backend)
   - Environment variables via .env
3. Create nginx config in `conf.d/<service>.conf`
4. Add DNS entry for `<service>.7gram.xyz`
5. Document in service README.md

### Implementing Forward Auth
1. Include authentik snippets in nginx config:
   ```nginx
   include /etc/nginx/conf.d/authentik-authrequest.conf;
   include /etc/nginx/conf.d/authentik-location.conf;
   ```
2. Add redirect on auth failure:
   ```nginx
   error_page 401 = @authentik_proxy_signin;
   ```
3. Forward user headers to backend:
   ```nginx
   proxy_set_header X-Authentik-Username $authentik_user;
   proxy_set_header X-Authentik-Email $authentik_email;
   ```

### Updating Environment Variables
1. Edit `.env` file (never commit!)
2. Recreate affected services: `docker compose up -d <service>`
3. Verify with: `docker compose exec <service> env | grep VARIABLE`

### Database Migrations
```bash
# Authentik
docker compose run --rm authentik-server migrate

# General pattern
docker compose exec <service> <migration-command>
```

### Viewing Logs
```bash
# All services
docker compose logs -f

# Specific service with timestamps
docker compose logs -f --timestamps <service>

# Last 100 lines
docker compose logs --tail=100 <service>
```

## Maintenance

### Weekly Automated Cleanup
- **Schedule**: Sundays at 2:00 AM
- **Script**: `./scripts/cleanup-docker-cache.sh`
- **Protected volumes**: All postgres, redis, authentik_*
- **Systemd**: `docker-cleanup.timer`

### Manual Cleanup
```bash
# Safe cleanup (protects databases)
sudo ./scripts/cleanup-docker-cache.sh

# Verify bind mounts after cleanup
ls -la services/*/config
```

### Backup Strategy
- **Configs**: Git-tracked in ./services/
- **Databases**: Volume backups via duplicati/restic
- **Media**: /mnt/1tb backed up to cloud storage

## Security

### Authentication
- All services behind Authentik SSO (except auth.7gram.xyz)
- LDAP: Port 636 (LDAPS) only, no plain LDAP
- OIDC: Use state/PKCE, configure redirect URIs
- Forward Auth: Nginx validates with Authentik before proxying

### Network Isolation
- Frontend network: nginx only
- Backend network: nginx + services
- Database network: services + postgres/redis
- No direct external access to backend/database networks

### Secrets Management
- `.env` file (git-ignored)
- Docker secrets for sensitive data
- Rotate secrets quarterly
- Never commit passwords/keys

## Troubleshooting

### Service Won't Start
```bash
# Check logs
docker compose logs <service>

# Verify config
docker compose config

# Check dependencies
docker compose ps
```

### Nginx 502 Bad Gateway
1. Check backend service is running: `docker compose ps <service>`
2. Verify network connectivity: `docker compose exec nginx ping <service>`
3. Check nginx error logs: `docker compose logs nginx`
4. Test nginx config: `docker compose exec nginx nginx -t`

### Authentik Issues
1. Check database: `docker compose exec authentik-postgres pg_isready`
2. Check Redis: `docker compose exec authentik-redis redis-cli ping`
3. View worker logs: `docker compose logs authentik-worker`
4. Check migrations: `docker compose run --rm authentik-server migrate --check`

## Related Infrastructure

### Sister Server: SULLIVAN
- **Purpose**: Media processing, downloads, AI workloads
- **Coordination**: Shares Tailscale network, uses FREDDY for auth
- **Services**: Emby, Jellyfin, Plex, *arr apps, Ollama

### Domain Management
- **Registrar**: Cloudflare
- **DNS**: Cloudflare (for Let's Encrypt DNS challenge)
- **SSL**: Certbot with wildcard cert for *.7gram.xyz

## Git Workflow

### What to Commit
✅ docker-compose.yml  
✅ .env.example (no secrets)  
✅ ./services/*/config/ (sanitized)  
✅ ./scripts/*.sh  
✅ nginx configs (./services/nginx/conf.d/)  
✅ Documentation (*.md)  

### What to Ignore
❌ .env (contains secrets)  
❌ ./services/*/cache/  
❌ ./services/*/logs/  
❌ ./services/*/database/ (if bind mounted)  
❌ /mnt/1tb/* (user data)  

## When Generating Code

### Preferences
- **Language**: Bash for scripts, YAML for compose
- **Style**: Clear > clever, documented > terse
- **Error handling**: Always check return codes
- **Logging**: Include timestamps and severity
- **Validation**: Test configs before applying

### Avoid
- Hardcoded secrets in compose files
- Anonymous volumes (always name them)
- Running containers as root when unnecessary
- Exposing database ports to host
- Modifying files in volumes directly (use docker exec)

## Quick Reference

```bash
# Start all services
docker compose up -d

# Restart specific service
docker compose restart <service>

# View service status
docker compose ps

# Execute command in service
docker compose exec <service> <command>

# Remove stopped containers
docker compose down

# Rebuild and restart
docker compose up -d --build <service>

# View resource usage
docker stats

# Clean up safely
sudo ./scripts/cleanup-docker-cache.sh
```

---

**Remember**: FREDDY handles authentication for the entire homelab. Changes to Authentik impact all services across both servers. Always test auth changes in staging subdomain first.
