# Authentik Forward Auth - Location Block
# Include this in server blocks to enable the /outpost.goauthentik.io endpoint
# Usage: include /etc/nginx/conf.d/authentik-location.conf;

location /outpost.goauthentik.io {
    internal;
    proxy_pass http://authentik-server:9000/outpost.goauthentik.io;
    proxy_http_version 1.1;
    
    # Forward original request information
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Forwarded-Method $request_method;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Uri $request_uri;
    proxy_set_header X-Forwarded-For $remote_addr;
    
    # Disable buffering
    proxy_buffering off;
    proxy_request_buffering off;
    
    # Increase buffer sizes for auth responses
    proxy_buffer_size 4k;
    proxy_buffers 4 4k;
    
    # Timeouts
    proxy_connect_timeout 10s;
    proxy_send_timeout 10s;
    proxy_read_timeout 10s;
}
