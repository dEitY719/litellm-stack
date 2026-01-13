# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 🎯 Project Overview

**LiteLLM Stack** is a unified Monorepo that integrates **Ollama (local LLM inference)** and **LiteLLM (AI Gateway)** into a single Docker Compose stack.

### Key Components

- **Ollama**: Local LLM serving with GPU acceleration (gpt-oss:20b, tinyllama, bge-m3)
- **LiteLLM**: OpenAI-compatible AI Gateway (Ollama + Gemini + OpenAI + Claude + ...)
- **PostgreSQL**: LiteLLM configuration and usage logs

### Architecture Type

- **Monorepo**: Single repository for entire stack
- **Single docker-compose.yml**: All services in one file
- **Process Isolation**: Ollama, LiteLLM, DB run as separate containers
- **Network Sharing**: Containers communicate via service names (`http://ollama:11434`)

---

## 📅 Recent Work History

### Latest Updates (2026-01-13) - Peer Setup Compatibility Fix

**Problem Identified:**
- Peers could not clone and run the repo (docker-compose up would fail)
- Root cause: `docker-compose.yml` marked volumes and network as `external: true`
- This required manual `make init` or `scripts/migrate.sh` execution
- Not intuitive for new users → breaking "first-time setup" experience

**Fixes Applied:**

1. **docker-compose.yml - Remove `external: true`**
   - Volumes: `litellm_postgres_data`, `litellm_ollama_data` now auto-create
   - Network: `litellm-network` now auto-create on first `docker compose up -d`
   - Impact: New environments work seamlessly without pre-initialization

2. **scripts/migrate.sh - Enhanced**
   - Now creates both volumes AND network (previously volumes only)
   - Better status messaging for troubleshooting
   - Still supports legacy migration from previous `litellm` project

3. **README.md - Clearer Quick Start**
   - Added explicit "Initialize" section with two options:
     - Option A: `make init && make up` (recommended)
     - Option B: `cp .env.example .env && docker compose up -d`
   - Added "Troubleshooting" for fresh setup errors
   - Better step-by-step guide

4. **Why this change?**
   - `external: true` was intended for graceful migration from separate projects
   - But it prevented fresh clones from working
   - New approach: Auto-create on first run, keep existing if present
   - Better UX: Works both for migration AND new setups

---

### Previous Updates (2025-12-08)

**Fixes Applied:**

1. **setup_models.sh VRAM threshold fix**
   - Changed from 16GB to 14GB (more realistic for gpt-oss:20b)
   - Allows 15GB VRAM systems to run high-spec models

2. **Migration Script** (initial)
   - Created `scripts/migrate.sh` for volume initialization
   - Integrated into `make init` workflow

3. **Makefile Enhancement**
   - `make init` includes volume migration
   - Better help message formatting

### Project Consolidation

**Previous State:**

- `devnet_env_setup/` - Ollama setup project (separate repo)
- `litellm/` - LiteLLM gateway project (separate repo)
- 2 docker-compose.yml files (separate management)

**Current State (Unified):**

- `litellm-stack/` - Single Monorepo
- Single docker-compose.yml for entire stack
- tinyllama1 merged into main ollama service
- Comprehensive documentation in `docs/`

### Key Decisions Made

1. **Architecture: Option C (Hybrid)**
   - Single Compose stack
   - Process separation (Ollama vs LiteLLM)
   - Network sharing (Docker internal DNS)
   - Reference: `docs/architecture-litellm-ollama-final.md`

2. **Repository Strategy: Monorepo**
   - Single GitHub repository: <https://github.com/dEitY719/litellm-stack>
   - Unified version management (v1.0.0)
   - Simplified deployment workflow
   - Reference: `docs/git-repository-strategy.md`

3. **Model Management**
   - Auto-detection for low/high spec PCs
   - Low spec: tinyllama only (~50MB)
   - High spec: tinyllama + gpt-oss:20b (~11GB) + bge-m3 (~2GB)

### Files Created/Modified

