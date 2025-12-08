# ============================================================
# LiteLLM Stack Makefile
# Ollama + LiteLLM + PostgreSQL Docker 환경 관리
# ============================================================

SHELL := /bin/bash
.ONESHELL:
.PHONY: help init up down logs logs-follow ps health restart setup-models health-check shell shell-db shell-ollama clean rebuild validate
.SILENT:

# ============================================================
# Configuration
# ============================================================

PROJECT_NAME := litellm-stack
DC := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo "docker compose")

# Service names (from docker-compose.yml)
OLLAMA := ollama
LITELLM := litellm
DB := db

# URLs and credentials
LITELLM_URL := http://localhost:4444
OLLAMA_URL := http://localhost:11434
LITELLM_API_KEY := sk-4444

# 색상
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# ============================================================
# Help (Default Target)
# ============================================================

help:
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(BLUE)$(PROJECT_NAME) - LLM Stack 관리$(NC)"
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo -e "$(GREEN)초기 설정:$(NC)"
	@echo "  make init              🔧 .env 파일 + Volume 초기화"
	@echo ""
	@echo -e "$(GREEN)Docker 관리:$(NC)"
	@echo "  make up                🚀 전체 스택 시작"
	@echo "  make down              🛑 전체 스택 정지"
	@echo "  make restart           🔄 재시작"
	@echo "  make rebuild           🆕 clean + up"
	@echo ""
	@echo -e "$(GREEN)LLM 모델 관리:$(NC)"
	@echo "  make setup-models      📥 모델 자동 설정 (GPU 감지)"
	@echo ""
	@echo -e "$(GREEN)로깅 & 모니터링:$(NC)"
	@echo "  make logs              📊 로그 조회"
	@echo "  make health            🏥 전체 헬스 체크"
	@echo "  make ps                📋 서비스 목록"
	@echo ""
	@echo -e "$(GREEN)컨테이너 접속:$(NC)"
	@echo "  make shell             💻 LiteLLM 셸"
	@echo "  make shell-db          💻 Database 셸"
	@echo "  make shell-ollama      💻 Ollama 셸"
	@echo ""
	@echo -e "$(GREEN)정리:$(NC)"
	@echo "  make clean             🧹 캐시 및 불필요한 이미지 정리"
	@echo ""
	@echo -e "$(GREEN)사용 예시:$(NC)"
	@echo "  make init              # 1. 초기화"
	@echo "  make up                # 2. 시작"
	@echo "  make setup-models      # 3. 모델 설정"
	@echo "  make health            # 4. 헬스 체크"
	@echo ""
	@echo -e "$(BLUE)포트:$(NC)"
	@echo "  - LiteLLM:  $(LITELLM_URL)"
	@echo "  - Ollama:   $(OLLAMA_URL)"
	@echo "  - Database: localhost:5431"
	@echo ""

# ============================================================
# 1. 초기 설정
# ============================================================

init:
	@echo -e "$(YELLOW)🔧 .env 파일 초기화 중...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo -e "$(GREEN)✅ .env 파일 생성 완료 (.env.example에서)$(NC)"; \
	else \
		echo -e "$(BLUE)ℹ️  .env 파일이 이미 있습니다 (초기화: rm .env && make init)$(NC)"; \
	fi
	@echo ""
	@echo -e "$(YELLOW)🔄 Volume 마이그레이션 중...$(NC)"
	@if [ -f scripts/migrate.sh ]; then \
		bash scripts/migrate.sh; \
	else \
		echo -e "$(RED)❌ scripts/migrate.sh 파일이 없습니다$(NC)"; \
	fi

validate:
	@echo -e "$(BLUE)✓ 구성 파일 검증 중...$(NC)"
	@if [ ! -f docker-compose.yml ]; then \
		echo -e "$(RED)❌ docker-compose.yml 파일이 없습니다$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f litellm_settings.yml ]; then \
		echo -e "$(RED)❌ litellm_settings.yml 파일이 없습니다$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f .env ]; then \
		echo -e "$(YELLOW)⚠️  .env 파일이 없습니다 (생성 중...)$(NC)"; \
		$(MAKE) init; \
	fi
	@$(DC) config > /dev/null 2>&1 && echo -e "$(GREEN)✅ 구성 검증 완료$(NC)" || (echo -e "$(RED)❌ docker-compose.yml 오류$(NC)"; exit 1)

# ============================================================
# 2. Docker 실행 및 관리
# ============================================================

up: validate
	@echo -e "$(YELLOW)🚀 스택 시작 중...$(NC)"
	$(DC) up -d
	@sleep 3
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(GREEN)✅ 시작 완료!$(NC)"
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@$(MAKE) ps
	@echo ""
	@echo -e "$(BLUE)다음 단계:$(NC)"
	@echo "  make setup-models      # 모델 설정"
	@echo "  make health            # 헬스 체크"
	@echo ""

down:
	@echo -e "$(YELLOW)🛑 스택 정지 중...$(NC)"
	$(DC) down
	@echo -e "$(GREEN)✅ 정지 완료$(NC)"

