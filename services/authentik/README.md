# Authentik SSO Configuration

This directory contains the configuration and data for Authentik SSO.

## Directory Structure

```
authentik/
├── media/              # User-uploaded media (avatars, etc.) - bind mounted
├── custom-templates/   # Custom email/login templates - bind mounted
├── certs/             # SSL certificates for outposts - bind mounted
└── README.md          # This file
```

## Data Storage Locations

- **Postgres Database**: `/mnt/1tb/authentik/postgres` (volume mount)
- **Redis Cache**: `/mnt/1tb/authentik/redis` (volume mount)
- **Media Files**: `./services/authentik/media` (bind mount - for git)
- **Custom Templates**: `./services/authentik/custom-templates` (bind mount - for git)
- **Certificates**: `./services/authentik/certs` (bind mount - for git)

## Initial Setup

1. **Generate Secret Key**:
   ```bash
   openssl rand -hex 32
   ```
   Add this to your `.env` file as `AUTHENTIK_SECRET_KEY`

2. **Create .env file**:
   ```bash
   cp .env.example .env
   # Edit .env and fill in all AUTHENTIK_* variables
   ```

3. **Create volume directories**:
   ```bash
   sudo mkdir -p /mnt/1tb/authentik/{postgres,redis}
   sudo chown -R 1000:1000 /mnt/1tb/authentik
   ```

4. **Start services**:
   ```bash
   docker compose up -d authentik-postgres authentik-redis authentik-server authentik-worker
   ```

5. **Run initial migrations**:
   ```bash
   docker compose run --rm authentik-server migrate
   ```

6. **Access Web UI**:
   - HTTP: `http://freddy:9000`
   - HTTPS: `https://freddy:9443` (self-signed cert initially)
   - After Nginx setup: `https://auth.7gram.xyz`

## Configuration

### LDAP Provider Setup
1. Navigate to **Applications > Providers** in the web UI
2. Create a new **LDAP Provider**
3. Configure base DN: `dc=7gram,dc=xyz`
4. Set bind mode (Direct or Anonymous)
5. Map attributes: `uid`, `cn`, `mail`
6. Create/assign an outpost for LDAP exposure

### OIDC/OAuth2 Provider Setup
1. Navigate to **Applications > Providers**
2. Create new **OAuth2/OpenID Provider**
3. Generate client ID and secret
4. Configure redirect URIs for your apps
5. Set token validity periods

### Forward Auth with Nginx
Forward auth snippets are in `/services/nginx/conf.d/`:
- `authentik-location.conf` - Outpost endpoint proxy
- `authentik-authrequest.conf` - Auth request configuration

## Migrating from Authelia

1. Export Authelia users/groups
2. Import into Authentik via web UI or API
3. Update Nginx configs to use Authentik endpoints
4. Test authentication thoroughly
5. Disable Authelia services
6. Update Tailscale ACLs if needed

## Maintenance

### Backup
```bash
# Backup postgres database
docker compose exec authentik-postgres pg_dump -U authentik authentik > authentik-backup.sql

# Backup media and templates (already in git)
tar -czf authentik-config-backup.tar.gz services/authentik/
```

### Update
```bash
docker compose pull authentik-server authentik-worker
docker compose up -d authentik-server authentik-worker
```

## Troubleshooting

### Check logs
```bash
docker compose logs -f authentik-server
docker compose logs -f authentik-worker
```

### Reset admin password
```bash
docker compose exec authentik-server ak create_admin_group
docker compose exec authentik-server ak create_recovery_key 10 akadmin
```

### Database issues
```bash
docker compose exec authentik-postgres psql -U authentik
```

## Security Notes

- Never commit `.env` file (contains secrets)
- Rotate `AUTHENTIK_SECRET_KEY` periodically
- Use strong passwords for database
- Enable MFA for admin accounts
- Review logs regularly for suspicious activity

## Resources

- [Official Documentation](https://docs.goauthentik.io/)
- [Integration Guides](https://integrations.goauthentik.io/)
- [Community Forum](https://github.com/goauthentik/authentik/discussions)
