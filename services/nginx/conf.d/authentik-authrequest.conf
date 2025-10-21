# Authentik Forward Auth - Auth Request Configuration
# Include this in location blocks that require authentication
# Usage: include /etc/nginx/conf.d/authentik-authrequest.conf;

# Send authentication request to Authentik
auth_request /outpost.goauthentik.io/auth/nginx;

# Redirect to Authentik login if authentication fails
error_page 401 = @authentik_auth_redirect;

# Capture user information from auth response
auth_request_set $authentik_user $upstream_http_x_authentik_username;
auth_request_set $authentik_email $upstream_http_x_authentik_email;
auth_request_set $authentik_name $upstream_http_x_authentik_name;
auth_request_set $authentik_uid $upstream_http_x_authentik_uid;
auth_request_set $authentik_groups $upstream_http_x_authentik_groups;

# Forward user information to backend application
proxy_set_header X-Forwarded-User $authentik_user;
proxy_set_header X-Forwarded-Email $authentik_email;
proxy_set_header X-Forwarded-Preferred-Username $authentik_user;
proxy_set_header X-Authentik-Username $authentik_user;
proxy_set_header X-Authentik-Email $authentik_email;
proxy_set_header X-Authentik-Name $authentik_name;
proxy_set_header X-Authentik-Uid $authentik_uid;
proxy_set_header X-Authentik-Groups $authentik_groups;

# Remote user for basic auth compatibility
proxy_set_header Remote-User $authentik_user;
proxy_set_header Remote-Email $authentik_email;
