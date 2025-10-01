#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create Authelia database and user
    CREATE DATABASE authelia;
    CREATE USER authelia WITH ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE authelia TO authelia;
    
    -- Create Nextcloud database and user
    CREATE DATABASE nextcloud;
    CREATE USER nextcloud WITH ENCRYPTED PASSWORD '$NEXTCLOUD_DB_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;
    
    -- Create Photoprism database and user
    CREATE DATABASE photoprism;
    CREATE USER photoprism WITH ENCRYPTED PASSWORD '$PHOTOPRISM_DB_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE photoprism TO photoprism;
EOSQL