restart:
	@echo -e "$(YELLOW)🔄 스택 재시작 중...$(NC)"
	$(DC) restart
	@sleep 2
	@echo -e "$(GREEN)✅ 재시작 완료$(NC)"
	@$(MAKE) ps

rebuild: down up
	@echo -e "$(GREEN)✅ 재구축 완료$(NC)"

# ============================================================
# 3. 로깅 & 모니터링
# ============================================================

logs:
	@echo -e "$(YELLOW)📊 전체 로그$(NC)"
	$(DC) logs

logs-follow:
	@echo -e "$(YELLOW)📊 실시간 로그 (Ctrl+C 종료)$(NC)"
	$(DC) logs -f

ps:
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(BLUE)실행 중인 서비스$(NC)"
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	$(DC) ps

health: validate
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(BLUE)헬스 체크$(NC)"
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo -e "$(YELLOW)1️⃣  Ollama ($(OLLAMA_URL))$(NC)"
	@if $(DC) exec $(OLLAMA) ollama list > /dev/null 2>&1; then \
		echo -e "$(GREEN)   ✅ Ollama API 정상$(NC)"; \
		$(DC) exec $(OLLAMA) ollama list | tail -n +2 | head -5; \
		echo -e "$(BLUE)   (더 많은 모델이 있을 수 있음)$(NC)"; \
	else \
		echo -e "$(RED)   ❌ Ollama API 응답 없음$(NC)"; \
	fi
	@echo ""
	@echo -e "$(YELLOW)2️⃣  LiteLLM ($(LITELLM_URL))$(NC)"
	@if curl -sf $(LITELLM_URL)/health/liveliness > /dev/null 2>&1; then \
		echo -e "$(GREEN)   ✅ LiteLLM 프록시 정상$(NC)"; \
		if [ -f scripts/list_models.sh ]; then \
			bash scripts/list_models.sh; \
		else \
			MODEL_COUNT=$$(curl -s $(LITELLM_URL)/models -H "Authorization: Bearer $(LITELLM_API_KEY)" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "?"); \
			echo -e "$(BLUE)   등록된 모델: $$MODEL_COUNT$(NC)"; \
		fi \
	else \
		echo -e "$(RED)   ❌ LiteLLM 프록시 응답 없음$(NC)"; \
	fi
	@echo ""
	@echo -e "$(YELLOW)3️⃣  Database (localhost:5431)$(NC)"
	@if $(DC) exec -T $(DB) pg_isready -U llmproxy -d litellm > /dev/null 2>&1; then \
		echo -e "$(GREEN)   ✅ Database 정상$(NC)"; \
	else \
		echo -e "$(RED)   ❌ Database 응답 없음 (docker compose exec 확인)$(NC)"; \
	fi
	@echo ""
	@echo -e "$(YELLOW)4️⃣  GPU 상태$(NC)"
	@if $(DC) exec -T $(OLLAMA) nvidia-smi > /dev/null 2>&1; then \
		$(DC) exec -T $(OLLAMA) nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "   ⚠️  GPU 정보 조회 실패"; \
	else \
		echo -e "$(BLUE)   ⚠️  GPU 미사용 또는 미감지$(NC)"; \
	fi
	@echo ""
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"

# ============================================================
# 4. LLM 모델 관리
# ============================================================

setup-models:
	@echo -e "$(YELLOW)📥 모델 자동 설정 시작...$(NC)"
	@if [ -f scripts/setup_models.sh ]; then \
		bash scripts/setup_models.sh; \
	else \
		echo -e "$(RED)❌ scripts/setup_models.sh 파일이 없습니다$(NC)"; \
		exit 1; \
	fi

health-check:
	@echo -e "$(YELLOW)🏥 전체 헬스 체크 실행 중...$(NC)"
	@if [ -f scripts/health_check.sh ]; then \
		bash scripts/health_check.sh; \
	else \
		echo -e "$(RED)❌ scripts/health_check.sh 파일이 없습니다$(NC)"; \
		exit 1; \
	fi

# ============================================================
# 5. 컨테이너 접속
# ============================================================

shell:
	@echo -e "$(YELLOW)💻 LiteLLM 셸 접속$(NC)"
	$(DC) exec -it $(LITELLM) /bin/bash

shell-db:
	@echo -e "$(YELLOW)💻 Database 접속 (litellm_db)$(NC)"
	$(DC) exec -it $(DB) psql -U llmproxy -d litellm

shell-ollama:
	@echo -e "$(YELLOW)💻 Ollama 셸 접속$(NC)"
	$(DC) exec -it $(OLLAMA) /bin/bash

# ============================================================
# 6. 정리
# ============================================================

clean:
	@echo -e "$(YELLOW)🧹 캐시 정리 중...$(NC)"
	@echo -e "$(BLUE)   • Python 캐시...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo -e "$(BLUE)   • Docker 불필요한 이미지...$(NC)"
	docker image prune -f 2>/dev/null || true
	@echo -e "$(GREEN)✅ 캐시 정리 완료$(NC)"

# ============================================================
# Default target
# ============================================================

.DEFAULT_GOAL := help
