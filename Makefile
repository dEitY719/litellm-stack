# ============================================================
# LiteLLM Stack Makefile
# Ollama + LiteLLM + PostgreSQL Docker 환경 관리
# ============================================================

SHELL := /bin/bash
.ONESHELL:
.PHONY: help init up down logs logs-follow ps health restart setup-models health-check shell shell-db shell-ollama clean rebuild validate gpu-status gpu-info
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
	@echo -e "$(GREEN)🚀 빠른 시작:$(NC)"
	@echo "  make init              🔧 환경 선택 + .env 생성 (필수 첫 단계)"
	@echo "  make up                🚀 전체 스택 시작"
	@echo "  make health            🏥 헬스 체크"
	@echo ""
	@echo -e "$(GREEN)📋 Docker 관리:$(NC)"
	@echo "  make up                🚀 전체 스택 시작"
	@echo "  make down              🛑 전체 스택 정지"
	@echo "  make restart           🔄 재시작"
	@echo "  make rebuild           🆕 clean + up (전체 재구축)"
	@echo "  make logs              📊 실시간 로그 (Ctrl+C 종료)"
	@echo "  make ps                📋 서비스 상태"
	@echo ""
	@echo -e "$(GREEN)🎮 모델 & GPU 관리:$(NC)"
	@echo "  make setup-models      📥 모델 자동 설정 (GPU 감지)"
	@echo "  make gpu-status        🎮 GPU 상세 상태"
	@echo "  make gpu-info          ℹ️  GPU 하드웨어 정보"
	@echo ""
	@echo -e "$(GREEN)💻 컨테이너 접속:$(NC)"
	@echo "  make shell             💻 LiteLLM 셸"
	@echo "  make shell-db          💻 Database 셸"
	@echo "  make shell-ollama      💻 Ollama 셸"
	@echo ""
	@echo -e "$(GREEN)🧹 정리:$(NC)"
	@echo "  make clean             🧹 캐시 및 불필요한 이미지 정리"
	@echo ""
	@echo -e "$(YELLOW)📖 환경별 설정:$(NC)"
	@echo "  • Home (개인 PC):      최소 설정, SSL 검증 활성화"
	@echo "  • External (회사 외부): 최소 설정, SSL 검증 활성화"
	@echo "  • Internal (회사 내부): CA 인증서 필수, SSL 검증 비활성화"
	@echo "  → make init로 환경 선택 후 자동 설정됨"
	@echo ""
	@echo -e "$(GREEN)📚 사용 예시:$(NC)"
	@echo "  make init              # 1. 환경 선택 (home/external/internal)"
	@echo "  make up                # 2. 스택 시작"
	@echo "  make setup-models      # 3. 모델 설정"
	@echo "  make health            # 4. 헬스 체크"
	@echo ""
	@echo -e "$(BLUE)🔗 포트:$(NC)"
	@echo "  - LiteLLM:  $(LITELLM_URL)"
	@echo "  - Ollama:   $(OLLAMA_URL)"
	@echo "  - Database: localhost:5431"
	@echo ""
	@echo -e "$(BLUE)📖 더 많은 정보: SETUP.md 참조$(NC)"
	@echo ""

# ============================================================
# 1. 초기 설정
# ============================================================

