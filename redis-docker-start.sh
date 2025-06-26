# Check if the "local" network exists
if ! docker network inspect local &> /dev/null; then
  # Create the "local" network if it doesn't exist
  docker network create local
fi
# Redis Setup
docker run -d -p 6379:6379 --name redis \
    -v $(pwd)/storage/redis:/data \
    --network local \
    redis redis-server \
    --appendonly yes \
    --requirepass toor