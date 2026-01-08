# AGENTS.md: LiteLLM Stack Governance

## Project Context

**Mission:** Unified Docker Compose stack integrating Ollama (local LLM inference) and LiteLLM (OpenAI-compatible AI Gateway) with persistent PostgreSQL backend.

**Tech Stack:**

- Python 3.13, Docker Compose
- LiteLLM >= 1.34.0, LangChain, Ollama
- PostgreSQL 16, ruff/mypy/shellcheck linting

**Repository Structure:** Monorepo at `/home/bwyoon/para/project/litellm`

- docker-compose.yml: source of truth (service names, ports 4444/11434)
- litellm_settings.yml: model routing and provider config
- scripts/: operator helpers (setup_models.sh, health_check.sh)
- example/: integration test patterns
- docs/: architecture decisions

---

## Operational Commands

### Development & Stack Management

```bash
docker compose up -d              # Start full stack (litellm + ollama + db)
docker compose down -v            # Cold shutdown with volume reset
docker compose logs -f litellm    # Tail LiteLLM proxy logs
docker compose ps                 # Service status
make init                         # Initialize volumes + migrations
make health                       # Full stack health check
```

### Python & Linting

```bash
tox -e ruff                       # Format + lint Python (auto-fix)
tox -e mypy                       # Type checking
tox -e mdlint                     # Markdown linting (auto-fix)
tox -e shellcheck                 # Shell script validation
tox -e shfmt                      # Shell formatting (auto-fix)
tox -e style                      # Full pipeline: ruff -> isort -> black
```

### Model Management

```bash
docker exec ollama ollama list                         # List cached models
docker exec ollama ollama pull gpt-oss:20b            # Download model
docker exec ollama ollama run gpt-oss:20b "warmup"   # Preload to VRAM
docker exec ollama nvidia-smi                         # GPU memory status
```

### Testing & Smoke Checks

```bash
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"                  # List routed models

curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{"model": "tinyllama", "messages": [{"role": "user", "content": "Hello"}]}'

docker compose exec db psql -U llmproxy -d litellm  # Access config DB
```

---

## Golden Rules (Immutable Constraints)

### Docker & Service Architecture

