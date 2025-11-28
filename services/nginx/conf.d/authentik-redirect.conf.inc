# Authentik Forward Auth - Redirect Handler
# Include this in server blocks using forward auth
# Usage: include /etc/nginx/conf.d/authentik-redirect.conf;

location @authentik_auth_redirect {
    # Redirect to Authentik login page with return URL
    return 302 https://auth.7gram.xyz/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
}
