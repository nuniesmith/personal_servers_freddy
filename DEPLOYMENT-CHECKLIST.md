# Pre-Deployment Checklist for Authentik

Complete these steps before running Task 2 (Deploy and initialize Authentik).

## ✅ Completed Tasks

- [x] Task 1: Infrastructure setup in docker-compose.yml
- [x] Task 3: Nginx configuration files created

## 📋 Pre-Deployment Steps

### 1. Environment Configuration
- [ ] Copy `.env.example` to `.env` on FREDDY server
  ```bash
  cd /path/to/freddy
  cp .env.example .env
  ```

- [ ] Generate secret key and add to `.env`
  ```bash
  openssl rand -hex 32
  # Add to .env as AUTHENTIK_SECRET_KEY=<generated_value>
  ```

- [ ] Set database password in `.env`
  ```bash
  # Set AUTHENTIK_POSTGRES_PASSWORD=<secure_password>
  ```

- [ ] Configure email settings in `.env` (optional but recommended)
  ```bash
  EMAIL_HOST=smtp.gmail.com
  EMAIL_PORT=587
  EMAIL_FROM=your-email@example.com
  EMAIL_USERNAME=your-email@example.com
  EMAIL_PASSWORD=<app_specific_password>
  ```

### 2. DNS Configuration
- [ ] Create DNS record for auth.7gram.xyz
  - **Option A**: Tailscale MagicDNS (recommended)
    - Visit https://login.tailscale.com/admin/dns
    - Add split DNS for 7gram.xyz
  
  - **Option B**: Domain registrar
    - Add A record: auth.7gram.xyz → FREDDY's Tailscale IP
  
  - **Option C**: Local testing
    - Add to `/etc/hosts`: `<FREDDY_IP> auth.7gram.xyz`

- [ ] Verify DNS resolution
  ```bash
  nslookup auth.7gram.xyz
  # or
  dig auth.7gram.xyz
  ```

### 3. SSL Certificates
- [ ] Verify SSL certificates exist at `/opt/ssl/7gram.xyz/`
  ```bash
  ls -la /opt/ssl/7gram.xyz/
  # Should show: fullchain.pem and privkey.pem
  ```

- [ ] If certificates don't exist, generate them:
  ```bash
  # Use scripts/letsencrypt.sh or similar
  ./scripts/letsencrypt.sh
  ```

### 4. Storage Directories
- [ ] Create volume directories (auto-created by setup script, or manual):
  ```bash
  sudo mkdir -p /mnt/1tb/authentik/{postgres,redis}
  sudo chown -R 1000:1000 /mnt/1tb/authentik
  ```

### 5. Network Connectivity
- [ ] Verify Docker networks exist
  ```bash
  docker network ls | grep -E "frontend|backend|database"
  ```

- [ ] Test connectivity to FREDDY server
  ```bash
  ping freddy.7gram.xyz
  # or
  ping <FREDDY_TAILSCALE_IP>
  ```

### 6. Git Commit
- [ ] Commit infrastructure changes to git
  ```bash
  git add .
  git commit -m "feat: Add Authentik SSO infrastructure and Nginx config"
  git push
  ```

## 🚀 Ready to Deploy

Once all checkboxes above are complete, proceed with:

**Task 2: Deploy and initialize Authentik**
```bash
# Option 1: Use automated setup script
chmod +x scripts/setup-authentik.sh
./scripts/setup-authentik.sh

# Option 2: Manual deployment
docker compose up -d authentik-postgres authentik-redis
sleep 10
docker compose run --rm authentik-server migrate
docker compose up -d authentik-server authentik-worker
```

## 📍 After Deployment

- [ ] Access web UI: https://auth.7gram.xyz
- [ ] Complete initial setup wizard
- [ ] Create admin user
- [ ] Enable MFA for admin account
- [ ] Proceed to Task 4 (LDAP provider setup)
- [ ] Proceed to Task 5 (OIDC provider setup)

## 🆘 Troubleshooting

If deployment fails, check:
```bash
# Check service status
docker compose ps

# Check logs
docker compose logs authentik-server
docker compose logs authentik-postgres

# Verify environment variables
docker compose config | grep AUTHENTIK

# Test Nginx config
docker compose exec nginx nginx -t
```

## 📚 Reference Documents

- `services/authentik/README.md` - Comprehensive setup guide
- `services/authentik/QUICKREF.md` - Quick command reference
- `services/nginx/conf.d/AUTHENTIK-README.md` - Nginx configuration guide
- `scripts/setup-authentik.sh` - Automated setup script
- `scripts/dns-setup-guide.sh` - DNS configuration helper
