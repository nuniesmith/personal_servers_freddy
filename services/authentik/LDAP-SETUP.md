# Authentik LDAP Provider Setup Guide

This guide walks through creating and configuring an LDAP provider in Authentik for use with media servers (Emby, Jellyfin, Plex) and Nextcloud.

## Overview

The LDAP provider allows legacy applications that don't support OIDC to authenticate against Authentik using the standard LDAP protocol.

### What You'll Create
- **LDAP Application** in Authentik
- **LDAP Provider** with base DN `dc=7gram,dc=xyz`
- **LDAP Outpost** to expose LDAP on ports 389/636
- **Service Account** for LDAP bind operations

### Applications Using LDAP
- Emby (media server on SULLIVAN)
- Jellyfin (media server on SULLIVAN)
- Plex (media server on SULLIVAN - via plugin)
- Nextcloud (cloud storage on FREDDY)

## Prerequisites

- [ ] Authentik deployed and accessible at https://auth.7gram.xyz
- [ ] Admin access to Authentik web interface
- [ ] At least one user created (for testing)

## Step 1: Create LDAP Outpost

The outpost is what actually exposes the LDAP protocol.

### Via Web UI

1. **Navigate to Outposts**
   - Go to: **Applications** → **Outposts**

2. **Create New Outpost**
   - Click **Create**
   - **Name**: `LDAP Outpost`
   - **Type**: `LDAP`
   - **Integration**: `Local Docker connection` (uses /var/run/docker.sock)

3. **Configuration**
   ```yaml
   # Leave default unless you need custom ports
   authentik_host: https://auth.7gram.xyz
   log_level: info
   ```

4. **Save**

### Expected Result
A new Docker container will be created: `authentik-ldap-outpost`

### Verify Outpost

```bash
# Check container is running
docker ps | grep ldap

# Should see something like:
# authentik-ldap-outpost   Up   0.0.0.0:389->3389/tcp, 0.0.0.0:636->6636/tcp

# Check logs
docker logs authentik-ldap-outpost

# Should see:
# "Outpost started and connected to authentik"
```

## Step 2: Create LDAP Provider

### Via Web UI

1. **Navigate to Providers**
   - Go to: **Applications** → **Providers**

2. **Create Provider**
   - Click **Create**
   - **Type**: Select `LDAP Provider`

3. **Provider Configuration**

   **Basic Settings:**
   - **Name**: `LDAP Provider - 7gram`
   - **Authorization flow**: `default-provider-authorization-implicit-consent`

   **LDAP Settings:**
   - **Base DN**: `dc=7gram,dc=xyz`
   - **Search group**: Leave empty (all users accessible)
   - **Certificate**: `authentik Self-signed Certificate` (or your custom cert)
   - **TLS Server name**: `ldap.7gram.xyz` (optional)

   **Bind Settings:**
   - **Bind mode**: `Direct bind`
   - **Search mode**: `Search mode` (allows searching for users)

   **Advanced Settings:**
   - **UID start number**: `2000` (Unix UID numbering)
   - **GID start number**: `4000` (Unix GID numbering)
   - **LDAP Schema**: `OpenLDAP` (recommended for compatibility)

4. **Save**

### Configuration Explanation

- **Base DN** (`dc=7gram,dc=xyz`): Root of LDAP tree, matches your domain
- **Direct bind**: Users authenticate with their Authentik username
- **Search mode**: Allows apps to search for users by email/username
- **UID/GID numbers**: Used for Unix-style permissions

## Step 3: Create LDAP Application

### Via Web UI

1. **Navigate to Applications**
   - Go to: **Applications** → **Applications**

2. **Create Application**
   - Click **Create**
   - **Name**: `LDAP Access`
   - **Slug**: `ldap-access`
   - **Provider**: Select `LDAP Provider - 7gram` (created in Step 2)
   - **Launch URL**: Leave empty (backend service)
   - **Policy engine mode**: `any` (allow all authenticated users)

