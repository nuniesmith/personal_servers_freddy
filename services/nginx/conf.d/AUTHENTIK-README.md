# Nginx Configuration for Authentik

This directory contains the Nginx reverse proxy configuration for Authentik SSO.

## Files Created

### Main Configuration
- **`authentik.conf`** - Main reverse proxy config for Authentik web UI (auth.7gram.xyz)

### Forward Auth Snippets
- **`authentik-location.conf`** - Defines the `/outpost.goauthentik.io` endpoint
- **`authentik-authrequest.conf`** - Auth request and header forwarding logic
- **`authentik-redirect.conf`** - Handles redirect to login page on 401

### Example
- **`sonarr.conf.example`** - Example showing how to protect Sonarr with Authentik forward auth

## DNS Configuration Required

Add the following DNS record to your domain provider or local DNS:

```
Type: A or CNAME
Name: auth.7gram.xyz
Value: <FREDDY_TAILSCALE_IP> or freddy.7gram.xyz
TTL: 300 (or your preference)
```

For Tailscale MagicDNS, you may need to add this to your Tailscale admin console or use the Tailscale IP directly.

## How to Use Forward Auth

To protect any application with Authentik SSO, add these three includes to your server block:

```nginx
server {
    listen 443 ssl http2;
    server_name myapp.7gram.xyz;

    # 1. Include location block (adds /outpost.goauthentik.io endpoint)
    include /etc/nginx/conf.d/authentik-location.conf;
    
    # 2. Include redirect handler (handles login redirects)
    include /etc/nginx/conf.d/authentik-redirect.conf;

    location / {
        # 3. Include auth request (requires authentication)
        include /etc/nginx/conf.d/authentik-authrequest.conf;
        
        # Your normal proxy_pass configuration
        proxy_pass http://your-app:port;
        # ... rest of your config
    }
}
```

## Services That Need Forward Auth

After Authentik is deployed and configured (Tasks 4-5), update these configs:

### SULLIVAN Media Apps (Task 8)
- [ ] `sonarr.conf` - TV show management
- [ ] `radarr.conf` - Movie management
- [ ] `lidarr.conf` - Music management
- [ ] `qbittorrent.conf` - Torrent client
- [ ] `jackett.conf` - Indexer proxy

### FREDDY Services
- [ ] `photo.conf` - PhotoPrism (if desired)
- [ ] `syncthing.conf` - File sync (if desired)
- [ ] `audiobookshelf.conf` - Audiobook server

### Services with Native OIDC/LDAP
These don't need forward auth, configure directly in the app:
- Home Assistant (OIDC - Task 10)
- Portainer (OIDC - Task 9)
- Nextcloud (LDAP/OIDC - Task 7)
- Emby/Jellyfin (LDAP - Task 6)

## API Endpoints

Some apps need their API endpoints accessible without auth for automation:

```nginx
# Allow API access without auth
location /api {
    proxy_pass http://your-app:port;
    # No authentik-authrequest.conf include here
}

# Protect web UI
location / {
    include /etc/nginx/conf.d/authentik-authrequest.conf;
    proxy_pass http://your-app:port;
}
```

## Testing Forward Auth

1. **Start Nginx**:
   ```bash
   docker compose restart nginx
   ```

2. **Check Nginx logs**:
   ```bash
   docker compose logs -f nginx
   ```

3. **Test unauthenticated access**:
   ```bash
   curl -I https://sonarr.7gram.xyz
   # Should return 302 redirect to auth.7gram.xyz
   ```

4. **Test in browser**:
   - Visit https://sonarr.7gram.xyz
   - Should redirect to Authentik login
   - After login, should redirect back to Sonarr

## Troubleshooting

### 502 Bad Gateway
- Check if Authentik services are running: `docker compose ps`
- Check Authentik logs: `docker compose logs authentik-server`

### Redirect loop
- Verify Authentik application is configured with correct redirect URI
- Check that forward auth headers are set correctly

### Headers not forwarding
- Check `authentik-authrequest.conf` for correct variable names
- View response headers in browser DevTools

### SSL certificate issues
- Ensure `/opt/ssl/7gram.xyz` contains valid certs
- Check cert permissions: `ls -la /opt/ssl/7gram.xyz`

## Security Notes

- Forward auth protects the entire application UI
- API endpoints can be excluded for automation
- User information is passed via headers to backend apps
- Session is managed by Authentik cookies
- Logout must be done through Authentik (https://auth.7gram.xyz)

## Next Steps

1. Complete Task 2 (Deploy Authentik)
2. Complete Task 4 (Set up LDAP provider)
3. Complete Task 5 (Set up OIDC providers)
4. Complete Task 8 (Apply forward auth to *arr apps)
5. Test authentication flow
6. Migrate from Authelia (Task 18)
