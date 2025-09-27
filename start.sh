#!/bin/bash

# Install ollama if not present
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Start ollama instances on different ports
OLLAMA_HOST=127.0.0.1:11434 ollama serve &
OLLAMA_HOST=127.0.0.1:11435 ollama serve &
OLLAMA_HOST=127.0.0.1:11436 ollama serve &
OLLAMA_HOST=127.0.0.1:11437 ollama serve &

sleep 5

# Pull model on all instances
OLLAMA_HOST=127.0.0.1:11434 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11435 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11436 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11437 ollama pull nomic-embed-text &

wait

# List pulled models on all instances
OLLAMA_HOST=127.0.0.1:11434 ollama list
OLLAMA_HOST=127.0.0.1:11435 ollama list
OLLAMA_HOST=127.0.0.1:11436 ollama list
OLLAMA_HOST=127.0.0.1:11437 ollama list


# Use curl to verify each instance is running and load the models on each insstance by sending a test request
curl -k -X POST http://localhost:11434/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11434"
  }'
curl -k -X POST http://localhost:11435/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11435"
  }'
curl -k -X POST http://localhost:11436/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11436"
  }'
curl -k -X POST http://localhost:11437/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11437"
  }'



# Start nginx and SQL Server
docker-compose up --build -d


docker exec -it -u 0 sql-server /bin/bash

apt-get update && apt-get install curl -y 

curl -k -X POST https://host.docker.internal:443/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for load balancer"
  }'


curl -k -X POST https://nginx-lb:443/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for load balancer"
  }' -vvvv



curl -k -X POST https://host.docker.internal:444/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for load balancer"
  }'


curl -k -X POST https://nginx-lb:444/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for load balancer"
  }' -vvvv


openssl  s_client -connect nginx-lb:443 -showcerts 



echo "Started 4 ollama instances, nginx load balancer, and SQL Server 2025"


docker cp /Users/aen/Downloads/StackOverflow2013_201809117/StackOverflow2013_1.mdf sql-server:/var/opt/mssql/data/
docker cp /Users/aen/Downloads/StackOverflow2013_201809117/StackOverflow2013_2.ndf sql-server:/var/opt/mssql/data/
docker cp /Users/aen/Downloads/StackOverflow2013_201809117/StackOverflow2013_3.ndf sql-server:/var/opt/mssql/data/
docker cp /Users/aen/Downloads/StackOverflow2013_201809117/StackOverflow2013_4.ndf sql-server:/var/opt/mssql/data/
docker cp /Users/aen/Downloads/StackOverflow2013_201809117/StackOverflow2013_log.ldf sql-server:/var/opt/mssql/data/

docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_1.mdf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_2.ndf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_3.ndf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_4.ndf
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/StackOverflow2013_log.ldf


# Stop ollama instances
pkill -f "ollama serve"


echo "Stopped ollama instances"


# remove all docker resources, including the data volumes
# docker compose down -v
