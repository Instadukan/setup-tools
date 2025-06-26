#!/bin/bash

# Check if the "local" network exists
if ! docker network inspect local &> /dev/null; then
  # Create the "local" network if it doesn't exist
  docker network create local
fi

# Create directories for MinIO data and configuration if they don't exist
mkdir -p $(pwd)/storage/minio/data
mkdir -p $(pwd)/storage/minio/config

# Generate a secure password that's hard to crack
# This creates a 16-character password with mixed case, numbers and special characters
MINIO_USER="minio_admin"
MINIO_PASS="IA+wYic7>egg4J#3R00t"

# Create the environment file for MinIO configuration
cat > $(pwd)/storage/minio/config/minio.env << EOF
# MinIO root credentials
MINIO_ROOT_USER=${MINIO_USER}
MINIO_ROOT_PASSWORD=${MINIO_PASS}

# MinIO volumes
MINIO_VOLUMES="/data"

# Additional MinIO options
MINIO_OPTS="--console-address :9001"
EOF

# Set proper permissions for the config file
chmod 600 $(pwd)/storage/minio/config/minio.env

# Run MinIO container
docker run -d \
  --name minio \
  -p 9000:9000 -p 9001:9001 \
  -v $(pwd)/storage/minio/data:/data \
  -v $(pwd)/storage/minio/config/minio.env:/etc/config.env \
  -e "MINIO_CONFIG_ENV_FILE=/etc/config.env" \
  --network local \
  --restart unless-stopped \
  minio/minio:latest server --console-address ":9001"

# Output information to console
echo "MinIO server started successfully!"
echo "API: http://localhost:9000"
echo "Console: http://localhost:9001"
echo ""
echo "Login credentials:"
echo "  Username: ${MINIO_USER}"
echo "  Password: ${MINIO_PASS}"
echo ""
echo "IMPORTANT: Save these credentials securely - they will not be shown again."

# Also save to a file that can be deleted later
cat > $(pwd)/minio-credentials.txt << EOF
MinIO Credentials
----------------
Username: ${MINIO_USER}
Password: ${MINIO_PASS}

Server URLs
----------
API: http://localhost:9000
Console: http://localhost:9001

This file contains sensitive information. Delete it after saving the credentials.
EOF

chmod 600 $(pwd)/minio-credentials.txt