- DO: Reference services by name (<http://ollama:11434>), NOT localhost
- DO: Update docker-compose.yml as source of truth for ports/health
- DO: Treat docker-compose.yml and litellm_settings.yml as coupled
- DON'T: Create manual volume binds; use docker volumes for persistence
- DON'T: Hardcode IP addresses or localhost in container configs

### Configuration Management

- DO: Align litellm_settings.yml model_list with actual Ollama models
- DO: Restart litellm after model/provider changes: docker compose restart litellm
- DO: Document new environment variables inside litellm_settings.yml
- DON'T: Modify .env manually; use .env.example as template
- DON'T: Commit secrets (API keys, tokens) to git

### Testing & Smoke Tests

- DO: Run /models health check after docker-compose changes
- DO: Send representative prompt to /v1/chat/completions for each new model
- DO: Capture curl response snippets in PR descriptions
- DO: Test cold start (first request) with perf measurement
- DON'T: Skip smoke tests for litellm_settings.yml edits

### YAML & Formatting

- DO: Use 2-space indents, lowercase-hyphenated keys
- DO: Name containers deterministically (tinyllama1, tinyllama2, etc.)
- DO: Use UPPERCASE for env vars, trailing underscores for internal flags
- DON'T: Use inline YAML anchors without documentation
- DON'T: Mix tabs and spaces

### Git & Commits

- DO: Use short imperative summaries ("update README", "fix gpu detection")
- DO: Wrap body at 72 columns; reference issue/ticket tags
- DO: Include docker compose commands and curl probes in PR bodies
- DO: Request reviewers familiar with Docker and LiteLLM
- DON'T: Commit without passing: tox -e ruff, tox -e mypy

---

## SOLID & Design Principles

### Single Responsibility Principle (SRP)

- docker-compose.yml: orchestration only, NOT configuration logic
- litellm_settings.yml: model routing only, NOT deployment logic
- scripts/setup_models.sh: GPU detection only, NOT auth management
- Each module handles ONE domain; changes to one don't affect others

### Open/Closed Principle (OCP)

- Extend model_list in litellm_settings.yml without modifying docker-compose.yml
- Add new providers as new sections, NOT by editing existing ones
- Use environment variables for API keys, allowing override without code change

### Liskov Substitution Principle (LSP)

- All models in model_list must respond to /v1/chat/completions interface
- Ollama providers and external APIs (Gemini, OpenAI) are interchangeable
- Proxy client code should work with any model_name without checking type

### Interface Segregation Principle (ISP)

- Clients don't need to know whether model is local (Ollama) or remote (API)
- Only expose needed fields in LiteLLM config (model, api_base, api_key)
- Don't require unused config blocks

### Dependency Inversion Principle (DIP)

- LiteLLM depends on interface (model_name), NOT specific provider implementation
- Scripts depend on Docker API, NOT hardcoded container IDs
- Health checks depend on HTTP contract (/health), NOT internal state

---

## Test-First (TDD) Protocol

### Workflow

1. Write failing test/curl probe demonstrating requirement
2. Implement minimal code to pass (docker config, script logic)
3. Refactor while keeping smoke tests green
4. Commit only when health_check.sh passes

### Targeted Test Commands

```bash
# Per-domain tests
pytest example/test_*.py -v                    # Python integration tests
bash scripts/health_check.sh                   # Full stack health
docker exec litellm curl http://litellm:4444/health/liveliness

# Coverage goal
tox -e mypy                                    # 100% type coverage
tox -e ruff                                    # No lint violations
```

### Coverage Requirements

- Python examples: >= 80% if testing logic exists
- Bash scripts: shellcheck clean, shfmt compliant
- docker-compose.yml: healthchecks for all services with depends_on
- litellm_settings.yml: tested via curl /models

### Validation Gates

- [ ] Test exists before implementation
- [ ] Smoke test passes: curl /models and /v1/chat/completions
- [ ] Docker logs contain no errors: docker compose logs litellm | grep -i error
- [ ] Environment variables documented in litellm_settings.yml comment
- [ ] Linting passes: tox -e ruff, tox -e mdlint, tox -e shellcheck

---

## Naming Conventions

### Python & Docker

- Function names: snake_case (test_ollama_model_loading)
- Container names: lowercase-hyphenated (ollama, litellm, db)
- Environment vars: UPPERCASE_WITH_UNDERSCORES (LITELLM_MASTER_KEY)
- Config files: lowercase-dash (litellm_settings.yml, docker-compose.yml)

### Bash Scripts

- Files: snake_case with .sh suffix (setup_models.sh, health_check.sh)
- Functions: snake_case (setup_models, health_check)
- Internal vars: UPPERCASE (VRAM_THRESHOLD, GPU_COUNT)
- User-facing aliases: lowercase-dash (setup-models, health-check)

### Markdown & Documentation

- Files: dash-form (architecture-litellm-ollama-final.md)
- Headings: Sentence case (Model Routing Configuration)
- Code blocks: Always include language (```bash,```python, ```yaml)

---

## Context Map: Module Routing

- **[Architecture & Decisions](./docs/architecture-litellm-ollama-final.md)** — Design rationale, SOLID enforcement, migration guide
- **[Repository Strategy](./docs/git-repository-strategy.md)** — Monorepo decision, CI/CD patterns
- **[Operational Scripts](./scripts/AGENTS.md)** — GPU detection, model setup, health checks (conditional)
- **[Integration Examples](./example/)** — Python test patterns (LangChain, OpenAI client)
- **[Configuration Source](./litellm_settings.yml)** — Model routing, provider blocks, env var overrides
- **[Stack Composition](./docker-compose.yml)** — Service orchestration (source of truth)
- **[Main Runbook](./README.md)** — Quick start, system requirements, troubleshooting

---

## Validation Checklist

- [ ] Backup created: .agents.md.TIMESTAMP.backup exists
- [ ] Root AGENTS.md < 500 lines
- [ ] No emojis in content
- [ ] Context Map uses lists, NOT tables
- [ ] All linked paths are relative
- [ ] Operational commands tested and valid
- [ ] SOLID principles section explicit (SRP, OCP, LSP, ISP, DIP)
- [ ] TDD workflow documented with validation gates
- [ ] Naming conventions match .markdownlint.json config