- `README.md` - Comprehensive project documentation
- `docs/architecture-litellm-ollama-final.md` - Architecture decisions
- `docs/git-repository-strategy.md` - Repository management strategy
- `docker-compose.yml` - Updated to use single ollama service
- `litellm_settings.yml` - Model routing configuration

### Git Status

- ✅ Initial commit: `9efaf3d`
- ✅ Pushed to: <https://github.com/dEitY719/litellm-stack>
- ✅ Tagged: v1.0.0
- ✅ Branch: main

---

## 📋 Pending Tasks

### ✅ COMPLETED (2026-01-13)

**Peer Setup Compatibility Issue - FIXED**

1. ✅ `docker-compose.yml` - Removed `external: true` from volumes and network
2. ✅ `scripts/migrate.sh` - Enhanced to create network + volumes
3. ✅ `README.md` - Added clear initialization instructions
4. ✅ `CLAUDE.md` - Updated with latest work history

**Why these fixes ensure peer compatibility:**
- Fresh `git clone` → `make init && make up` now works seamlessly
- No more manual volume/network creation needed
- Both migration (existing data) and fresh setup cases work
- Better error messages in troubleshooting

### 1. Directory Rename (User will do manually)

**Current:**

```
/home/bwyoon/para/project/devnet_env_setup/
```

**Target:**

```
/home/bwyoon/para/project/ollama/
```

**Reason:** More intuitive name

### 2. ✅ Scripts (COMPLETED)

- ✅ `scripts/setup_models.sh` - Auto model setup with GPU detection
- ✅ `scripts/health_check.sh` - Full stack health check
- ✅ `scripts/migrate.sh` - Volume + network initialization
- 🔄 Future: `scripts/backup.sh`, `scripts/restore.sh`

### 3. ✅ docker-compose.yml (COMPLETED)

Structure completed:

- ✅ Single unified `ollama` service (port 11434)
- ✅ GPU acceleration configured
- ✅ Proper healthchecks with `depends_on` conditions
- ✅ Docker network properly configured
- ✅ litellm depends on ollama and db

**Reference:** `docs/architecture-litellm-ollama-final.md` section 3.1

---

## 🏗️ Repository Structure

```
litellm-stack/
├── AGENTS.md                       # Repository governance & agent notes
├── CLAUDE.md                       # This file
├── CODE_REVIEW.md                  # Code review guidelines
├── README.md                       # Main documentation / runbook
├── USAGE.md                        # Usage guide
├── docker-compose.yml              # Unified stack (ollama + litellm + db)
├── litellm_settings.yml            # Model routing config for LiteLLM proxy
├── Makefile                        # Compose and helper commands
├── .env.example                    # Environment variable template
├── .env                            # Local environment (gitignored)
├── .dockerignore
├── .gitignore
├── .python-version                 # Python version pin
├── pyproject.toml                  # Python tooling config
├── requirements.txt                # Runtime dependencies
├── tox.ini                         # Tox/ruff/mypy config
├── uv.lock                         # Python lock file
├── docs/                           # Architecture and repo strategy docs
│   ├── architecture-litellm-ollama-final.md
│   └── git-repository-strategy.md
├── example/                        # Python examples for hitting the proxy
│   ├── test_langchain_agent.py
│   ├── test_langchain_openai.py
│   └── test_openai.py
├── scripts/                        # Stack setup and smoke-test scripts
│   ├── health_check.sh
│   ├── list_models.sh
│   ├── migrate.sh
│   ├── setup_models.sh
│   └── test_setup.sh
├── tools/                          # Placeholder for future tooling
├── .claude/                        # Local Claude configuration
├── .tox/                           # Virtualenv for lint/test runs
├── .mypy_cache/                    # Generated mypy cache
├── .ruff_cache/                    # Generated ruff cache
└── .markdownlint.json              # Markdown lint rules
```

---

## 🔧 Technology Stack

- **Docker & Docker Compose**: Service orchestration
- **Ollama**: Local LLM runtime (GPU accelerated)
- **LiteLLM** (v1.73.0): AI Gateway with 100+ provider support
- **PostgreSQL 16**: Configuration persistence
- **Python 3.13**: Application runtime
- **LangChain**: AI agent framework

---

## 🚀 Common Commands

