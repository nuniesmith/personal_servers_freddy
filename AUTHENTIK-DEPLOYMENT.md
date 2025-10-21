# Authentik Deployment Guide - Task 2

This guide walks through deploying and initializing Authentik on the FREDDY server.

## Prerequisites

Before deploying, verify these are complete:

### Infrastructure Ready ✅
- [ ] `docker-compose.yml` has Authentik services (Task 1)
- [ ] `services/authentik/` directory structure exists
- [ ] Nginx configs created (`authentik.conf`, forward auth snippets)
- [ ] SSL certificate available at `/opt/ssl/7gram.xyz/`

### Network Ready ✅
- [ ] DNS: `auth.7gram.xyz` → FREDDY Tailscale IP
- [ ] Firewall: Ports 9000/9443 accessible internally
- [ ] FREDDY accessible via Tailscale

### Environment Ready ✅
- [ ] Docker and Docker Compose installed
- [ ] .env file created from .env.example

## Step 1: Create Environment File

```bash
cd /path/to/freddy

# Copy example
cp .env.example .env

# Generate secret key
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -hex 32)" >> .env

# Edit remaining variables
nano .env
```

Required variables in `.env`:
```bash
# Authentik Core
AUTHENTIK_SECRET_KEY=<generated-above>
AUTHENTIK_POSTGRES_PASSWORD=<strong-password>
AUTHENTIK_POSTGRES_USER=authentik
AUTHENTIK_POSTGRES_DB=authentik

# Email (for password resets, notifications)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=<app-password>
EMAIL_USE_TLS=true
EMAIL_FROM=noreply@7gram.xyz

# Domain
AUTHENTIK_HOST=https://auth.7gram.xyz
AUTHENTIK_COOKIE_DOMAIN=.7gram.xyz

# Error reporting (optional)
AUTHENTIK_ERROR_REPORTING__ENABLED=false
```

**Security Note**: Never commit the `.env` file to git!

## Step 2: Verify DNS Configuration

```bash
# From FREDDY server
ping auth.7gram.xyz

# Should resolve to FREDDY's Tailscale IP
# If not, update DNS:
# Cloudflare: auth.7gram.xyz → <freddy-tailscale-ip>
```

## Step 3: Verify SSL Certificates

```bash
# Check certificates exist
ls -la /opt/ssl/7gram.xyz/

# Should see:
# fullchain.pem (or cert.pem)
# privkey.pem (or key.pem)

# If missing, run Let's Encrypt script
cd scripts
sudo ./letsencrypt.sh
```

## Step 4: Start PostgreSQL and Redis

```bash
cd /path/to/freddy

# Start database services first
docker compose up -d authentik-postgres authentik-redis

# Wait for databases to be ready (30 seconds)
sleep 30

# Verify PostgreSQL is ready
docker compose exec authentik-postgres pg_isready
# Should output: /var/run/postgresql:5432 - accepting connections

# Verify Redis is ready
docker compose exec authentik-redis redis-cli ping
# Should output: PONG
```

## Step 5: Run Database Migrations

```bash
# Run migrations to set up database schema
docker compose run --rm authentik-server migrate

# Expected output:
# Operations to perform:
#   Apply all migrations: admin, auth, contenttypes, sessions, ...
# Running migrations:
#   Applying contenttypes.0001_initial... OK
#   ...
```

## Step 6: Start Authentik Services

```bash
# Start server and worker
docker compose up -d authentik-server authentik-worker

# Verify all Authentik services are running
docker compose ps | grep authentik

# Should show 4 services running:
# - authentik-postgres
# - authentik-redis
# - authentik-server
# - authentik-worker
```

## Step 7: Check Logs

```bash
# View server logs
docker compose logs -f authentik-server

# Look for successful startup:
# "Authentik server listening on 0.0.0.0:9000"
# "Worker process is ready"

# Check for errors
docker compose logs authentik-worker | grep -i error
```

## Step 8: Access Web Interface

### Option A: Direct Access (Testing)
```bash
# From browser on same network:
http://freddy:9000
# or
http://<freddy-tailscale-ip>:9000
```

### Option B: Via Nginx (Production)

1. **Enable Nginx config:**
```bash
# The config should already exist from Task 1
ls -la services/nginx/conf.d/authentik.conf

# Restart nginx to load config
docker compose restart nginx

# Test nginx config
docker compose exec nginx nginx -t
```

2. **Access via domain:**
```
https://auth.7gram.xyz
```

## Step 9: Initial Setup Wizard

When you first access Authentik, you'll see the setup wizard:

### 1. Create Admin User
- **Email**: admin@7gram.xyz (or your email)
- **Username**: admin
- **Password**: Strong password (store in password manager!)

### 2. Configure Default Tenant
- **Domain**: 7gram.xyz
- **Default**: Yes
- **Branding**: Optional (can customize later)

### 3. Complete Setup
- Click "Finish Setup"
- You'll be logged into the admin interface

## Step 10: Verify Installation

