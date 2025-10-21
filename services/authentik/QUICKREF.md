# Authentik Quick Reference

## Initial Setup Commands

### 1. Generate Secret Key
```bash
openssl rand -hex 32
```

### 2. Setup Environment
```bash
cd /path/to/freddy
cp .env.example .env
nano .env  # Edit and add your secrets
```

### 3. Run Setup Script
```bash
chmod +x scripts/setup-authentik.sh
./scripts/setup-authentik.sh
```

Or manually:
```bash
# Create directories
sudo mkdir -p /mnt/1tb/authentik/{postgres,redis}
sudo chown -R 1000:1000 /mnt/1tb/authentik

# Start services
docker compose up -d authentik-postgres authentik-redis
sleep 10

# Run migrations
docker compose run --rm authentik-server migrate

# Start Authentik
docker compose up -d authentik-server authentik-worker
```

## Common Commands

### View Logs
```bash
docker compose logs -f authentik-server
docker compose logs -f authentik-worker
docker compose logs -f authentik-postgres
```

### Restart Services
```bash
docker compose restart authentik-server authentik-worker
```

### Stop Services
```bash
docker compose stop authentik-server authentik-worker
```

### Check Health
```bash
docker compose ps | grep authentik
curl http://localhost:9000/-/health/live/
```

### Database Access
```bash
docker compose exec authentik-postgres psql -U authentik
```

### Backup Database
```bash
docker compose exec authentik-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql
```

### Restore Database
```bash
cat authentik-backup.sql | docker compose exec -T authentik-postgres psql -U authentik
```

## Admin Commands

### Create Admin User (if needed)
```bash
docker compose exec authentik-server ak create_admin_group
```

### Create Recovery Key
```bash
docker compose exec authentik-server ak create_recovery_key 10 akadmin
```

### Clear Cache
```bash
docker compose exec authentik-redis redis-cli FLUSHALL
```

## Troubleshooting

### Reset Everything
```bash
docker compose down authentik-server authentik-worker authentik-postgres authentik-redis
sudo rm -rf /mnt/1tb/authentik/*
./scripts/setup-authentik.sh
```

### Check Environment Variables
```bash
docker compose exec authentik-server env | grep AUTHENTIK
```

### Test Email Configuration
Navigate to: System > System Tasks > Test Email

### View Worker Tasks
```bash
docker compose logs -f authentik-worker | grep ERROR
```

## URLs

- **Web UI**: http://freddy:9000 or https://freddy:9443
- **API**: http://freddy:9000/api/v3/
- **Health Check**: http://freddy:9000/-/health/live/
- **Metrics**: http://freddy:9000/-/metrics/

## Environment Variables Required

```bash
AUTHENTIK_SECRET_KEY=<generate with openssl rand -hex 32>
AUTHENTIK_POSTGRES_PASSWORD=<secure password>
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_FROM=your-email@example.com
EMAIL_USERNAME=your-email@example.com
EMAIL_PASSWORD=<app-specific password>
```

## Next Steps After Setup

1. Access web UI at http://freddy:9000
2. Complete initial setup wizard
3. Create admin user
4. Enable MFA for admin
5. Configure LDAP provider (Task 4)
6. Configure OIDC providers (Task 5)
7. Set up Nginx reverse proxy (Task 3)
