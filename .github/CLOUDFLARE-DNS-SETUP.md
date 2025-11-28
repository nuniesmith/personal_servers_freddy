# Cloudflare DNS Auto-Update

This GitHub Actions workflow automatically updates Cloudflare DNS records to point to your server's IP address.

## Setup Instructions

### 1. Get Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to **My Profile** → **API Tokens**
3. Click **Create Token**
4. Use the **Edit zone DNS** template or create a custom token with:
   - **Permissions:**
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - **Zone Resources:**
     - Include → Specific zone → `7gram.xyz`
5. Copy the generated API token (you won't see it again!)

### 2. Get Cloudflare Zone ID

1. Go to your [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select your domain: `7gram.xyz`
3. Scroll down on the Overview page
4. Copy the **Zone ID** from the right sidebar (under "API")

### 3. Add GitHub Secrets

Add these secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

   | Secret Name | Description | Example |
   |------------|-------------|---------|
   | `CLOUDFLARE_API_TOKEN` | Your Cloudflare API token | `AbCdEf123456...` |
   | `CLOUDFLARE_ZONE_ID` | Your zone ID for 7gram.xyz | `a1b2c3d4e5f6...` |
   | `DNS_TARGET_IP` | Your server's public IP address | `203.0.113.42` |

### 4. Test the Workflow

#### Manual Trigger

1. Go to **Actions** → **Update Cloudflare DNS Records**
2. Click **Run workflow**
3. Optionally enter a specific IP address (overrides the secret)
4. Click **Run workflow**

#### Scheduled Updates

The workflow runs automatically every 6 hours to keep DNS records updated.

## DNS Records Managed

The workflow updates these DNS records:

### Core Services
- `7gram.xyz` (root domain)
- `*.7gram.xyz` (wildcard)
- `auth.7gram.xyz` (Authentik SSO)

### Storage & Photos
- `nc.7gram.xyz` (Nextcloud)
- `photo.7gram.xyz` (PhotoPrism)

### Home & Productivity
- `home.7gram.xyz` (Home Assistant)
- `grocy.7gram.xyz` (Household Management)
- `mealie.7gram.xyz` (Recipe Manager)
- `wiki.7gram.xyz` (Wiki)
- `duplicati.7gram.xyz` (Backups)

### Media Services
- `jellyfin.7gram.xyz`
- `emby.7gram.xyz`
- `plex.7gram.xyz`

### Download Automation
- `sonarr.7gram.xyz`
- `radarr.7gram.xyz`
- `lidarr.7gram.xyz`
- `jackett.7gram.xyz`
- `qbittorrent.7gram.xyz`
- `yt.7gram.xyz` (YT-DLP)
- `filebot.7gram.xyz`
- `calibre.7gram.xyz`

### Sync Services
- `sync-freddy.7gram.xyz`
- `sync-sullivan.7gram.xyz`
- `sync-oryx.7gram.xyz`
- `sync-desktop.7gram.xyz`

### Trading Bots (NEW)
- `octobot-spot.7gram.xyz`
- `octobot-futures.7gram.xyz`

## How It Works

1. **Trigger**: Runs on schedule (every 6 hours) or manual trigger
2. **IP Detection**: Uses `DNS_TARGET_IP` secret or manual input
3. **Validation**: Validates IP address format
4. **Update/Create**: For each DNS record:
   - Checks if record exists
   - Creates new A record if it doesn't exist
   - Updates existing record if it does
5. **Verification**: Tests DNS propagation using Cloudflare DNS
6. **Summary**: Generates a detailed summary of changes

## Modifying DNS Records

To add or remove DNS records, edit the workflow file:

```yaml
env:
  DNS_RECORDS: >-
    your-subdomain.7gram.xyz
    another-subdomain.7gram.xyz
```

## Troubleshooting

### Invalid API Token
- Verify the token has correct permissions
- Ensure it's for the correct zone

### Zone ID Not Found
- Double-check the Zone ID from Cloudflare dashboard
- Make sure it's for `7gram.xyz`

### DNS Not Updating
- Check workflow logs in GitHub Actions
- Verify IP address format is correct
- Ensure Cloudflare account is active

### Rate Limiting
- The workflow includes 1-second delays between updates
- If you have many records, consider splitting into batches

## Security Notes

- ✅ API token is stored as a GitHub secret (encrypted)
- ✅ Token permissions are limited to DNS editing only
- ✅ DNS records are not proxied through Cloudflare (direct to IP)
- ✅ TTL set to auto (1) for fastest updates

## Manual DNS Update (Alternative)

If you prefer to update DNS manually without GitHub Actions:

```bash
# Set your variables
export CF_API_TOKEN="your_token_here"
export CF_ZONE_ID="your_zone_id_here"
export TARGET_IP="your_ip_here"

# Update a single record
curl -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/{record_id}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"subdomain.7gram.xyz\",\"content\":\"${TARGET_IP}\",\"ttl\":1,\"proxied\":false}"
```

## Links

- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [DNS Record Types](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/)
