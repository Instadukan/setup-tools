# Check if the "local" network exists
if ! docker network inspect local &> /dev/null; then
  # Create the "local" network if it doesn't exist
  docker network create local
fi
docker run -d -p 27017-27019:27017-27019 --name mongodb \
    -e MONGO_INITDB_DATABASE=instadukan \
    -e MONGO_INITDB_ROOT_USERNAME=root \
    -e MONGO_INITDB_ROOT_PASSWORD=toor \
    -v $(pwd)/storage/mongodb:/data/db \
    -v $(pwd)/init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js:ro \
    --network local \
    mongo