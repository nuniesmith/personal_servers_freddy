#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE authelia;
    CREATE USER authelia WITH ENCRYPTED PASSWORD 'authelia';
    GRANT ALL PRIVILEGES ON DATABASE authelia TO authelia;
EOSQL