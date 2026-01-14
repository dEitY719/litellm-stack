# LiteLLM Stack

Unified Docker Compose stack to run **Ollama** (local LLM inference) + **LiteLLM** (OpenAI-compatible API gateway) + **PostgreSQL** together.

## Overview

- **Single `docker-compose.yml`** orchestrates all services
- **OpenAI-style API** — use standard OpenAI client libraries
- **Route to multiple models** — local Ollama models + external APIs (Gemini, OpenAI, Claude)
- **Ready-to-run examples** — Python scripts using LangChain and OpenAI SDK
- **Auto-setup** — scripts detect your hardware and configure models automatically

## Quick Start

### Prerequisites

- Docker & Docker Compose v2+
- 8GB+ RAM recommended
- (Optional) NVIDIA GPU for faster inference
- **Internal PC Users**: CA 인증서(samsungsemi-prx.com.crt) 필요 → [상세 가이드](docs/INTERNAL_SETUP.md)

### 1. Clone & Initialize

```bash
git clone https://github.com/dev-team-404/litellm-stack
cd litellm-stack

# 🔧 Interactive initialization (환경 선택)
make init
```

**선택 옵션:**
```
🏠 Home (개인 PC):         로컬 개발, SSL 검증 활성화
🌐 External (회사 외부):   공개 GitHub, SSL 검증 활성화
🏢 Internal (회사 내부):   프록시, CA 인증서 필수
```

> **Internal PC 사용자**: [docs/INTERNAL_SETUP.md](docs/INTERNAL_SETUP.md)에서 CA 인증서 다운로드 방법을 확인하세요.

### 2. Start Services

```bash
make up
```

This starts:

- **Ollama** (port 11434) — local LLM serving with GPU acceleration
- **LiteLLM** (port 4444) — OpenAI-compatible proxy
- **PostgreSQL** (port 5431) — stores config and usage logs

### 3. Verify It Works

```bash
# Check service status
docker compose ps

# List available models
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"
```

### 4. Test a Model

```bash
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "What is 2+2?"}]
  }'
```

## Model Setup

Models are auto-configured on first run. The setup script detects your hardware:

**Low-spec** (< 8GB VRAM):

- `tinyllama` — ~50MB, fast inference

**High-spec** (8GB+ VRAM):

- `tinyllama` — fast for testing
- `gpt-oss:20b` — powerful 20B parameter model (~11GB VRAM)
- `bge-m3` — embedding model for search tasks

To manually run setup:

```bash
# Auto-detect hardware and download models
make setup-models

# Or manually pull a model
docker exec ollama ollama pull gpt-oss:20b
```

## Python Examples

```bash
# Install dependencies
pip install -r requirements.txt

# Run examples
python example/test_openai.py           # OpenAI SDK style
python example/test_langchain_openai.py # LangChain
python example/test_langchain_agent.py  # Agent with tools
```

All examples use `http://localhost:4444` and key `sk-4444` (edit if you changed them).

## Configuration

### Add External API Models

Edit `.env` to add API keys:

```bash
GEMINI_API_KEY=your-key-here
OPENAI_API_KEY=your-key-here
```

Then edit `litellm_settings.yml` to add routes. Restart LiteLLM:

```bash
docker compose restart litellm
```

### GPU Optimization

Default settings in `docker-compose.yml` work for RTX 5070 Ti (16GB). For other GPUs, optionally override in `.env` (see `.env.example` for options).

## Useful Commands

```bash
make up           # Start services
make down         # Stop services
make restart      # Restart services
make logs         # Tail service logs
make health       # Check all services
```

## Troubleshooting

**Containers won't start?**
```bash
# Check logs
docker compose logs litellm

# Full restart
docker compose down -v
docker compose up -d
```

**GPU not detected?**
```bash
# On host
nvidia-smi

# In Docker
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

**Out of memory?**
```bash
# Remove unused models
docker exec ollama ollama rm model-name

# Check GPU usage
docker exec ollama nvidia-smi
```

## Architecture

- **Ollama**: Runs local models with GPU acceleration (port 11434)
- **LiteLLM**: Proxy server routes requests to Ollama or external APIs (port 4444)
- **PostgreSQL**: Stores API keys, usage stats, and config (port 5431)

All services communicate via internal Docker network. External clients connect to LiteLLM on port 4444.

## Contributing

Contributions welcome! Please:

1. Test your changes: `docker compose up -d && make health`
2. Follow shell/Python style guides (see CONTRIBUTING.md)
3. Update relevant docs
4. Submit a PR with clear description

## License

MIT — see LICENSE file for details.

## Support

- Ollama docs: https://github.com/ollama/ollama
- LiteLLM docs: https://docs.litellm.ai/
- Issues: Create a GitHub issue
