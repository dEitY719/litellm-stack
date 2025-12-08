# Repository Guidelines

## Project Structure & Module Organization
Primary runtime assets live at the repository root, so keep layout flat and predictable. `docker-compose.yml` orchestrates the litellm proxy plus the three Ollama-backed `tinyllama{1..3}` services and postgres; treat it as the source of truth for service names, ports (4444), and health checks. `litellm_settings.yml` configures routed models, rate limits, and credentials; align any new provider blocks with the existing YAML schema before wiring them into Docker Compose. `README.md` doubles as the runbook; keep new operator notes near the relevant section rather than scattering new files.

## Build, Test, and Development Commands
Spin up the full stack with `docker compose up -d`; it builds the litellm container, starts Ollama instances, and seeds postgres volumes. Use `docker compose logs -f litellm` while iterating on prompts or proxy features. First-time model loads require `docker exec -it tinyllamaN ollama run tinyllama` (run once per service) so the models stay cached. Shut down cleanly with `docker compose down -v` when you need a cold restart. Exercise the API proxy via `curl http://localhost:4444/models -H "Authorization: Bearer sk-4444"` and `/v1/chat/completions` requests to confirm new config takes effect.

## Coding Style & Naming Conventions
Compose files and settings stay in YAML with two-space indents and lowercase-hyphenated keys (e.g., `service-name`, `environment`). Container names follow `tinyllama<number>` so scripts can loop deterministically; match that pattern for additional replicas. Keep environment variables uppercase with underscores, and document defaults inside `litellm_settings.yml`. Comments should explain intent ("why we proxy this endpoint"), not implementation trivia.

## Testing Guidelines
Treat the curl probes as smoke tests: run the `/models` check whenever Compose changes, then send a short conversation payload to `/v1/chat/completions` for every new model mapping. When editing litellm routing logic, add regression scripts under `tests/` (create if missing) that replay representative prompts against the local proxy. Aim for coverage of each provider block you touch, and capture failures with response snippets in the PR description.

## Commit & Pull Request Guidelines
Recent commits use short, imperative summaries (`update README`); follow that style and keep body lines wrapped at ~72 columns with bullet points for context. Reference an issue ID or ticket tag when available. PRs should list the commands run (`docker compose up -d`, curl smoke tests), describe any new environment variables, and include screenshots of GUI configuration changes. Request reviewers familiar with both Docker and litellm before merging and wait for green CI (or pasted log excerpts if CI is manual).

