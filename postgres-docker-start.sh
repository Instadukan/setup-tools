#!/bin/bash

# Check if the "local" network exists
if ! docker network inspect local &> /dev/null; then
  docker network create local
fi

# Run PostgreSQL for CryptoXpress
docker run --name postgresdb \
  -e POSTGRES_PASSWORD='toor' \
  -e POSTGRES_USER='pguser1' \
  -e POSTGRES_DB='pgdb1' \
  -v $(pwd)/storage/postgresdb:/var/lib/postgresql/data \
  -p 5432:5432 \
  --network local \
  --restart always \
  -d postgres:15-alpine

# Your DATABASE_URL would be:
# postgresql://pguser1:toor@localhost:5432/pgdb1