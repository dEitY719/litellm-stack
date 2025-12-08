.PHONY: help .env-setup up down logs ps health restart reset build pull logs-follow shell-litellm shell-db

# Environment setup
export LITELLM_PROJECT_PATH:=$(PWD)
export LITELLM_URL:=http://localhost:4444
export LITELLM_API_KEY:=sk-4444

.env-setup:
	@echo "✅ Environment variables configured:"
	@echo "   LITELLM_PROJECT_PATH: $(LITELLM_PROJECT_PATH)"
	@echo "   LITELLM_URL: $(LITELLM_URL)"
	@echo "   LITELLM_API_KEY: $(LITELLM_API_KEY)"

help:
	@echo "LiteLLM Docker Compose Commands"
	@echo "==============================="
	@echo "make up          - Start all services (litellm, litellm_db, tinyllama1)"
	@echo "make down        - Stop all services"
	@echo "make logs        - View logs from all services"
	@echo "make logs-follow - Follow logs from all services in real-time"
	@echo "make ps          - Show running containers status"
	@echo "make health      - Check health of services"
	@echo "make restart     - Restart all services"
	@echo "make reset       - Reset all data (removes volumes)"
	@echo "make build       - Pull latest images"
	@echo "make shell-litellm   - Access LiteLLM container shell"
	@echo "make shell-db        - Access PostgreSQL container shell"

up: .env-setup
	@echo "Starting LiteLLM stack..."
	docker compose up -d
	@echo ""
	@echo "Waiting for services to be ready..."
	@sleep 5
	@make ps
	@echo ""
	@echo "Health check:"
	@make health

down:
	@echo "Stopping all services..."
	docker compose down

logs:
	docker compose logs

logs-follow:
	docker compose logs -f

ps:
	docker compose ps

health:
	@echo "Checking LiteLLM health (http://localhost:4444/health/liveliness)..."
	@curl -s http://localhost:4444/health/liveliness || echo "❌ LiteLLM is not responding"
	@echo ""
	@echo "Checking database connectivity..."
	@docker exec litellm_db pg_isready -U llmproxy -d litellm || echo "❌ Database is not responding"

restart: down up

reset:
	@echo "⚠️  WARNING: This will delete all data in volumes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Resetting all data..."; \
		docker compose down -v; \
		echo "Reset complete. Run 'make up' to restart."; \
	else \
		echo "Reset cancelled."; \
	fi

build:
	@echo "Pulling latest images..."
	docker compose pull
	@echo "Images updated. Run 'make restart' to apply changes."

shell-litellm:
	@docker exec -it litellm /bin/bash

shell-db:
	@docker exec -it litellm_db psql -U llmproxy -d litellm