init:
	@echo ""
	@echo -e "$(BLUE)╔════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(BLUE)║       🔧 LiteLLM 환경 초기 설정$(NC)$(BLUE)        ║$(NC)"
	@echo -e "$(BLUE)╚════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo -e "$(BLUE)실행 환경을 선택하세요:$(NC)"
	@echo ""
	@echo -e "  $(GREEN)1) home$(NC)      - 개인 PC (로컬 개발, SSL 검증 활성화)"
	@echo -e "  $(GREEN)2) external$(NC)  - 회사 외부 PC (공개 GitHub, SSL 검증 활성화)"
	@echo -e "  $(GREEN)3) internal$(NC)  - 회사 내부 PC (프록시, SSL 검증 비활성화, CA 인증서 필수)"
	@echo ""
	@read -p "선택 (1-3, Enter로 기본값 1 선택): " choice; \
	choice=$${choice:-1}; \
	case $$choice in \
		1) \
			LITELLM_ENV=home; \
			ENV_CHOICE_NAME="Home (개인 PC - 로컬 개발)"; \
			ENV_EMOJI="🏠"; \
			;; \
		2) \
			LITELLM_ENV=external; \
			ENV_CHOICE_NAME="External (회사 외부 - 공개 네트워크)"; \
			ENV_EMOJI="🌐"; \
			;; \
		3) \
			LITELLM_ENV=internal; \
			ENV_CHOICE_NAME="Internal (회사 내부 - 프록시)"; \
			ENV_EMOJI="🏢"; \
			;; \
		*) \
			echo -e "$(RED)❌ 잘못된 선택입니다. 1-3 중 하나를 선택하세요.$(NC)"; \
			exit 1; \
			;; \
	esac; \
	echo ""; \
	echo -e "$(YELLOW)$$ENV_EMOJI 선택됨: $$ENV_CHOICE_NAME$(NC)"; \
	echo ""; \
	echo -e "$(YELLOW)📝 .env 파일 생성 중...$(NC)"; \
	if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo -e "$(GREEN)   ✅ .env 파일 생성됨$(NC)"; \
	else \
		echo -e "$(BLUE)   ℹ️  .env 파일이 이미 있습니다 (초기화하려면: rm .env && make init)$(NC)"; \
	fi; \
	echo ""; \
	echo -e "$(YELLOW)⚙️  환경 설정 적용 중 (LITELLM_ENV=$$LITELLM_ENV)...$(NC)"; \
	if grep -q "LITELLM_ENV=" .env; then \
		sed -i.bak "s/^LITELLM_ENV=.*/LITELLM_ENV=$$LITELLM_ENV/" .env; \
		rm -f .env.bak; \
		echo -e "$(GREEN)   ✅ .env 파일 업데이트됨 (LITELLM_ENV=$$LITELLM_ENV)$(NC)"; \
	else \
		echo "LITELLM_ENV=$$LITELLM_ENV" >> .env; \
		echo -e "$(GREEN)   ✅ .env 파일에 LITELLM_ENV=$$LITELLM_ENV 추가됨$(NC)"; \
	fi; \
	echo ""; \
	if [ "$$LITELLM_ENV" = "internal" ]; then \
		echo -e "$(YELLOW)🏢 Internal PC 추가 설정...$(NC)"; \
		if [ ! -f docker-compose.override.yml ]; then \
			if [ -f docker-compose.override.yml.example ]; then \
				cp docker-compose.override.yml.example docker-compose.override.yml; \
				echo -e "$(GREEN)   ✅ docker-compose.override.yml 파일 생성됨$(NC)"; \
			else \
				echo -e "$(RED)   ❌ docker-compose.override.yml.example 파일을 찾을 수 없습니다$(NC)"; \
			fi; \
		else \
			echo -e "$(BLUE)   ℹ️  docker-compose.override.yml 파일이 이미 있습니다$(NC)"; \
		fi; \
		echo ""; \
		mkdir -p certs; \
		echo -e "$(YELLOW)🔑 CA 인증서 필요 (필수)$(NC)"; \
		if [ ! -f certs/corp-ca.crt ]; then \
			echo -e "$(RED)   ❌ certs/corp-ca.crt 파일이 없습니다$(NC)"; \
			echo ""; \
			echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
			echo -e "$(BLUE)📥 CA 인증서 다운로드 방법$(NC)"; \
			echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
			echo ""; \
			echo -e "$(BLUE)1️⃣  다음 링크에서 다운로드:$(NC)"; \
			echo -e "$(YELLOW)   http://12.53.3.52:5465/apc/AgentInstall/list_agent.htm$(NC)"; \
			echo ""; \
			echo -e "$(BLUE)2️⃣  파일명: samsungsemi-prx.com.crt$(NC)"; \
			echo ""; \
			echo -e "$(BLUE)3️⃣  다운로드 후 복사:$(NC)"; \
			echo -e "$(YELLOW)   mkdir -p certs$(NC)"; \
			echo -e "$(YELLOW)   cp ~/Downloads/samsungsemi-prx.com.crt certs/corp-ca.crt$(NC)"; \
			echo ""; \
			echo -e "$(BLUE)4️⃣  다시 실행:$(NC)"; \
			echo -e "$(YELLOW)   make init$(NC)"; \
			echo ""; \
			echo -e "$(BLUE)📖 상세 가이드: docs/INTERNAL_SETUP.md$(NC)"; \
			echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
			echo ""; \
		else \
			echo -e "$(GREEN)   ✅ certs/corp-ca.crt 파일 확인됨$(NC)"; \
		fi; \
	fi; \
	echo ""; \
	echo -e "$(YELLOW)🔄 Volume 마이그레이션 중...$(NC)"; \
	if [ -f scripts/migrate.sh ]; then \
		bash scripts/migrate.sh; \
		echo -e "$(GREEN)   ✅ Volume 마이그레이션 완료$(NC)"; \
	else \
		echo -e "$(RED)   ❌ scripts/migrate.sh 파일이 없습니다$(NC)"; \
	fi; \
	echo ""; \
	echo -e "$(BLUE)╔════════════════════════════════════════════════════╗$(NC)"; \
	echo -e "$(GREEN)✅ 초기 설정 완료!$(NC)"; \
	echo -e "$(BLUE)╚════════════════════════════════════════════════════╝$(NC)"; \
	echo ""; \
	echo -e "$(BLUE)다음 단계:$(NC)"; \
	echo -e "  $(GREEN)make up$(NC)              - 스택 시작"; \
	echo -e "  $(GREEN)make setup-models$(NC)   - 모델 설정"; \
	echo -e "  $(GREEN)make health$(NC)         - 헬스 체크"; \
	echo ""

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
	@if ! grep -q "LITELLM_ENV=" .env; then \
		echo -e "$(YELLOW)⚠️  LITELLM_ENV 환경 설정이 없습니다 (설정 중...)$(NC)"; \
		$(MAKE) init; \
	fi
	@LITELLM_ENV=$$(grep "LITELLM_ENV=" .env | cut -d'=' -f2 | tr -d ' '); \
	if [ "$$LITELLM_ENV" = "internal" ] && [ ! -f docker-compose.override.yml ]; then \
		echo -e "$(RED)❌ Internal 환경이지만 docker-compose.override.yml 파일이 없습니다$(NC)"; \
		echo -e "$(BLUE)   → make init을 다시 실행하거나 docker-compose.override.yml.example을 복사하세요$(NC)"; \
		exit 1; \
	fi
	@if [ "$$LITELLM_ENV" = "internal" ] && [ ! -f samsungsemi-prx.com.crt ]; then \
		echo -e "$(YELLOW)⚠️  Internal 환경이지만 CA 인증서(samsungsemi-prx.com.crt)가 없습니다$(NC)"; \
		echo -e "$(BLUE)   → 회사 CA 인증서를 복사한 후 make up을 실행하세요$(NC)"; \
	fi
	@$(DC) config > /dev/null 2>&1 && echo -e "$(GREEN)✅ 구성 검증 완료$(NC)" || (echo -e "$(RED)❌ docker-compose 오류$(NC)"; exit 1)

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
	@echo -e "$(YELLOW)4️⃣  GPU 상태 (간략)$(NC)"
	@LATEST_OFFLOAD=$$(docker logs $(OLLAMA) 2>&1 | grep "offloaded.*layers" | tail -1 | grep -oP 'offloaded \K\d+/\d+' 2>/dev/null || echo "N/A"); \
	if [ "$$LATEST_OFFLOAD" != "N/A" ]; then \
		if [[ "$$LATEST_OFFLOAD" == 0/* ]]; then \
			echo -e "$(RED)   ⚠ GPU 레이어 오프로드: $$LATEST_OFFLOAD (CPU 모드!)$(NC)"; \
			echo -e "$(BLUE)   → 상세 진단: make gpu-status$(NC)"; \
		else \
			echo -e "$(GREEN)   ✓ GPU 레이어 오프로드: $$LATEST_OFFLOAD$(NC)"; \
		fi; \
	else \
		GPU_MEM=$$(docker logs $(OLLAMA) 2>&1 | grep "gpu memory" | tail -1 | grep -oP 'available="\K[^"]+' 2>/dev/null || echo ""); \
		if [ -n "$$GPU_MEM" ]; then \
			echo -e "$(GREEN)   ✓ GPU 인식됨 ($$GPU_MEM VRAM)$(NC)"; \
		else \
			echo -e "$(BLUE)   ⚠ GPU 미사용 또는 모델 미로드$(NC)"; \
		fi; \
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
# 7. GPU 관리
# ============================================================

gpu-status:
	@echo -e "$(YELLOW)🎮 GPU 상태 확인 (WSL2 최적화)$(NC)"
	@if [ -f scripts/gpu_status.sh ]; then \
		bash scripts/gpu_status.sh; \
	else \
		echo -e "$(RED)❌ scripts/gpu_status.sh 파일이 없습니다$(NC)"; \
		exit 1; \
	fi

gpu-info:
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo -e "$(BLUE)GPU 하드웨어 정보 (요약)$(NC)"
	@echo -e "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo ""
	@echo -e "$(YELLOW)WSL2 호스트 GPU:$(NC)"
	@if [ -x /usr/lib/wsl/lib/nvidia-smi ]; then \
		/usr/lib/wsl/lib/nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader 2>/dev/null | \
			awk -F, '{printf "  [GPU %s] %s (%s VRAM)\n", $$1, $$2, $$3}'; \
	else \
		echo -e "$(YELLOW)  ⚠ GPU 미감지 또는 nvidia-smi 없음$(NC)"; \
	fi
	@echo ""
	@echo -e "$(YELLOW)Ollama GPU 레이어 오프로드:$(NC)"
	@LATEST_OFFLOAD=$$(docker logs $(OLLAMA) 2>&1 | grep "offloaded.*layers" | tail -1 | grep -oP 'offloaded \K\d+/\d+' 2>/dev/null || echo "N/A"); \
	if [ "$$LATEST_OFFLOAD" != "N/A" ]; then \
		if [[ "$$LATEST_OFFLOAD" == 0/* ]]; then \
			echo -e "$(RED)  ⚠ $$LATEST_OFFLOAD (CPU 모드)$(NC)"; \
		else \
			echo -e "$(GREEN)  ✓ $$LATEST_OFFLOAD layers$(NC)"; \
		fi; \
	else \
		echo -e "$(BLUE)  - 아직 모델 로드 안됨$(NC)"; \
	fi
	@echo ""
	@echo -e "$(BLUE)상세 정보: make gpu-status$(NC)"
	@echo ""

# ============================================================
# Default target
# ============================================================

.DEFAULT_GOAL := help
