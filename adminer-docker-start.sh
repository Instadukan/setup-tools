# Check if the "local" network exists
if ! docker network inspect local &> /dev/null; then
  # Create the "local" network if it doesn't exist
  docker network create local
fi
docker run -d -p 8080:80 --network local  --restart always --name adminer -e UPLOAD=4096M dockette/adminer:full
