# LiteLLM Stack 🚀

Local LLM serving (Ollama) + OpenAI-compatible gateway (LiteLLM) in one Docker Compose stack.

## What is this? 🤖

- One compose file to run LiteLLM + Ollama + Postgres locally.
- Use OpenAI-style APIs while routing to local or external models.
- Includes ready-to-run Python examples and smoke-test scripts.

## Prerequisites 🔧

- Docker & Docker Compose v2+
- (Optional) NVIDIA GPU drivers for acceleration
- RAM 8GB+ recommended

## Install & Run 🏁

```bash
# 1) Clone
git clone https://github.com/dEitY719/litellm-stack
cd litellm-stack

# 2) Configure env
cp .env.example .env
# edit .env for API keys (e.g., GEMINI_API_KEY) if needed

# 3) Start stack
docker compose up -d

# 4) Auto setup models (auto-detects spec)
chmod +x scripts/setup_models.sh
./scripts/setup_models.sh

# 5) Health check
chmod +x scripts/health_check.sh
./scripts/health_check.sh
```

## Quick Smoke Test ✅

```bash
# List models
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"

# TinyLlama chat
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{"model": "tinyllama", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Python Samples 🐍

```bash
pip install -r requirements.txt
python example/test_openai.py           # OpenAI SDK style
python example/test_langchain_openai.py # LangChain chat
python example/test_langchain_agent.py  # Agent example
```

## Handy Commands 🛠️

```bash
make up        # start services
make down      # stop
make logs      # tail logs
make setup     # run model setup script
make health    # run health checks
```

## Docs & Help 📚

- Architecture: docs/architecture-litellm-ollama-final.md
- Repo strategy: docs/git-repository-strategy.md
- More examples and scripts live in `example/` and `scripts/`.

## Troubleshooting 🩹

- GPU not detected: `nvidia-smi` on host, then `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`
- Proxy health: `docker compose logs -f litellm`
- Model cache issues: restart stack `docker compose down -v && docker compose up -d`