### Initial Setup

```bash
# 1. Clone repository
git clone https://github.com/dEitY719/litellm-stack
cd litellm-stack

# 2. Configure environment
cp .env.example .env
vim .env  # Set GEMINI_API_KEY, etc.

# 3. Start entire stack
docker compose up -d

# 4. Auto setup models (TODO: create script)
chmod +x scripts/setup_models.sh
./scripts/setup_models.sh

# 5. Health check (TODO: create script)
chmod +x scripts/health_check.sh
./scripts/health_check.sh
```

### Makefile Commands

```bash
make up          # Start all services
make down        # Stop all services
make restart     # Restart all services
make logs        # View logs
make ps          # Container status
make health      # Health check
make setup       # Auto model setup
make test        # Integration test
```

### Manual Model Management

```bash
# Download model
docker exec ollama ollama pull <model-name>

# List models
docker exec ollama ollama list

# Remove model (free VRAM)
docker exec ollama ollama rm <model-name>

# Pre-load model (prevent cold start)
docker exec ollama ollama run gpt-oss:20b "warm up"

# Check GPU memory
docker exec ollama nvidia-smi
```

### Testing

```bash
# Check available models
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"

# Test tinyllama (low spec)
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Test gpt-oss:20b (high spec)
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss-20b",
    "messages": [{"role": "user", "content": "한국의 수도는?"}]
  }'

# Health check
curl http://localhost:4444/health/liveliness
```

### Debugging

```bash
# View logs
docker compose logs -f                # All services
docker compose logs -f ollama         # Ollama only
docker compose logs -f litellm        # LiteLLM only
docker compose logs -f db             # PostgreSQL only

# Access container shell
docker exec -it ollama /bin/bash
docker exec -it litellm /bin/bash
docker exec -it litellm_db psql -U llmproxy -d litellm

# Check Docker network
docker network inspect litellm-network
```

---

## ⚙️ Configuration Files

### docker-compose.yml

**Current Status:** ⚠️ Needs update to new architecture

**Expected Structure:**

```yaml
services:
  ollama:          # Single Ollama service (was: tinyllama1, tinyllama2, tinyllama3)
    ports:
      - "11434:11434"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  litellm:
    depends_on:
      - ollama   # Wait for Ollama
      - db       # Wait for PostgreSQL

  db:
    # PostgreSQL configuration
```

**Reference:** `docs/architecture-litellm-ollama-final.md` section 3.1

### litellm_settings.yml

**Model Configuration:**

```yaml
model_list:
  # Local Ollama models
  - model_name: tinyllama
    litellm_params:
      model: ollama/tinyllama
      api_base: http://ollama:11434  # Service name (Docker DNS)

  - model_name: gpt-oss-20b
    litellm_params:
      model: ollama/gpt-oss:20b
      api_base: http://ollama:11434

  # External APIs
  - model_name: gemini-2.5-pro
    litellm_params:
      model: gemini/gemini-2.5-pro
      api_key: os.environ/GEMINI_API_KEY
```

**Key Points:**

- Use `http://ollama:11434` (service name, not localhost)
- External API keys loaded from environment variables
- Changes require LiteLLM restart: `docker compose restart litellm`

### Environment Variables

**.env file (create from .env.example):**

```bash
# External API keys
GEMINI_API_KEY=your-gemini-api-key-here
OPENAI_API_KEY=your-openai-api-key-here

# LiteLLM master key (fixed for this project)
LITELLM_MASTER_KEY=sk-4444
```

---

## 🎨 Development Patterns

### Adding New Models

#### 1. Local Ollama Model

```bash
# Download model
docker exec ollama ollama pull llama-3-8b

# Add to litellm_settings.yml
cat >> litellm_settings.yml <<EOF
  - model_name: llama-3-8b
    litellm_params:
      model: ollama/llama-3-8b
      api_base: http://ollama:11434
EOF

# Restart LiteLLM
docker compose restart litellm

# Test
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{"model": "llama-3-8b", "messages": [{"role": "user", "content": "Hi"}]}'
```

#### 2. External API Model

