# Nextcloud Ops Notes

## Updating trusted domains

Nextcloud keeps its runtime configuration in the mounted volume `/mnt/1tb/nextcloud/config`. If you add a new hostname (for example `nc.7gram.xyz`), update the `trusted_domains` array so requests are accepted through the reverse proxy:

1. Enter the stack directory for this compose project.
2. Run the built-in `occ` helper via docker:

```
docker compose exec -T nextcloud occ config:system:get trusted_domains
# identify the next available integer index (0, 1, 2, ...)
docker compose exec -T nextcloud occ config:system:set trusted_domains <INDEX> --value="nc.7gram.xyz"
```

You can re-run `config:system:get` afterwards to confirm the hostname is present. Nextcloud reads this setting instantly—no container restart required.

Alternatively, edit the file `<volume>/nextcloud/config/config.php` directly and add the hostname to the `trusted_domains` array, then reload nginx.