3. **Save**

## Step 4: Bind Outpost to Provider

### Via Web UI

1. **Navigate to Outposts**
   - Go to: **Applications** → **Outposts**

2. **Edit LDAP Outpost**
   - Click on `LDAP Outpost` (created in Step 1)
   - **Selected applications**: Add `LDAP Access`
   - **Save**

3. **Verify Connection**
   - Outpost status should show **Healthy** (green)
   - Last seen should be recent (< 1 minute ago)

## Step 5: Create Service Account (Optional but Recommended)

Some applications need a service account for LDAP bind operations.

### Via Web UI

1. **Navigate to Users**
   - Go to: **Directory** → **Users**

2. **Create User**
   - Click **Create**
   - **Username**: `ldapservice`
   - **Name**: `LDAP Service Account`
   - **Email**: `ldapservice@7gram.xyz`
   - **Password**: Generate strong password, store in password manager
   - **Active**: Yes
   - **Type**: `Internal service account`

3. **Save**

### Note Service Account Credentials

```
Bind DN: cn=ldapservice,ou=users,dc=7gram,dc=xyz
Password: <generated-password>
```

You'll use these when configuring applications.

## Step 6: Test LDAP Connection

### From FREDDY Server (where Authentik runs)

```bash
# Install LDAP utilities
sudo apt install ldap-utils

# Test anonymous bind (should fail if configured correctly)
ldapsearch -H ldap://localhost:389 -x -b "dc=7gram,dc=xyz"

# Test with service account
ldapsearch -H ldap://localhost:389 \
  -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" \
  -w '<service-account-password>' \
  -b "dc=7gram,dc=xyz" \
  "(objectClass=user)"

# Should return list of users in LDIF format
```

### From SULLIVAN Server (remote test)

```bash
# Install LDAP utilities
sudo apt install ldap-utils

# Test LDAP connection to FREDDY
ldapsearch -H ldap://freddy:389 \
  -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" \
  -w '<service-account-password>' \
  -b "dc=7gram,dc=xyz" \
  "(objectClass=user)"

# Test LDAPS (secure) connection
ldapsearch -H ldaps://freddy:636 \
  -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" \
  -w '<service-account-password>' \
  -b "dc=7gram,dc=xyz" \
  "(objectClass=user)"
```

### Expected Output

```ldif
# ldapservice, users, 7gram.xyz
dn: cn=ldapservice,ou=users,dc=7gram,dc=xyz
objectClass: user
cn: ldapservice
mail: ldapservice@7gram.xyz
uid: ldapservice

# admin, users, 7gram.xyz
dn: cn=admin,ou=users,dc=7gram,dc=xyz
objectClass: user
cn: admin
mail: admin@7gram.xyz
uid: admin
```

## Step 7: Configure LDAP in Docker Compose (Optional)

If you want LDAP exposed on non-standard ports or need custom configuration:

### Update docker-compose.yml

```yaml
services:
  authentik-ldap-outpost:
    image: ghcr.io/goauthentik/ldap:latest
    container_name: freddy_authentik-ldap-outpost
    restart: unless-stopped
    ports:
      - "389:3389"   # LDAP (plaintext - for internal use only)
      - "636:6636"   # LDAPS (TLS - recommended)
    environment:
      AUTHENTIK_HOST: https://auth.7gram.xyz
      AUTHENTIK_TOKEN: ${AUTHENTIK_LDAP_TOKEN}
      AUTHENTIK_INSECURE: "false"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - backend
```

**Note**: Authentik automatically creates the outpost container when you create an LDAP outpost in the UI. Only add this manually if you need custom configuration.

## LDAP Connection Details

### For Applications on FREDDY (same server as Authentik)

