# Git Repository 관리 전략: LiteLLM + Ollama

**작성일**: 2025-12-08
**질문**: litellm과 ollama를 1개의 GitHub Repository에서 관리 vs 별도 관리?

---

## 📋 목차

1. [TL;DR - 빠른 답변](#1-tldr---빠른-답변)
2. [옵션 비교](#2-옵션-비교)
3. [추천 전략](#3-추천-전략-단일-레포-monorepo)
4. [구현 가이드](#4-구현-가이드)
5. [대안: Multi-repo](#5-대안-multi-repo)

---

## 1. TL;DR - 빠른 답변

**✅ 추천: 단일 Repository (Monorepo)**

**이유:**
- 이미 단일 `docker-compose.yml`로 통합됨
- 설정 파일 간 의존성이 강함 (`litellm_settings.yml` ↔ `docker-compose.yml`)
- 함께 배포되어야 하는 "단일 애플리케이션"
- 버전 관리 단순화 (한 번의 commit/tag로 전체 스택 버전 관리)

**언제 별도 레포를 써야 하나?**
- Ollama를 여러 프로젝트에서 공유할 때
- 팀이 분리되어 있을 때 (Infra팀 vs App팀)
- 릴리스 사이클이 완전히 다를 때

---

## 2. 옵션 비교

### Option A: 단일 Repository (Monorepo) ⭐ 추천

```text
litellm-stack/
├── .git/
├── README.md
├── docker-compose.yml          # 전체 스택
├── litellm_settings.yml        # LiteLLM 설정
├── .env.example
├── .gitignore
├── Makefile
├── scripts/
│   ├── setup_models.sh
│   ├── health_check.sh
│   └── backup.sh
├── docs/
│   ├── architecture.md
│   ├── deployment.md
│   └── troubleshooting.md
└── tests/
    ├── test_ollama.sh
    └── test_litellm.sh
```

#### 장점

| 장점 | 설명 |
|------|------|
| **단순성** | 1개 레포만 관리, 1번의 `git clone` |
| **일관성** | 모든 설정 파일이 같은 버전으로 관리됨 |
| **원자적 변경** | 1개 commit으로 전체 스택 변경 가능 |
| **배포 단순화** | 1개 태그로 전체 스택 버전 관리 |
| **CI/CD 단순** | 1개 파이프라인으로 통합 테스트 |
| **협업 편의** | PR 1개로 전체 스택 리뷰 가능 |

#### 단점

| 단점 | 설명 | 완화 방법 |
|------|------|----------|
| **권한 관리** | 전체 레포에 대한 접근 권한 필요 | GitHub Teams로 디렉토리별 권한 설정 가능 (CODEOWNERS) |
| **대규모 팀** | 여러 팀이 동일 레포 사용 시 충돌 | 잘 정의된 디렉토리 구조 + branching 전략 |
| **부분 clone** | Ollama 설정만 필요해도 전체 clone | Git sparse-checkout 사용 가능 |

#### 사용 사례

```bash
# 개발자 워크플로우
git clone https://github.com/dEitY719/litellm-stack
cd litellm-stack
docker compose up -d

# 설정 변경
vim litellm_settings.yml
vim docker-compose.yml
git add .
git commit -m "Add new model: llama-3-8b"
git push

# 배포
git tag v1.2.0
git push --tags
```

---

### Option B: 별도 Repository (Multi-repo)

```text
ollama-infra/                    # Repository 1
├── .git/
├── README.md
├── docker-compose.yml          # Ollama만
└── scripts/
    └── setup_gpu.sh

litellm-gateway/                 # Repository 2
├── .git/
├── README.md
├── docker-compose.yml          # LiteLLM + DB
├── litellm_settings.yml
└── scripts/
    └── setup_proxy.sh
```

#### 장점

| 장점 | 설명 |
|------|------|
| **독립적 릴리스** | Ollama와 LiteLLM을 독립적으로 버전 관리 |
| **팀 분리** | Infra팀과 App팀이 별도 레포 관리 |
| **재사용성** | Ollama를 다른 프로젝트에서도 사용 가능 |
| **권한 세분화** | 레포별로 완전히 다른 권한 설정 |

#### 단점

| 단점 | 설명 |
|------|------|
| **복잡도 증가** | 2개 레포 clone, 2번의 배포 |
| **버전 불일치** | Ollama v1.2 + LiteLLM v2.1 조합 관리 필요 |
| **통합 테스트** | 2개 레포를 함께 테스트해야 함 |
| **설정 중복** | 네트워크, 볼륨 설정 중복 가능 |

#### 사용 사례

```bash
# Infra 팀
git clone https://github.com/yourteam/ollama-infra.git
cd ollama-infra
docker compose up -d

# App 팀
git clone https://github.com/yourteam/litellm-gateway.git
cd litellm-gateway
# ollama-infra가 실행 중이어야 함
docker compose up -d
```

---

### Option C: Monorepo with Subdirectories (절충안)

```text
ai-platform/
├── .git/
├── README.md
├── docker-compose.yml          # 전체 통합 (추천)
├── docker-compose.dev.yml      # 개발용 오버라이드
├── ollama/
│   ├── README.md
│   ├── docker-compose.ollama.yml  # Ollama만 (선택적)
│   └── scripts/
│       └── setup_gpu.sh
├── litellm/
│   ├── README.md
│   ├── litellm_settings.yml
│   ├── docker-compose.litellm.yml # LiteLLM만 (선택적)
│   └── scripts/
│       └── setup_proxy.sh
└── docs/
    └── architecture.md
```

#### 사용법

```bash
# 전체 스택 (운영)
docker compose up -d

# Ollama만 (개발)
docker compose -f ollama/docker-compose.ollama.yml up -d

# LiteLLM만 (개발)
docker compose -f litellm/docker-compose.litellm.yml up -d
```

---

## 3. 추천 전략: 단일 레포 (Monorepo)

### 3.1 추천 이유

**현재 아키텍처와 완벽하게 일치:**

```text
┌────────────────────────────────────────┐
│  단일 docker-compose.yml               │
│  ├─ ollama (모델 서빙)                 │
│  ├─ litellm (프록시)                   │
│  └─ litellm_db (상태 저장)             │
└────────────────────────────────────────┘
         ↓
  단일 애플리케이션 스택
         ↓
    단일 Repository
```

**배포 시나리오:**
- Ollama와 LiteLLM은 **항상 함께 배포**됨
- 설정 파일 간 강한 의존성 (litellm_settings.yml의 `api_base: http://ollama:11434`)
- 버전 불일치 시 문제 발생 가능성 높음

**팀 구조:**
- 대부분의 경우 **같은 팀**이 관리
- Infra와 App이 분리되어도, 이 스택은 "AI Gateway" 단일 역할

### 3.2 Repository 이름 제안

```text
옵션 1: litellm-stack          (추천)
옵션 2: ai-gateway
옵션 3: llm-proxy-stack
옵션 4: local-llm-platform
```

**추천**: `litellm-stack` (명확하고 검색하기 쉬움)

---

## 4. 구현 가이드

### 4.1 Monorepo 구조

**최종 디렉토리 구조:**

```text
litellm-stack/
├── .git/
├── .github/
│   └── workflows/
│       ├── ci.yml              # 자동 테스트
│       └── release.yml         # 자동 배포
├── .gitignore
├── .env.example
├── README.md
├── CHANGELOG.md
├── LICENSE
│
├── docker-compose.yml          # 전체 스택 (운영)
├── docker-compose.dev.yml      # 개발 오버라이드
├── litellm_settings.yml        # LiteLLM 설정
├── Makefile                    # 편의 명령어
│
├── scripts/
│   ├── setup_models.sh         # 모델 자동 설정
│   ├── health_check.sh         # 헬스 체크
│   ├── backup.sh               # 백업
│   └── restore.sh              # 복원
│
├── docs/
│   ├── README.md
│   ├── architecture.md
│   ├── deployment.md
│   ├── development.md
│   └── troubleshooting.md
│
├── tests/
│   ├── test_ollama.sh
│   ├── test_litellm.sh
│   └── integration_test.sh
│
└── examples/
    ├── python_client.py
    ├── curl_examples.sh
    └── langchain_agent.py
```

### 4.2 README.md 템플릿

```markdown
# LiteLLM Stack

> 로컬 LLM + API Gateway 통합 스택

## 개요

Ollama (로컬 LLM)와 LiteLLM (AI Gateway)을 단일 Docker Compose 스택으로 통합.

- **Ollama**: gpt-oss:20b, tinyllama, bge-m3 등 로컬 모델 서빙
- **LiteLLM**: 통합 API Gateway (Ollama + Gemini + ...)
- **PostgreSQL**: LiteLLM 설정 및 로그 저장

## 빠른 시작

```bash
# 1. Clone
git clone https://github.com/dEitY719/litellm-stack
cd litellm-stack

# 2. 환경 변수 설정
cp .env.example .env
# .env 파일에서 GEMINI_API_KEY 등 설정

# 3. 자동 설정
./scripts/setup_models.sh

# 4. 테스트
curl http://localhost:4444/models -H "Authorization: Bearer sk-4444"
```

## 주요 기능

- ✅ GPU 가속 지원 (NVIDIA)
- ✅ 저사양/고사양 PC 자동 감지
- ✅ OpenAI 호환 API
- ✅ 여러 LLM 통합 (Ollama, Gemini, ...)

## 문서

- [아키텍처](docs/architecture.md)
- [배포 가이드](docs/deployment.md)
- [개발 가이드](docs/development.md)
- [문제 해결](docs/troubleshooting.md)

## 라이선스

MIT
```

### 4.3 .gitignore

```gitignore
# Environment
.env
.env.local

# Docker volumes (로컬 데이터)
data/
volumes/

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp

# Python
__pycache__/
*.pyc
.venv/

# Backups
*.backup
backups/

# Secrets (절대 커밋하지 말 것)
*.key
*.pem
credentials.json
```

### 4.4 Makefile

```makefile
.PHONY: help up down restart logs ps health setup test

help:
	@echo "LiteLLM Stack - Available Commands"
	@echo "=================================="
	@echo "make up        - Start all services"
	@echo "make down      - Stop all services"
	@echo "make restart   - Restart all services"
	@echo "make logs      - View logs"
	@echo "make ps        - Show running containers"
	@echo "make health    - Health check"
	@echo "make setup     - Auto setup models"
	@echo "make test      - Run integration tests"

up:
	@echo "Starting LiteLLM Stack..."
	docker compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 10
	@make health

down:
	docker compose down

restart:
	@make down
	@make up

logs:
	docker compose logs -f

ps:
	docker compose ps

health:
	@./scripts/health_check.sh

setup:
	@./scripts/setup_models.sh

test:
	@./tests/integration_test.sh
```

### 4.5 GitHub Actions CI/CD

**.github/workflows/ci.yml**

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Compose
        run: |
          docker compose version

      - name: Start services
        run: |
          docker compose up -d
          sleep 30

      - name: Health check
        run: |
          chmod +x scripts/health_check.sh
          ./scripts/health_check.sh

      - name: Integration tests
        run: |
          chmod +x tests/integration_test.sh
          ./tests/integration_test.sh

      - name: Cleanup
        if: always()
        run: |
          docker compose down -v
```

### 4.6 버전 관리 전략

#### Semantic Versioning

```text
v1.2.3
│ │ │
│ │ └─ Patch: 버그 수정, 설정 조정
│ └─── Minor: 새 모델 추가, 기능 추가
└───── Major: Breaking changes (API 변경, 구조 변경)
```

#### Git 태그 예시

```bash
# 마이너 버전 (새 모델 추가)
git tag -a v1.1.0 -m "Add llama-3-8b model support"
git push --tags

# 패치 버전 (버그 수정)
git tag -a v1.1.1 -m "Fix GPU memory leak"
git push --tags

# 메이저 버전 (Breaking change)
git tag -a v2.0.0 -m "Migrate to LiteLLM v2 API"
git push --tags
```

### 4.7 CHANGELOG.md

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Support for llama-3-70b model

## [1.1.0] - 2025-12-08

### Added
- Auto model setup script (`setup_models.sh`)
- Low/high spec PC detection
- Health check script

### Changed
- Merged tinyllama1 into main ollama service
- Updated to LiteLLM v1.73.0

### Fixed
- GPU memory leak on model switching

## [1.0.0] - 2025-12-01

### Added
- Initial release
- Ollama + LiteLLM integration
- Support for gpt-oss:20b, tinyllama, bge-m3
```

---

## 5. 대안: Multi-repo

### 5.1 언제 Multi-repo를 써야 하나?

**다음 중 하나라도 해당되면 Multi-repo 고려:**

1. **팀이 완전히 분리**
   - Infra팀: Ollama만 관리, GPU 최적화 전담
   - App팀: LiteLLM만 관리, 비즈니스 로직 전담

2. **Ollama를 여러 프로젝트에서 공유**
   - `project-a`, `project-b`, `project-c` 모두 같은 Ollama 사용
   - Ollama는 공용 인프라, LiteLLM은 프로젝트별

3. **릴리스 사이클이 완전히 다름**
   - Ollama: 월 1회 업데이트 (안정성 중시)
   - LiteLLM: 주 1회 업데이트 (빠른 기능 추가)

4. **보안/권한 요구사항**
   - Ollama: Infra팀만 접근 가능 (GPU 리소스 관리)
   - LiteLLM: 전체 개발팀 접근 가능

### 5.2 Multi-repo 구조 예시

#### Repository 1: ollama-infra

```text
ollama-infra/
├── docker-compose.yml
├── scripts/
│   └── setup_gpu.sh
└── docs/
    └── gpu_optimization.md
```

#### Repository 2: litellm-gateway

```text
litellm-gateway/
├── docker-compose.yml
├── litellm_settings.yml
└── docs/
    └── api_usage.md
```

#### 배포 방법

```bash
# 1. Ollama (Infra 팀)
cd ollama-infra
docker compose up -d

# 2. LiteLLM (App 팀)
cd litellm-gateway
# .env에서 OLLAMA_URL=http://ollama-server:11434
docker compose up -d
```

### 5.3 Multi-repo의 버전 관리

#### 의존성 명시 (DEPENDENCIES.md)

**litellm-gateway/DEPENDENCIES.md**

```markdown
# Dependencies

## Required Services

- **ollama-infra**: v1.2.0 or higher
  - Repository: https://github.com/yourteam/ollama-infra
  - Required models: gpt-oss:20b, tinyllama

## Compatibility Matrix

| litellm-gateway | ollama-infra | Notes |
|-----------------|--------------|-------|
| v2.0.0          | v1.2.0+      | ✅ Tested |
| v1.5.0          | v1.1.0+      | ✅ Tested |
| v1.0.0          | v1.0.0+      | ⚠️ Deprecated |
```

---

## 6. 의사결정 플로우차트

```text
시작: litellm + ollama 관리 방법?
│
├─ Q1: 같은 팀이 관리하나요?
│  ├─ Yes → Q2
│  └─ No → Multi-repo 고려
│
├─ Q2: 항상 함께 배포되나요?
│  ├─ Yes → Q3
│  └─ No → Multi-repo 고려
│
├─ Q3: Ollama를 다른 프로젝트에서도 쓰나요?
│  ├─ Yes → Multi-repo 고려
│  └─ No → ✅ Monorepo 추천
│
└─ Q4: 릴리스 사이클이 다른가요?
   ├─ Yes → Multi-repo 고려
   └─ No → ✅ Monorepo 추천
```

---

## 7. 최종 추천

### 7.1 현재 상황 분석

| 질문 | 답변 | Monorepo 점수 |
|------|------|---------------|
| 같은 팀이 관리? | Yes | +1 |
| 항상 함께 배포? | Yes | +1 |
| 단일 docker-compose? | Yes | +1 |
| 설정 파일 의존성? | Strong | +1 |
| Ollama 공유? | No | +1 |
| 릴리스 사이클 동일? | Yes | +1 |
| **총점** | | **6/6** |

### 7.2 결론

**✅ 강력 추천: Monorepo (단일 Repository)**

**추천 구조:**

```text
litellm-stack/
├── .git/
├── README.md
├── docker-compose.yml
├── litellm_settings.yml
├── Makefile
├── scripts/
│   ├── setup_models.sh
│   └── health_check.sh
├── docs/
│   └── architecture.md
└── tests/
    └── integration_test.sh
```

### 7.3 즉시 실행 가능한 마이그레이션

```bash
# 1. 새 Repository 생성
cd /home/bwyoon/para/project
mkdir litellm-stack
cd litellm-stack
git init

# 2. 기존 litellm 프로젝트 내용 복사
cp -r ../litellm/* .

# 3. devnet_env_setup의 문서만 병합
cp -r ../devnet_env_setup/docs ./docs-archive

# 4. 초기 커밋
git add .
git commit -m "Initial commit: Merge litellm + ollama into single stack"

# 5. GitHub에 푸시
git remote add origin https://github.com/dEitY719/litellm-stack
git push -u origin main

# 6. 기존 프로젝트 아카이브
mv ../litellm ../litellm.old
mv ../devnet_env_setup ../devnet_env_setup.old
```

---

## 8. 요약

| 기준 | Monorepo | Multi-repo |
|------|----------|------------|
| **관리 복잡도** | ⭐⭐⭐⭐⭐ 낮음 | ⭐⭐⭐ 중간 |
| **배포 단순성** | ⭐⭐⭐⭐⭐ 단순 | ⭐⭐ 복잡 |
| **버전 일관성** | ⭐⭐⭐⭐⭐ 보장 | ⭐⭐⭐ 관리 필요 |
| **팀 분리** | ⭐⭐⭐ CODEOWNERS | ⭐⭐⭐⭐⭐ 완전 분리 |
| **재사용성** | ⭐⭐⭐ 보통 | ⭐⭐⭐⭐⭐ 높음 |
| **현재 상황 적합성** | ⭐⭐⭐⭐⭐ 완벽 | ⭐⭐ 불필요 |

**최종 답변:**

> **✅ Monorepo (단일 Repository) 추천**
>
> 이유:
> 1. 이미 단일 `docker-compose.yml`로 통합됨
> 2. 같은 팀이 관리
> 3. 항상 함께 배포
> 4. 설정 파일 간 강한 의존성
> 5. 관리 복잡도 최소화
> 6. 버전 일관성 보장

**Repository 이름**: `litellm-stack` (추천)

---

**Happy Git Management! 🚀**
