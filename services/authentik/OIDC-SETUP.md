# Authentik OIDC/OAuth2 Providers Setup Guide

This guide covers creating OIDC (OpenID Connect) and OAuth2 providers in Authentik for modern applications that support these protocols.

## Overview

OIDC/OAuth2 is the preferred authentication method for modern applications. It provides:
- **Single Sign-On (SSO)**: Users log in once to access multiple apps
- **Secure**: Token-based authentication, no password sharing
- **Standards-based**: Industry standard protocol (OAuth 2.0 + OpenID Connect)

### Applications Using OIDC
- **Portainer** (Docker management on both servers)
- **Home Assistant** (smart home on FREDDY)
- **Wiki.js** (documentation on SULLIVAN)
- Future applications with OIDC support

## Prerequisites

- [ ] Authentik deployed at https://auth.7gram.xyz
- [ ] Admin access to Authentik web interface
- [ ] Applications installed and accessible
- [ ] DNS entries configured for all applications

## OIDC Concepts

### Key Terms

- **Provider**: Authentik (the authentication server)
- **Client**: The application requesting authentication (Portainer, Home Assistant, etc.)
- **Client ID**: Unique identifier for the application
- **Client Secret**: Password for the application to authenticate with Authentik
- **Redirect URI**: Where Authentik sends users after authentication
- **Scopes**: What information the app can request (email, profile, groups, etc.)

### Authentication Flow

```
1. User visits application (e.g., Portainer)
2. App redirects to Authentik login page
3. User authenticates with Authentik
4. Authentik redirects back to app with authorization code
5. App exchanges code for access token
6. App uses token to get user info from Authentik
7. User is logged into the application
```

## General Provider Setup Pattern

All OIDC providers follow this pattern:

1. **Create OAuth2/OIDC Provider** in Authentik
2. **Create Application** in Authentik
3. **Note Client ID and Secret**
4. **Configure Application** with Authentik details
5. **Test Authentication**

## Provider 1: Portainer

Portainer supports OAuth2 authentication for Docker management access.

### Create Provider in Authentik

1. **Navigate to Providers**
   - Go to: **Applications** → **Providers**
   - Click: **Create**

2. **Select Provider Type**
   - Type: **OAuth2/OpenID Provider**

3. **Configure Provider**
   ```
   Name:                    Portainer OAuth2
   Authorization flow:      default-provider-authorization-implicit-consent
   Protocol settings:       OpenID Connect
   ```

4. **Client Settings**
   ```
   Client type:             Confidential
   Client ID:               portainer
   Client Secret:           <click Generate> (save this!)
   ```

5. **Redirect URIs**
   ```
   https://portainer.7gram.xyz/
   https://portainer.7gram.xyz/auth
   ```

6. **Scopes**
   - Select: `openid`, `profile`, `email`, `groups`

7. **Advanced Settings** (Optional)
   ```
   Token validity:          hours=1
   Refresh token validity:  days=30
   ```

8. **Save**

### Create Application in Authentik

1. **Navigate to Applications**
   - Go to: **Applications** → **Applications**
   - Click: **Create**

2. **Configure Application**
   ```
   Name:           Portainer
   Slug:           portainer
   Provider:       Portainer OAuth2
   Launch URL:     https://portainer.7gram.xyz
   ```

3. **Save**

### Note Credentials

Save these for Portainer configuration:

```bash
# Portainer OIDC Settings
Authorization URL:  https://auth.7gram.xyz/application/o/authorize/
Token URL:          https://auth.7gram.xyz/application/o/token/
User Info URL:      https://auth.7gram.xyz/application/o/userinfo/
Logout URL:         https://auth.7gram.xyz/application/o/portainer/end-session/

Client ID:          portainer
Client Secret:      <generated-secret-from-step-4>

Scopes:             openid profile email groups
Redirect URI:       https://portainer.7gram.xyz/
```

## Provider 2: Home Assistant

Home Assistant has native Authentik integration.

### Create Provider in Authentik

1. **Navigate to Providers**
   - Go to: **Applications** → **Providers** → **Create**

2. **Configure Provider**
   ```
   Name:                    Home Assistant OAuth2
   Type:                    OAuth2/OpenID Provider
   Authorization flow:      default-provider-authorization-implicit-consent
   Client type:             Confidential
   Client ID:               homeassistant
   Client Secret:           <generate and save>
   ```

3. **Redirect URIs**
   ```
   https://home.7gram.xyz/auth/external/callback
   ```

4. **Scopes**
   - Select: `openid`, `profile`, `email`

5. **Save**

### Create Application in Authentik

1. **Navigate to Applications**
   - Go: **Applications** → **Applications** → **Create**

2. **Configure**
   ```
   Name:           Home Assistant
   Slug:           homeassistant
   Provider:       Home Assistant OAuth2
   Launch URL:     https://home.7gram.xyz
   ```