```
Server: localhost (or authentik-server)
Port: 389 (LDAP) or 636 (LDAPS)
Base DN: dc=7gram,dc=xyz
Bind DN: cn=ldapservice,ou=users,dc=7gram,dc=xyz
Bind Password: <service-account-password>
User DN: ou=users,dc=7gram,dc=xyz
User Object Class: user
User Filter: (objectClass=user)
Username Attribute: uid
Email Attribute: mail
Display Name Attribute: cn
```

### For Applications on SULLIVAN (remote server)

```
Server: freddy (Docker hostname) or <freddy-tailscale-ip>
Port: 389 (LDAP) or 636 (LDAPS - recommended)
Base DN: dc=7gram,dc=xyz
Bind DN: cn=ldapservice,ou=users,dc=7gram,dc=xyz
Bind Password: <service-account-password>
User DN: ou=users,dc=7gram,dc=xyz
User Object Class: user
User Filter: (objectClass=user)
Username Attribute: uid
Email Attribute: mail
Display Name Attribute: cn
```

### Security Recommendation

**Always use LDAPS (port 636) for remote connections!**

```bash
# Good: LDAPS with TLS
ldaps://freddy:636

# Bad: Plain LDAP over network (credentials sent in clear text)
ldap://freddy:389
```

## LDAP Schema Reference

### Common User Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `dn` | Distinguished Name | `cn=username,ou=users,dc=7gram,dc=xyz` |
| `uid` | Username | `john` |
| `cn` | Common Name | `John Doe` |
| `mail` | Email Address | `john@7gram.xyz` |
| `objectClass` | Object Type | `user` |
| `uidNumber` | Unix UID | `2001` |
| `gidNumber` | Unix GID | `4001` |
| `memberOf` | Group Memberships | `cn=admins,ou=groups,dc=7gram,dc=xyz` |

### Common Group Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `dn` | Distinguished Name | `cn=admins,ou=groups,dc=7gram,dc=xyz` |
| `cn` | Group Name | `admins` |
| `member` | Group Members | `cn=john,ou=users,dc=7gram,dc=xyz` |
| `objectClass` | Object Type | `group` |

## Troubleshooting

### LDAP Outpost Not Starting

**Check Docker socket permissions:**
```bash
ls -la /var/run/docker.sock
# Should be readable by docker group

# Check if authentik-server can access socket
docker exec authentik-server ls -la /var/run/docker.sock
```

**Check outpost logs:**
```bash
docker logs authentik-ldap-outpost
```

**Restart outpost:**
```bash
# Via Authentik UI
# Applications → Outposts → LDAP Outpost → Restart

# Or via Docker
docker restart authentik-ldap-outpost
```

### Cannot Connect from Remote Server

**Check ports are exposed:**
```bash
# On FREDDY
netstat -tulpn | grep -E '389|636'

# Should show:
# tcp6  0  0  :::389  :::*  LISTEN  <pid>/docker-proxy
# tcp6  0  0  :::636  :::*  LISTEN  <pid>/docker-proxy
```

**Test connectivity from remote:**
```bash
# From SULLIVAN
nc -zv freddy 389
nc -zv freddy 636
```

**Check firewall:**
```bash
# On FREDDY
sudo ufw status | grep -E '389|636'

# Allow LDAP ports if needed
sudo ufw allow 389/tcp comment 'LDAP'
sudo ufw allow 636/tcp comment 'LDAPS'
```

### LDAP Search Returns No Results

**Verify base DN:**
```bash
# Test with broader search
ldapsearch -H ldap://localhost:389 \
  -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" \
  -w '<password>' \
  -b "dc=7gram,dc=xyz" \
  "(objectClass=*)"
```

**Check user exists in Authentik:**
- Go to: **Directory** → **Users**
- Verify user is **Active**
- Verify user has **Email** set

**Check provider settings:**
- Go to: **Applications** → **Providers** → **LDAP Provider - 7gram**
- Verify **Base DN** matches: `dc=7gram,dc=xyz`
- Verify **Bind mode** is set correctly

### Authentication Fails