### Check Admin Interface
- [ ] Can access https://auth.7gram.xyz
- [ ] Can log in with admin credentials
- [ ] Dashboard loads without errors
- [ ] Can navigate to Applications, Providers, etc.

### Check Docker Services
```bash
# All services healthy
docker compose ps

# No restart loops
docker compose ps | grep -i restart

# Check resource usage
docker stats --no-stream | grep authentik
```

### Check Database
```bash
# Connect to database
docker compose exec authentik-postgres psql -U authentik -d authentik

# List tables (should see many authentik_* tables)
\dt

# Exit
\q
```

### Check Logs
```bash
# No critical errors in last 100 lines
docker compose logs --tail=100 authentik-server | grep -i error
docker compose logs --tail=100 authentik-worker | grep -i error
```

## Step 11: Initial Configuration

After setup, configure these basics:

### 1. Update Admin Profile
- Navigate to: User menu → Settings
- Add full name, avatar
- Verify email address

### 2. Configure Outpost
- Navigate to: System → Outposts
- Verify "authentik Embedded Outpost" exists
- This handles LDAP and proxy providers

### 3. Set Up Authentication Flows
- Navigate to: Flows & Stages
- Verify default flows exist:
  - default-authentication-flow
  - default-invalidation-flow
  - default-source-authentication
  - default-enrollment-flow

### 4. Configure Branding (Optional)
- Navigate to: System → Brands
- Edit "authentik Default"
- Upload logo, set title, customize colors

## Troubleshooting

### Can't Access Web Interface

**Check service is running:**
```bash
docker compose ps authentik-server
```

**Check port binding:**
```bash
docker compose port authentik-server 9000
# Should show: 0.0.0.0:9000
```

**Check nginx logs:**
```bash
docker compose logs nginx | grep auth
```

### Database Connection Errors

**Verify postgres is ready:**
```bash
docker compose exec authentik-postgres pg_isready
```

**Check environment variables:**
```bash
docker compose exec authentik-server env | grep POSTGRES
```

**Check database logs:**
```bash
docker compose logs authentik-postgres
```

### Migration Fails

**Check database is empty (first install):**
```bash
docker compose exec authentik-postgres psql -U authentik -d authentik -c "\dt"
# Should show no tables or error on first run
```

**Reset and retry:**
```bash
# Stop services
docker compose down

# Remove database volume (WARNING: loses data!)
docker volume rm freddy_authentik_postgres

# Recreate and migrate
docker compose up -d authentik-postgres authentik-redis
sleep 30
docker compose run --rm authentik-server migrate
docker compose up -d authentik-server authentik-worker
```

### Email Not Working

**Test SMTP manually:**
```bash
# Install swaks
apt install swaks

# Test email
swaks --to admin@7gram.xyz \
  --from noreply@7gram.xyz \
  --server smtp.gmail.com:587 \
  --auth-user your-email@gmail.com \
  --auth-password '<app-password>' \
  --tls
```

**Check Authentik email config:**
- Navigate to: System → Settings → Email
- Click "Test email" to send test message

### Worker Not Processing Tasks

**Check worker logs:**
```bash
docker compose logs -f authentik-worker
```

**Restart worker:**
```bash
docker compose restart authentik-worker
```

**Check Redis connection:**
```bash
docker compose exec authentik-worker redis-cli -h authentik-redis ping
```

## Security Checklist

After deployment, verify:

- [ ] `.env` file has strong passwords (not defaults)
- [ ] `.env` file is git-ignored
- [ ] Admin account has strong password
- [ ] HTTPS is working (via nginx)
- [ ] HTTP redirects to HTTPS
- [ ] Database is not exposed to external network
- [ ] Only nginx is in frontend network
- [ ] Authentik services are in backend network only

## Backup Configuration

After successful setup:

```bash
# Backup database
docker compose exec authentik-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql

# Backup environment
cp .env .env.backup-$(date +%Y%m%d)

# Backup to secure location
# Store these backups in password manager or encrypted storage
```

## Next Steps

After Authentik is deployed:

1. **Task 4**: Set up LDAP provider for media servers
2. **Task 5**: Set up OIDC providers for Portainer, Home Assistant, Wiki.js
3. **Tasks 6-10**: Integrate individual applications

## Quick Commands Reference

```bash
# Restart all Authentik services
docker compose restart authentik-server authentik-worker

# View logs
docker compose logs -f authentik-server authentik-worker

# Run migrations (after updates)
docker compose run --rm authentik-server migrate

# Access PostgreSQL
docker compose exec authentik-postgres psql -U authentik -d authentik

# Access Redis
docker compose exec authentik-redis redis-cli

# Backup database
docker compose exec authentik-postgres pg_dump -U authentik authentik > backup.sql

# Restore database
docker compose exec -T authentik-postgres psql -U authentik authentik < backup.sql

# Update Authentik
docker compose pull authentik-server authentik-worker
docker compose run --rm authentik-server migrate
docker compose up -d authentik-server authentik-worker
```

---

**Status**: Ready to deploy  
**Prerequisites**: Completed Task 1  
**Next**: Create LDAP and OIDC providers (Tasks 4-5)