3. **Save**

### Note Credentials

```bash
# Home Assistant OIDC Settings
Issuer:             https://auth.7gram.xyz/application/o/homeassistant/
Client ID:          homeassistant
Client Secret:      <generated-secret>
```

## Provider 3: Wiki.js

Wiki.js on SULLIVAN for documentation.

### Create Provider in Authentik

1. **Navigate to Providers**
   - Go to: **Applications** → **Providers** → **Create**

2. **Configure Provider**
   ```
   Name:                    Wiki.js OAuth2
   Type:                    OAuth2/OpenID Provider
   Authorization flow:      default-provider-authorization-implicit-consent
   Client type:             Confidential
   Client ID:               wikijs
   Client Secret:           <generate and save>
   ```

3. **Redirect URIs**
   ```
   https://wiki.7gram.xyz/login/callback
   ```

4. **Scopes**
   - Select: `openid`, `profile`, `email`

5. **Property Mappings** (Important for Wiki.js)
   - Add: `authentik default OAuth Mapping: OpenID 'email'`
   - Add: `authentik default OAuth Mapping: OpenID 'profile'`
   - Add: `authentik default OAuth Mapping: OpenID 'openid'`

6. **Save**

### Create Application in Authentik

1. **Navigate to Applications**
   - Go: **Applications** → **Applications** → **Create**

2. **Configure**
   ```
   Name:           Wiki.js
   Slug:           wikijs
   Provider:       Wiki.js OAuth2
   Launch URL:     https://wiki.7gram.xyz
   ```

3. **Save**

### Note Credentials

```bash
# Wiki.js OIDC Settings
Authorization URL:  https://auth.7gram.xyz/application/o/authorize/
Token URL:          https://auth.7gram.xyz/application/o/token/
User Info URL:      https://auth.7gram.xyz/application/o/userinfo/
Logout URL:         https://auth.7gram.xyz/application/o/wikijs/end-session/

Client ID:          wikijs
Client Secret:      <generated-secret>

Scopes:             openid profile email
```

## OIDC Endpoints Reference

Authentik provides standard OIDC endpoints. For any application with slug `<slug>`:

```bash
# Well-known Configuration (auto-discovery)
https://auth.7gram.xyz/application/o/<slug>/.well-known/openid-configuration

# Authorization Endpoint
https://auth.7gram.xyz/application/o/authorize/

# Token Endpoint
https://auth.7gram.xyz/application/o/token/

# User Info Endpoint
https://auth.7gram.xyz/application/o/userinfo/

# Logout Endpoint
https://auth.7gram.xyz/application/o/<slug>/end-session/

# JWKS (JSON Web Key Set)
https://auth.7gram.xyz/application/o/<slug>/jwks/
```

## Scopes Explanation

| Scope | Description | Returns |
|-------|-------------|---------|
| `openid` | Required for OIDC | Subject identifier (user ID) |
| `profile` | User profile info | Name, username, preferred_username |
| `email` | User email address | email, email_verified |
| `groups` | User group memberships | groups (array of group names) |
| `offline_access` | Refresh tokens | Allows refresh without re-authentication |

## Testing OIDC Configuration

### Test with curl

```bash
# 1. Get authorization URL (paste in browser)
echo "https://auth.7gram.xyz/application/o/authorize/?client_id=portainer&redirect_uri=https://portainer.7gram.xyz/&response_type=code&scope=openid%20profile%20email"

# 2. After login, you'll get redirected with a code
# Extract code from URL: https://portainer.7gram.xyz/?code=<CODE>

# 3. Exchange code for token
curl -X POST https://auth.7gram.xyz/application/o/token/ \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=portainer" \
  -d "client_secret=<CLIENT_SECRET>" \
  -d "code=<CODE>" \
  -d "redirect_uri=https://portainer.7gram.xyz/"

# 4. Use access_token to get user info
curl -H "Authorization: Bearer <ACCESS_TOKEN>" \
  https://auth.7gram.xyz/application/o/userinfo/
```

### Test with Browser