**Test direct bind:**
```bash
# Try binding as actual user (not service account)
ldapwhoami -H ldap://localhost:389 \
  -D "cn=username,ou=users,dc=7gram,dc=xyz" \
  -w '<user-password>'

# Should return: dn:cn=username,ou=users,dc=7gram,dc=xyz
```

**Check password is correct:**
- Reset password in Authentik UI
- Try again with new password

**Check authorization flow:**
- Go to: **Applications** → **Providers** → **LDAP Provider - 7gram**
- Verify **Authorization flow** is set
- Check **Policy bindings** aren't blocking access

### TLS/SSL Certificate Errors

**Check certificate in provider:**
```bash
# Test LDAPS connection
openssl s_client -connect localhost:636 -showcerts

# Should show certificate details
```

**Use self-signed cert (for testing):**
```bash
# Tell ldapsearch to ignore cert validation
LDAPTLS_REQCERT=never ldapsearch -H ldaps://localhost:636 \
  -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" \
  -w '<password>' \
  -b "dc=7gram,dc=xyz"
```

**For production, use valid certificate:**
- Go to: **System** → **Certificates**
- Upload your Let's Encrypt certificate
- Update LDAP provider to use it

## Security Best Practices

### 1. Use LDAPS for Remote Connections
```bash
# Good: Encrypted connection
ldaps://freddy:636

# Bad: Unencrypted connection (passwords in clear text)
ldap://freddy:389
```

### 2. Use Service Account (Not Admin)
- Create dedicated service account with minimal permissions
- Don't use admin account for LDAP binds
- Rotate service account password quarterly

### 3. Limit LDAP Access
```yaml
# Only expose LDAP to internal networks
# Don't expose ports 389/636 to internet
```

### 4. Monitor LDAP Access
```bash
# Check LDAP outpost logs regularly
docker logs authentik-ldap-outpost | grep -i error

# Monitor authentication attempts in Authentik
# Go to: Events → Logs
```

### 5. Use Search Groups
- Create groups for different access levels
- Set **Search group** in provider to limit visibility
- Example: Only show users in "media-users" group to media servers

## Next Steps

After LDAP provider is configured:

1. **Task 6**: Configure Emby LDAP authentication
2. **Task 7**: Configure Jellyfin LDAP authentication  
3. **Task 8**: Configure Nextcloud LDAP authentication
4. **Task 9**: Set up forward auth for *arr apps (alternative to LDAP)

## Quick Reference

### Service Account Credentials
```
Bind DN: cn=ldapservice,ou=users,dc=7gram,dc=xyz
Password: <stored-in-password-manager>
```

### LDAP Connection Settings
```
Server: freddy (or localhost on FREDDY)
LDAP Port: 389
LDAPS Port: 636 (recommended)
Base DN: dc=7gram,dc=xyz
User DN: ou=users,dc=7gram,dc=xyz
Username Attribute: uid
Email Attribute: mail
```

### Testing Commands
```bash
# Test LDAP connection
ldapsearch -H ldap://freddy:389 -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" -w '<password>' -b "dc=7gram,dc=xyz" "(objectClass=user)"

# Test LDAPS connection
ldapsearch -H ldaps://freddy:636 -D "cn=ldapservice,ou=users,dc=7gram,dc=xyz" -w '<password>' -b "dc=7gram,dc=xyz" "(objectClass=user)"

# Test user authentication
ldapwhoami -H ldap://freddy:389 -D "cn=username,ou=users,dc=7gram,dc=xyz" -w '<user-password>'
```

### Maintenance
```bash
# Restart LDAP outpost
docker restart authentik-ldap-outpost

# View outpost logs
docker logs -f authentik-ldap-outpost

# Check outpost status in UI
# Applications → Outposts → LDAP Outpost
```

---

**Status**: Ready to configure applications  
**Prerequisites**: Authentik deployed (Task 2)  
**Next**: Configure LDAP in media servers (Tasks 6-8)
