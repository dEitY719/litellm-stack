# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a **Docker Compose-based development environment** that sets up a complete LLM application stack:

- **LiteLLM Proxy Server**: A unified OpenAI-compatible API proxy (`localhost:4444`) that routes requests to multiple language model providers
- **Local Ollama Instances**: Three independent Ollama servers (tinyllama1-3) running TinyLlama models for testing
- **PostgreSQL Database**: Persists LiteLLM configurations and enables dynamic model management via the web UI
- **LangChain Agent Application** (in `src/`): Example agent that uses LiteLLM to access external models with tool integration

The setup demonstrates multi-model orchestration patterns suitable for production-like testing and development.

## Technology Stack

- **Docker & Docker Compose**: Service orchestration (version in docker-compose.yml)
- **LiteLLM** (v1.73.0): OpenAI-compatible LLM proxy with 100+ provider support
- **Ollama**: Local language model runtime
- **PostgreSQL 16**: Configuration and model metadata persistence
- **LangChain**: AI agent framework with tool integration
- **Python 3.x**: Application runtime (via LangChain dependencies)

## Repository Structure

```
.
├── docker-compose.yml         # Orchestrates all services (LiteLLM, Ollama x3, PostgreSQL)
├── litellm_settings.yml       # Model routing configuration (YAML schema)
├── pyproject.toml             # Python project dependencies (LangChain, litellm)
├── README.md                  # Setup instructions (Korean)
├── AGENTS.md                  # Repository governance & coding standards
├── src/
│   └── run_langchain_agent.py # Example LangChain agent using LiteLLM proxy
└── .venv/                     # Python virtual environment (uv managed)
```

## Service Architecture

```
┌──────────────────────────────────────┐
│  Client Apps (src/run_langchain_agent.py)
│  or Direct HTTP (localhost:4444)      │
└──────────────┬───────────────────────┘
               │ Authorization: Bearer sk-4444
               ▼
┌──────────────────────────────────────┐
│  LiteLLM Proxy Server (v1.73.0)      │
│  - OpenAI API compatibility          │
│  - Dynamic model routing              │
│  - Cost tracking & rate limiting      │
│  - PostgreSQL model persistence      │
└─┬──────────────┬──────────────┬──────┘
  │              │              │
  ▼              ▼              ▼
Ollama #1    Ollama #2     Ollama #3
tinyllama    tinyllama     tinyllama
(local)      (local)       (local)
  ▼
PostgreSQL (stores config, API keys, usage)
```

## Common Commands

### Initial Setup

```bash
# Start all services (litellm, ollama x3, postgres)
docker compose up -d

# Load models into Ollama instances (required once per service)
# This downloads and caches the TinyLlama model (~50MB per instance)
docker exec -it tinyllama1 ollama run tinyllama

# Verify all containers are healthy
docker compose ps
```

### Running the Application

```bash
# Run the LangChain agent example (requires Python environment)
# Assumes LiteLLM proxy is running on localhost:4444
cd src
python run_langchain_agent.py
```

### Testing the Proxy API

```bash
# Check available models (via LiteLLM web UI)
curl -X GET "http://localhost:4444/models" \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json"

# Test chat completion with local ollama model
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama1",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Proxy health check
curl http://localhost:4444/health/liveliness
```

### Logs & Debugging

```bash
# Stream logs from all services
docker compose logs -f

# View specific service logs (follow mode)
docker compose logs -f litellm     # Proxy server
docker compose logs -f tinyllama1  # Ollama instance
docker compose logs -f db          # PostgreSQL

# Access container shells for debugging
docker exec -it litellm /bin/bash
docker exec -it tinyllama1 /bin/bash
docker exec -it litellm_db psql -U llmproxy -d litellm

# Check if models are loaded in Ollama
docker exec -it tinyllama1 ollama list
```

### Lifecycle Management

```bash
# Stop all services (preserves volumes and data)
docker compose down

# Full reset (removes all volumes, caches, and database)
docker compose down -v

# Rebuild after configuration changes
docker compose up -d --force-recreate

# Update LiteLLM to latest version
docker compose pull litellm
docker compose up -d --force-recreate litellm
```

## Configuration

### Key Configuration Files

**docker-compose.yml** (docker-compose.yml:1-82)
- Orchestrates LiteLLM, 3x Ollama instances, and PostgreSQL
- Defines ports: 4444 (LiteLLM), 11431-11433 (Ollama), 5431 (PostgreSQL)
- Sets environment variables: `DATABASE_URL`, `LITELLM_MASTER_KEY`, `STORE_MODEL_IN_DB`
- Configures health checks and service dependencies
- Mounts `litellm_settings.yml` at `/app/config.yml` inside container

**litellm_settings.yml** (litellm_settings.yml:1-20)
- YAML model routing configuration read by LiteLLM at startup
- Defines available models with provider details and API base URLs
- Example: maps `tinyllama1` model to Ollama instance at `http://tinyllama1:11434`