1. Visit application URL (e.g., https://portainer.7gram.xyz)
2. Click OAuth/SSO login button
3. Should redirect to Authentik
4. Login with Authentik credentials
5. Should redirect back to application (logged in)

## Advanced Configuration

### Custom Property Mappings

To add custom claims to tokens:

1. **Navigate to Property Mappings**
   - Go: **Customization** → **Property Mappings**
   - Click: **Create**

2. **Create Scope Mapping**
   ```python
   # Example: Add custom "role" claim
   return {
       "role": request.user.attributes.get("role", "user")
   }
   ```

3. **Attach to Provider**
   - Edit provider
   - Add custom mapping to **Property mappings**

### Group-Based Access Control

Limit which users can access an application:

1. **Create Group in Authentik**
   - Go: **Directory** → **Groups** → **Create**
   - Name: `portainer-users`

2. **Add Users to Group**
   - Edit group
   - Add users who should have access

3. **Create Policy**
   - Go: **Policies** → **Create** → **Expression Policy**
   - Name: `Portainer Access Policy`
   - Expression:
     ```python
     return ak_is_group_member(request.user, name="portainer-users")
     ```

4. **Bind Policy to Application**
   - Edit application
   - Go to: **Policy / Group / User Bindings**
   - Add policy binding

### Auto-Create Users in Applications

Some applications can auto-create users on first OIDC login:

- **Portainer**: Enable "Automatic user provisioning"
- **Wiki.js**: Enable "Allow self-registration"
- **Home Assistant**: Create user manually first, then link OIDC

## Security Best Practices

### Use Confidential Clients

Always use "Confidential" client type for server-side apps:
```
✓ Confidential: Client secret required (secure)
✗ Public: No client secret (insecure for server apps)
```

### Restrict Redirect URIs

Only allow exact redirect URIs:
```
✓ Good:  https://portainer.7gram.xyz/auth
✗ Bad:   https://*.7gram.xyz/* (wildcards are dangerous)
```

### Rotate Client Secrets

Regularly rotate secrets (quarterly):

1. Edit provider in Authentik
2. Generate new client secret
3. Update application configuration
4. Test authentication
5. Delete old secret

### Monitor Authentication

Check Authentik logs regularly:

- Go to: **Events** → **Logs**
- Filter by: Application name
- Look for: Failed logins, suspicious activity

### Use HTTPS Only

Never use OIDC over HTTP:
```
✓ Good:  https://auth.7gram.xyz (encrypted)
✗ Bad:   http://auth.7gram.xyz (credentials exposed)
```

## Troubleshooting

### "Invalid redirect_uri"

**Problem**: Redirect URI in app doesn't match Authentik config

**Solution**:
1. Check exact redirect URI in application
2. Update provider in Authentik to match exactly
3. No trailing slashes unless app requires them

### "Invalid client_id or client_secret"

**Problem**: Credentials don't match

**Solution**:
1. Verify client_id matches slug in Authentik
2. Re-generate client secret in Authentik
3. Update application with new secret
4. Restart application

### "User not found" after login

**Problem**: Application can't find user by email/username

**Solution**:
1. Check scopes include `profile` and `email`
2. Verify user has email set in Authentik
3. Check application's user attribute mapping
4. Enable auto-user-creation in application if available

### "Token expired"

**Problem**: Access token validity too short

**Solution**:
1. Edit provider in Authentik
2. Increase **Token validity** (e.g., hours=8)
3. Enable **Refresh tokens** (offline_access scope)
4. Save and test

### Application shows "Authorization failed"

**Check Authentik logs**:
```bash
# On FREDDY
docker compose logs authentik-server | grep -i error
```

**Common causes**:
- User not authorized (check policies)
- Missing scopes (add required scopes to provider)
- Clock skew (sync system time)

## Next Steps

After OIDC providers are configured:

1. **Task 10**: Configure OIDC in Portainer and Home Assistant
2. Configure Wiki.js authentication (separate guide)
3. Test SSO flow with real users
4. Set up group-based access control
5. Document client credentials securely

## Quick Reference

### Provider Creation Checklist

For each application:
- [ ] Create OAuth2/OIDC provider
- [ ] Set client type: Confidential
- [ ] Generate and save client secret
- [ ] Configure redirect URIs
- [ ] Select scopes (openid, profile, email, groups)
- [ ] Create application
- [ ] Link provider to application
- [ ] Configure application with Authentik details
- [ ] Test authentication flow

### Common OIDC Settings

```yaml
# For most applications
Authorization Flow:   default-provider-authorization-implicit-consent
Client Type:          Confidential
Scopes:               openid, profile, email
Token Validity:       hours=1
Refresh Validity:     days=30

# Endpoints (replace <slug> with app slug)
Issuer:               https://auth.7gram.xyz/application/o/<slug>/
Authorization URL:    https://auth.7gram.xyz/application/o/authorize/
Token URL:            https://auth.7gram.xyz/application/o/token/
User Info URL:        https://auth.7gram.xyz/application/o/userinfo/
JWKS URL:             https://auth.7gram.xyz/application/o/<slug>/jwks/
```

### Credentials Template

Save this for each application:

```bash
Application:        <app-name>
Slug:               <slug>
Client ID:          <slug>
Client Secret:      <generated-secret>
Redirect URI:       https://<app>.7gram.xyz/<callback-path>
Scopes:             openid profile email [groups]
Issuer:             https://auth.7gram.xyz/application/o/<slug>/
```

---

**Status**: Ready to configure applications  
**Prerequisites**: Authentik deployed (Task 2)  
**Next**: Configure OIDC in applications (Task 10)
