# Ollama Load Balanced SQL

Simple setup with 4 ollama instances, nginx load balancer, and SQL Server 2025 RC1 with vector support.

## Quick Start

```bash
./start.sh
```

This will:
- Install ollama if needed
- Start 4 ollama instances on ports 11434-11437
- Pull nomic-embed-text model
- Start nginx load balancer in Docker
- Start SQL Server 2025 in Docker

## Testing

```bash
# Test load balancer
curl -k https://localhost:443/lb-health

# Test SQL Server
# Server: localhost,1433
# Username: sa  
# Password: S0methingS@Str0ng!

# Run vector-demos.sql to test embeddings
```

## Services

- **ollama**: 4 instances on host (ports 11434-11437)
- **nginx**: Load balancer in Docker (port 443)  
- **sql-server**: SQL Server 2025 in Docker (port 1433)

## Cleanup

```bash
# Stop ollama instances
./stop.sh

# Stop Docker services
docker compose down
```
