# Check if the "local" network exists
if ! docker network inspect local &> /dev/null; then
  # Create the "local" network if it doesn't exist
  docker network create local
fi

# Run the MySQL container and attach it to the "local" network
docker run --name mysql-db -e MYSQL_ROOT_PASSWORD='toor' -e MYSQL_DATABASE=first_db -v $(pwd)/storage/mysql-db:/var/lib/mysql  -p 3306:3306 --network local  --restart always -d mysql  --default-authentication-plugin=mysql_native_password