```bash
# Add API key to .env
echo "OPENAI_API_KEY=sk-..." >> .env

# Add to litellm_settings.yml
cat >> litellm_settings.yml <<EOF
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY
EOF

# Restart with new env
docker compose up -d --force-recreate litellm
```

### System Requirements

#### Low Spec PC (Minimum)

- **CPU**: 4+ cores
- **RAM**: 8GB
- **GPU**: Not required (CPU mode)
- **Disk**: 10GB
- **Models**: tinyllama, external APIs

#### High Spec PC (Recommended)

- **CPU**: 8+ cores
- **RAM**: 16GB+
- **GPU**: NVIDIA 16GB+ VRAM
- **Disk**: 50GB
- **Models**: tinyllama, gpt-oss:20b, bge-m3, external APIs

---

## 🐛 Troubleshooting

### GPU Not Detected

```bash
# 1. Check NVIDIA driver
nvidia-smi

# 2. Test Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# 3. Install NVIDIA Container Toolkit (if missing)
# See: docs/architecture-litellm-ollama-final.md section 8.1
```

### Model Not Found

```bash
# Check if model exists in Ollama
docker exec ollama ollama list

# If missing, download it
docker exec ollama ollama pull gpt-oss:20b

# Verify it's in litellm_settings.yml
grep "gpt-oss-20b" litellm_settings.yml
```

### LiteLLM Not Responding

```bash
# Check container status
docker compose ps

# View logs
docker compose logs litellm

# Restart
docker compose restart litellm

# Full reset
docker compose down && docker compose up -d
```

### Slow First Response (Cold Start)

```bash
# Pre-load model
docker exec ollama ollama run gpt-oss:20b "warmup"

# Or set OLLAMA_KEEP_ALIVE="-1" in docker-compose.yml
# (keeps model in memory always)
```

### Out of Memory (OOM)

```bash
# Check GPU memory
docker exec ollama nvidia-smi

# Remove unused models
docker exec ollama ollama rm <unused-model>

# Reduce OLLAMA_KEEP_ALIVE time
# docker-compose.yml: OLLAMA_KEEP_ALIVE="2m"
```

---

## 📚 Documentation

### Main Documents

- **README.md** - Quick start guide, features, system requirements
- **docs/architecture-litellm-ollama-final.md** - Complete architecture document
  - Architecture decisions (Monorepo vs Multi-repo)
  - SOLID principles analysis
  - Implementation guide
  - Migration guide
  - Troubleshooting (comprehensive)

- **docs/git-repository-strategy.md** - Repository management
  - Monorepo vs Multi-repo comparison
  - Version management strategy
  - CI/CD guidelines

### References

- [Ollama Documentation](https://github.com/ollama/ollama)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)

---

## 🔄 Version Management

This project uses [Semantic Versioning](https://semver.org/):

- **Major (v2.0.0)**: Breaking changes (API changes, structure changes)
- **Minor (v1.1.0)**: New features (new models, new APIs)
- **Patch (v1.0.1)**: Bug fixes, configuration tweaks

**Current Version:** v1.0.0 (2025-12-08)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make changes
4. Test locally: `docker compose up -d`
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

---

## 📝 Notes for Claude Code

### When Starting Work

1. **Check pending tasks** in this file (section: Pending Tasks)
2. **Review recent changes** in git log: `git log --oneline -10`
3. **Check running services**: `docker compose ps`
4. **Review documentation** in `docs/` for context

### When Making Changes

1. **Update this file** if architecture decisions change
2. **Update README.md** if user-facing features change
3. **Update docs/** for major architectural changes
4. **Test locally** before committing: `docker compose up -d`
5. **Follow Semantic Versioning** for tags

### Important Paths

- **Project root**: `/home/bwyoon/para/project/litellm-stack`
- **Separate Ollama project**: `/home/bwyoon/para/project/devnet_env_setup` (to be renamed to `ollama`)
- **Old backups**: `/home/bwyoon/para/project/{litellm,devnet_env_setup}.old`

---

**Last Updated:** 2025-12-08 by Claude Sonnet 4.5
**Next Update:** After completing pending tasks (scripts creation, docker-compose.yml update)