**pyproject.toml** (pyproject.toml:1-14)
- Python project metadata and dependencies
- Key dependencies: `langchain`, `langchain-community`, `litellm>=1.34.0`, `duckduckgo-search`
- Managed with `uv` package installer

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `LITELLM_MASTER_KEY` | `sk-4444` | Required for all API requests (`Authorization: Bearer sk-4444`) |
| `STORE_MODEL_IN_DB` | `True` | Enable web UI at `http://localhost:4444` for dynamic model management |
| `DATABASE_URL` | `postgresql://llmproxy:dbpassword9090@db:5432/litellm` | PostgreSQL connection (db service name resolves via Docker DNS) |
| `GEMINI_API_KEY` | `your-gemini-api-key` | Add your API key here to enable external providers |

### Port Mappings

| Port | Service | Internal | Purpose |
|------|---------|----------|---------|
| 4444 | litellm | 4000 | OpenAI-compatible proxy API |
| 11431 | tinyllama1 | 11434 | First Ollama instance (local development) |
| 5431 | PostgreSQL | 5432 | Database (for proxy configuration & credentials) |

### Data Persistence

All services use named Docker volumes:
- `litellm_postgres_data`: PostgreSQL database files
- `tinyllama{1,2,3}_data`: Ollama model caches (persists across restarts)

Use `docker compose down -v` to delete all volumes for a complete reset.

## Development Patterns

### Adding External LLM Providers

Use the LiteLLM web UI (recommended for dynamic configuration):

1. Start services: `docker compose up -d`
2. Navigate to `http://localhost:4444` in browser
3. Click "Add Model" and enter provider credentials (Gemini, OpenAI, Claude, etc.)
4. Configurations are automatically persisted to PostgreSQL
5. Models become available in `litellm_settings.yml` and via API

For static configuration, edit `litellm_settings.yml`:
```yaml
model_list:
  - model_name: gemini-pro
    litellm_params:
      model: gemini/gemini-pro
```
Then restart: `docker compose up -d --force-recreate litellm`

### Extending the LangChain Agent

The example agent in `src/run_langchain_agent.py` uses:
- **ChatLiteLLM** to access models via proxy: `api_base="http://localhost:4444"`
- **DuckDuckGoSearchRun** as an example tool (can add custom tools)
- **ReAct prompt** from LangChain hub for agent reasoning

To add new tools or modify the agent logic, edit the agent creation section and tool list.

### Adding More Ollama Instances

1. Edit `docker-compose.yml`: duplicate `tinyllama3` section as `tinyllama4`
2. Update ports: use `11434:11434` mapping (one per instance)
3. Create volume: `tinyllama4_data`
4. Edit `litellm_settings.yml` to add new model entry
5. Start and load:
   ```bash
   docker compose up -d
   docker exec -it tinyllama4 ollama run tinyllama
   ```

### Testing Configuration Changes

After editing `docker-compose.yml` or `litellm_settings.yml`:

```bash
# Rebuild and restart affected services
docker compose up -d --force-recreate litellm

# Verify models are available
curl -X GET "http://localhost:4444/models" \
  -H "Authorization: Bearer sk-4444"

# Test a simple request
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{"model": "tinyllama1", "messages": [{"role": "user", "content": "test"}]}'
```

## Troubleshooting

### Models not responding or not listed

```bash
# Check model status in Ollama
docker exec -it tinyllama1 ollama list

# If empty, load the model
docker exec -it tinyllama1 ollama run tinyllama

# Verify LiteLLM config loads correctly
docker compose logs litellm | grep -i "model_list\|loaded"
```

### Proxy returns 401 or 403 errors

- Verify `LITELLM_MASTER_KEY` is set to `sk-4444` in `docker-compose.yml`
- Check requests include header: `Authorization: Bearer sk-4444`
- For external providers (Gemini, OpenAI), add API keys to environment variables in `docker-compose.yml`

### Services not communicating

- Verify all containers running: `docker compose ps`
- Check service names match in `docker-compose.yml` and configuration files
- Services communicate via Docker internal DNS (e.g., `tinyllama1:11434`)
- External clients use `localhost:4444`
- View logs: `docker compose logs -f`

### PostgreSQL connection issues

```bash
# Verify database is running and accessible
docker exec -it litellm_db psql -U llmproxy -d litellm -c "SELECT version();"

# Check tables created
docker exec -it litellm_db psql -U llmproxy -d litellm -c "\dt"

# View database logs
docker compose logs db
```

### Python agent script fails to connect

```bash
# Verify LiteLLM proxy is healthy
curl http://localhost:4444/health/liveliness

# Check proxy logs for errors
docker compose logs litellm

# Ensure script uses correct endpoint
# api_base="http://localhost:4444" (not container DNS name)
```
