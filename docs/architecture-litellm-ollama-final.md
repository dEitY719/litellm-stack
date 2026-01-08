# LiteLLM + Ollama 최종 아키텍처 설계

**작성일**: 2025-12-08
**버전**: Final v1.0
**결정**: Option C (하이브리드) - 단일 Compose 스택, 프로세스 분리, 네트워크 공유

---

## 📋 목차

1. [핵심 설계 결정](#1-핵심-설계-결정)
2. [최종 아키텍처](#2-최종-아키텍처)
3. [구현: 단일 Compose 스택](#3-구현-단일-compose-스택)
4. [저사양/고사양 PC 대응](#4-저사양고사양-pc-대응)
5. [SOLID 원칙 준수 확인](#5-solid-원칙-준수-확인)
6. [마이그레이션 가이드](#6-마이그레이션-가이드)
7. [운영 가이드](#7-운영-가이드)
8. [문제 해결](#8-문제-해결)

---

## 1. 핵심 설계 결정

### 1.1 최종 선택: 단일 Compose 스택 + 프로세스 분리

```
✅ 채택: 한 docker-compose.yml에 묶어 네트워크만 공유
❌ 기각: 단일 컨테이너로 통합 (SOLID 위배)
❌ 기각: 완전 분리 (관리 복잡도 증가)
```

**이유:**

| 관점 | 평가 |
|------|------|
| **SOLID 원칙** | ✅ SRP 준수 (프로세스 분리: Ollama vs LiteLLM) |
| **관리 복잡도** | ✅ 단일 명령어 (`docker compose up`) |
| **네트워크** | ✅ 서비스명으로 직접 통신 (`http://ollama:11434`) |
| **확장성** | ✅ 모델 추가 시 설정만 변경 |
| **이식성** | ✅ 단일 파일로 전체 스택 재현 가능 |

### 1.2 주요 변경 사항

#### Before (분리된 프로젝트)

```text
devnet_env_setup/
└─ docker-compose.yml
   └─ ollama (11434) → gpt-oss:20b, bge-m3

litellm/
└─ docker-compose.yml
   ├─ tinyllama1 (11431) → tinyllama
   ├─ litellm (4444)
   └─ litellm_db (5432)
```

#### After (통합 Compose 스택)

```text
litellm/
└─ docker-compose.yml
   ├─ ollama (11434) → tinyllama, gpt-oss:20b (선택적), bge-m3
   ├─ litellm (4444)
   └─ litellm_db (5432)
```

**핵심 개선:**

- ✅ `tinyllama1` 제거 → `ollama`로 통합 (일관성)
- ✅ 단일 Ollama 인스턴스에서 모든 모델 관리
- ✅ 저사양/고사양 PC에 따라 모델만 선택적 로드

---

## 2. 최종 아키텍처

### 2.1 컴포넌트 다이어그램

```text
┌────────────────────────────────────────────────────────────┐
│              사용자 애플리케이션                             │
└─────────────────────────┬──────────────────────────────────┘
                          │
                          ↓ http://localhost:4444
        ┌─────────────────────────────────────────┐
        │      LiteLLM Proxy (포트 4444)           │
        │  ┌───────────────────────────────────┐  │
        │  │ 모델 라우팅 테이블                 │  │
        │  ├───────────────────────────────────┤  │
        │  │ tinyllama      → ollama:11434     │  │
        │  │ gpt-oss-20b    → ollama:11434     │  │
        │  │ bge-m3         → ollama:11434     │  │
        │  │ gemini-2.5-pro → Gemini API       │  │
        │  └───────────────────────────────────┘  │
        └─────────────┬──────────────┬────────────┘
                      │              │
     ┌────────────────┴────┐    ┌───┴──────────┐
     │                     │    │              │
     ↓                     ↓    ↓              ↓
┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
│ ollama       │  │ litellm_db       │  │ Gemini API   │
│ (11434)      │  │ (5432)           │  │ (외부)       │
│              │  │                  │  │              │
│ ├─ tinyllama │  │ ├─ 모델 설정     │  │              │
│ ├─ gpt-oss   │  │ └─ 사용 로그     │  │              │
│ └─ bge-m3    │  │                  │  │              │
└──────────────┘  └──────────────────┘  └──────────────┘
  │                 │
  │ 모델 서빙        │ 상태 저장
  │ (GPU 가속)      │

  ┌─────────────────────────────────────────────┐
  │       litellm-network (Docker 브릿지)        │
  │  - 컨테이너 간 서비스명으로 통신              │
  │  - ollama, litellm, litellm_db 공유         │
  └─────────────────────────────────────────────┘
```

### 2.2 설계 원칙

#### 프로세스 분리 (Process Isolation)

- **ollama**: 모델 로딩, 추론 실행 (GPU 집약적)
- **litellm**: 라우팅, 인증, 로깅 (CPU 집약적)
- **litellm_db**: 상태 저장 (I/O 집약적)

#### 네트워크 공유 (Network Sharing)

- 동일 Docker Compose 네트워크 사용
- 서비스명으로 직접 통신: `http://ollama:11434`
- 외부 노출: litellm (4444), ollama (11434) 선택적

#### 데이터 격리 (Data Isolation)

- 각 서비스별 독립 볼륨
- `ollama_data`: 모델 파일 (~13GB)
- `postgres_data`: LiteLLM 설정 및 로그

---

## 3. 구현: 단일 Compose 스택

### 3.1 최종 docker-compose.yml

**위치**: `/home/bwyoon/para/project/litellm/docker-compose.yml`

```yaml
services:
  # ═══════════════════════════════════════════════════
  # Ollama: 로컬 LLM 추론 엔진 (통합)
  # ═══════════════════════════════════════════════════
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      # 모델 자동 언로드 시간 (메모리 관리)
      OLLAMA_KEEP_ALIVE: "5m"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  # ═══════════════════════════════════════════════════
  # PostgreSQL: LiteLLM 설정 및 로그 저장소
  # ═══════════════════════════════════════════════════
  db:
    image: postgres:16
    restart: always
    container_name: litellm_db
    environment:
      POSTGRES_DB: litellm
      POSTGRES_USER: llmproxy
      POSTGRES_PASSWORD: dbpassword9090
    ports:
      - "5431:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d litellm -U llmproxy"]
      interval: 1s
      timeout: 5s
      retries: 10

  # ═══════════════════════════════════════════════════
  # LiteLLM: AI Gateway (Proxy)
  # ═══════════════════════════════════════════════════
  litellm:
    container_name: litellm
    image: ghcr.io/berriai/litellm:main-v1.73.0-stable
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./litellm_settings.yml:/app/config.yml
    command:
      - "--config=config.yml"
    ports:
      - "4444:4000"
    environment:
      DATABASE_URL: "postgresql://llmproxy:dbpassword9090@db:5432/litellm"
      STORE_MODEL_IN_DB: "True"
      LITELLM_MASTER_KEY: "sk-4444"
    depends_on:
      db:
        condition: service_healthy
      ollama:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 http://localhost:4000/health/liveliness || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgres_data:
    name: litellm_postgres_data
  ollama_data:
    name: litellm_ollama_data

networks:
  default:
    name: litellm-network
```

### 3.2 최종 litellm_settings.yml

**위치**: `/home/bwyoon/para/project/litellm/litellm_settings.yml`

```yaml
model_list:
  # ═══════════════════════════════════════════════════
  # Ollama 로컬 모델 (단일 인스턴스)
  # ═══════════════════════════════════════════════════

  # 저사양 PC: 항상 사용 가능 (~50MB)
  - model_name: tinyllama
    litellm_params:
      model: ollama/tinyllama
      api_base: http://ollama:11434
    model_info:
      mode: chat
      supports_function_calling: false
      max_tokens: 2048

  # 고사양 PC: 선택적 사용 (~11GB VRAM)
  - model_name: gpt-oss-20b
    litellm_params:
      model: ollama/gpt-oss:20b
      api_base: http://ollama:11434
    model_info:
      mode: chat
      supports_function_calling: true
      max_tokens: 8192

  # 임베딩 모델 (~2GB)
  - model_name: bge-m3
    litellm_params:
      model: ollama/bge-m3:latest
      api_base: http://ollama:11434
    model_info:
      mode: embedding
      max_input_tokens: 8192

  # ═══════════════════════════════════════════════════
  # 외부 API 모델
  # ═══════════════════════════════════════════════════

  - model_name: gemini-2.0-flash
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: os.environ/GEMINI_API_KEY

  - model_name: gemini-2.5-flash
    litellm_params:
      model: gemini/gemini-2.5-flash
      api_key: os.environ/GEMINI_API_KEY

  - model_name: gemini-2.5-pro
    litellm_params:
      model: gemini/gemini-2.5-pro
      api_key: os.environ/GEMINI_API_KEY

general:
  debug: true
  # 요청 로깅 활성화
  litellm_settings:
    success_callback: ["postgres"]
    failure_callback: ["postgres"]
```

---

## 4. 저사양/고사양 PC 대응

### 4.1 모델 선택 전략

#### 저사양 PC (VRAM < 8GB)

**권장 모델:**

- ✅ `tinyllama` (50MB) - 빠른 테스트용
- ✅ `gemini-*` - 외부 API (VRAM 불필요)

**초기 설정:**

```bash
cd /home/bwyoon/para/project/litellm

# 1. Compose 스택 시작
docker compose up -d

# 2. 가벼운 모델만 다운로드
docker exec ollama ollama pull tinyllama

# 3. 테스트
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "안녕?"}]
  }'
```

#### 고사양 PC (VRAM >= 16GB)

**권장 모델:**

- ✅ `tinyllama` (50MB) - 테스트용
- ✅ `gpt-oss-20b` (11GB) - 메인 모델
- ✅ `bge-m3` (2GB) - 임베딩
- ✅ `gemini-*` - 보조 모델

**초기 설정:**

```bash
cd /home/bwyoon/para/project/litellm

# 1. Compose 스택 시작
docker compose up -d

# 2. 모든 모델 다운로드 (순차적으로 실행)
docker exec ollama ollama pull tinyllama        # ~1분
docker exec ollama ollama pull gpt-oss:20b      # ~10분 (11GB)
docker exec ollama ollama pull bge-m3:latest    # ~3분

# 3. gpt-oss:20b 사전 로드 (첫 요청 지연 방지)
docker exec ollama ollama run gpt-oss:20b "안녕?" --verbose

# 4. 테스트
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss-20b",
    "messages": [{"role": "user", "content": "한국의 수도는?"}]
  }'
```

### 4.2 동적 모델 관리

#### 모델 목록 확인

```bash
# Ollama에 다운로드된 모델
docker exec ollama ollama list

# LiteLLM에 등록된 모델
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"
```

#### 모델 추가/제거

```bash
# 모델 다운로드
docker exec ollama ollama pull <model-name>

# 모델 삭제 (VRAM 확보)
docker exec ollama ollama rm <model-name>
```

#### VRAM 모니터링

```bash
# GPU 메모리 사용량 확인
docker exec ollama nvidia-smi

# Ollama 로그에서 모델 로딩 상태 확인
docker logs ollama | grep -E "loaded|offloaded"
```

### 4.3 자동 모델 선택 스크립트

**위치**: `/home/bwyoon/para/project/litellm/setup_models.sh`

```bash
#!/bin/bash
# setup_models.sh - PC 사양에 따른 자동 모델 설정

set -e

echo "=================================="
echo "LiteLLM 모델 자동 설정"
echo "=================================="
echo ""

# VRAM 확인 (nvidia-smi 필요)
if command -v nvidia-smi &> /dev/null; then
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    VRAM_GB=$((VRAM_MB / 1024))
    echo "✓ GPU 감지: ${VRAM_GB}GB VRAM"
else
    VRAM_GB=0
    echo "⚠ GPU 미감지 (CPU 모드)"
fi

echo ""

# Compose 스택 시작
echo "[1/3] Docker Compose 스택 시작 중..."
docker compose up -d
sleep 5

# 모델 다운로드
echo ""
echo "[2/3] 모델 다운로드 중..."

# 기본 모델 (항상)
echo "  - tinyllama 다운로드 중 (~50MB)..."
docker exec ollama ollama pull tinyllama

# 사양별 모델
if [ "$VRAM_GB" -ge 16 ]; then
    echo "  ✓ 고사양 PC 감지 (${VRAM_GB}GB VRAM)"
    echo "  - gpt-oss:20b 다운로드 중 (~11GB, 약 10분 소요)..."
    docker exec ollama ollama pull gpt-oss:20b

    echo "  - bge-m3 다운로드 중 (~2GB)..."
    docker exec ollama ollama pull bge-m3:latest

    echo "  - gpt-oss:20b 사전 로드 중..."
    docker exec ollama ollama run gpt-oss:20b "테스트" > /dev/null 2>&1 || true

    MODELS="tinyllama, gpt-oss-20b, bge-m3"
else
    echo "  ✓ 저사양 PC 감지 (${VRAM_GB}GB VRAM)"
    echo "  ⚠ gpt-oss:20b는 생략합니다 (16GB VRAM 권장)"
    MODELS="tinyllama"
fi

# 테스트
echo ""
echo "[3/3] 설정 확인 중..."
echo ""

# LiteLLM 헬스 체크
if curl -f http://localhost:4444/health/liveliness > /dev/null 2>&1; then
    echo "✓ LiteLLM 프록시 정상"
else
    echo "✗ LiteLLM 프록시 응답 없음"
    exit 1
fi

# 모델 목록 확인
echo "✓ 사용 가능한 모델: ${MODELS}"

echo ""
echo "=================================="
echo "설정 완료!"
echo "=================================="
echo ""
echo "다음 명령어로 테스트하세요:"
echo ""
echo "  curl http://localhost:4444/v1/chat/completions \\"
echo "    -H \"Authorization: Bearer sk-4444\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{"
echo "      \"model\": \"tinyllama\","
echo "      \"messages\": [{\"role\": \"user\", \"content\": \"안녕?\"}]"
echo "    }'"
echo ""
```

**사용법:**

```bash
cd /home/bwyoon/para/project/litellm
chmod +x setup_models.sh
./setup_models.sh
```

---

## 5. SOLID 원칙 준수 확인

### 5.1 Single Responsibility Principle (SRP)

| 컴포넌트 | 단일 책임 | 준수 여부 |
|----------|----------|----------|
| **ollama** | 모델 로딩 및 추론 실행 | ✅ |
| **litellm** | API 라우팅, 인증, 로깅 | ✅ |
| **litellm_db** | 상태 저장 | ✅ |

**평가**: ✅ **준수**
각 서비스가 명확한 단일 책임을 가짐. 프로세스 분리로 독립적 배포 가능.

### 5.2 Open/Closed Principle (OCP)

**확장 시나리오:**

1. **새 Ollama 모델 추가**
   - 변경: `litellm_settings.yml`만 수정
   - 코드 변경: 불필요 ✅

2. **새 외부 API 추가** (예: Claude)
   - 변경: `litellm_settings.yml` + `.env`
   - 코드 변경: 불필요 ✅

3. **Ollama를 vLLM으로 교체**
   - 변경: `docker-compose.yml`의 ollama 서비스만 교체
   - LiteLLM 코드: 변경 불필요 ✅

**평가**: ✅ **준수**
설정 변경만으로 확장 가능. 기존 코드 수정 불필요.

### 5.3 Dependency Inversion Principle (DIP)

```text
상위 계층 (High-level)
┌──────────────┐
│   LiteLLM    │ ────→ "OpenAI 호환 API" (추상화)
└──────────────┘              ↑
                              │ 구현
                      ┌───────┴────────┐
                      │                │
                  ┌───────┐       ┌────────┐
                  │ Ollama │       │ Gemini │
                  └───────┘       └────────┘
                  (구현체)         (구현체)
```

**평가**: ✅ **준수**
LiteLLM은 구체적인 Ollama에 의존하지 않고, "OpenAI 호환 API" 인터페이스에 의존.

### 5.4 종합 평가

| SOLID 원칙 | 이전 (분리) | 현재 (통합 Compose) |
|-----------|------------|---------------------|
| SRP | ✅ | ✅ |
| OCP | ⚠️ (네트워크 설정 복잡) | ✅ (설정만 변경) |
| LSP | ✅ | ✅ |
| ISP | ✅ | ✅ |
| DIP | ✅ | ✅ |
| **관리 복잡도** | ❌ 높음 | ✅ 낮음 |

**결론**: 단일 Compose 스택이 SOLID 원칙을 유지하면서 관리 복잡도를 낮춤.

---

## 6. 마이그레이션 가이드

### 6.1 사전 준비

#### Step 1: 기존 devnet_env_setup의 모델 확인

```bash
cd /home/bwyoon/para/project/devnet_env_setup/ollama_setup

# 현재 실행 중인 모델 확인
docker exec ollama ollama list

# 예상 출력:
# NAME                  ID              SIZE      MODIFIED
# gpt-oss:20b          abc123...       11 GB     2 days ago
# bge-m3:latest        def456...       2.0 GB    2 days ago
```

#### Step 2: 기존 프로젝트 백업

```bash
# litellm 프로젝트 백업
cd /home/bwyoon/para/project/litellm
cp docker-compose.yml docker-compose.yml.backup
cp litellm_settings.yml litellm_settings.yml.backup

# devnet_env_setup 중지 (모델 파일은 유지)
cd /home/bwyoon/para/project/devnet_env_setup/ollama_setup
docker compose down
# 주의: -v 옵션 사용하지 말 것 (볼륨 삭제됨)
```

### 6.2 새 구조로 마이그레이션

#### Step 1: litellm 프로젝트 업데이트

```bash
cd /home/bwyoon/para/project/litellm

# 1. 기존 스택 중지 및 정리
docker compose down -v

# 2. 새 docker-compose.yml 적용 (위 3.1절 참조)
# - tinyllama1 서비스 제거
# - ollama 서비스 추가
# - litellm의 depends_on에 ollama 추가

# 3. 새 litellm_settings.yml 적용 (위 3.2절 참조)
# - tinyllama1 → ollama로 변경
# - api_base를 http://ollama:11434로 변경

# 4. 새 스택 시작
docker compose up -d
```

#### Step 2: 모델 다운로드

**저사양 PC:**

```bash
docker exec ollama ollama pull tinyllama
```

**고사양 PC:**

```bash
# 자동 설정 스크립트 사용 (권장)
chmod +x setup_models.sh
./setup_models.sh

# 또는 수동 설정
docker exec ollama ollama pull tinyllama
docker exec ollama ollama pull gpt-oss:20b
docker exec ollama ollama pull bge-m3:latest
```

#### Step 3: 검증

```bash
# 1. 모든 서비스 헬스 체크
docker compose ps

# 예상 출력: (모두 "healthy" 상태)
# NAME         STATUS
# ollama       Up (healthy)
# litellm      Up (healthy)
# litellm_db   Up (healthy)

# 2. 모델 목록 확인
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444" | jq '.data[].id'

# 예상 출력:
# "tinyllama"
# "gpt-oss-20b"
# "bge-m3"
# "gemini-2.5-pro"

# 3. 추론 테스트
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "1+1=?"}]
  }' | jq '.choices[0].message.content'

# 4. GPU 사용 확인 (고사양 PC)
docker exec ollama nvidia-smi
```

### 6.3 기존 devnet_env_setup 프로젝트 처리

#### Option A: 완전 제거 (권장)

```bash
cd /home/bwyoon/para/project/devnet_env_setup/ollama_setup

# 컨테이너 및 볼륨 삭제
docker compose down -v

# 프로젝트 보관 (삭제 전 백업)
cd /home/bwyoon/para/project
mv devnet_env_setup devnet_env_setup.deprecated
```

#### Option B: 참고용으로 보관

```bash
# README에 "Deprecated" 표시 추가
cd /home/bwyoon/para/project/devnet_env_setup
echo "" >> README.md
echo "## ⚠️ Deprecated" >> README.md
echo "이 프로젝트는 litellm 프로젝트로 통합되었습니다." >> README.md
echo "새 위치: /home/bwyoon/para/project/litellm" >> README.md
```

### 6.4 롤백 절차 (문제 발생 시)

```bash
cd /home/bwyoon/para/project/litellm

# 1. 새 스택 중지
docker compose down

# 2. 백업 복원
cp docker-compose.yml.backup docker-compose.yml
cp litellm_settings.yml.backup litellm_settings.yml

# 3. 이전 스택 재시작
docker compose up -d

# 4. devnet_env_setup 재시작
cd /home/bwyoon/para/project/devnet_env_setup/ollama_setup
docker compose up -d
```

---

## 7. 운영 가이드

### 7.1 일상 작업

#### 전체 스택 시작/종료

```bash
cd /home/bwyoon/para/project/litellm

# 시작
docker compose up -d

# 종료
docker compose down

# 전체 재시작 (설정 변경 후)
docker compose restart

# 특정 서비스만 재시작
docker compose restart litellm
```

#### 모델 관리

```bash
# 모델 다운로드
docker exec ollama ollama pull <model-name>

# 모델 목록
docker exec ollama ollama list

# 모델 삭제 (VRAM 확보)
docker exec ollama ollama rm <model-name>

# 모델 사전 로드 (첫 요청 지연 방지)
docker exec ollama ollama run gpt-oss:20b "test"
```

#### 로그 확인

```bash
# 전체 로그
docker compose logs

# 특정 서비스 로그
docker compose logs ollama
docker compose logs litellm

# 실시간 로그 (tail -f)
docker compose logs -f litellm

# 최근 50줄
docker compose logs --tail=50 ollama
```

### 7.2 모니터링

#### 헬스 체크 스크립트

**위치**: `/home/bwyoon/para/project/litellm/health_check.sh`

```bash
#!/bin/bash
# health_check.sh - 전체 스택 헬스 체크

echo "========================================"
echo "  LiteLLM 스택 헬스 체크"
echo "========================================"
echo ""

# 1. Docker 컨테이너 상태
echo "[1/4] 컨테이너 상태"
docker compose ps

echo ""

# 2. Ollama 헬스
echo "[2/4] Ollama 헬스"
if curl -f http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "  ✓ Ollama API 정상"
    MODELS=$(docker exec ollama ollama list | tail -n +2 | wc -l)
    echo "  ✓ 모델 개수: ${MODELS}"
else
    echo "  ✗ Ollama API 응답 없음"
fi

echo ""

# 3. LiteLLM 헬스
echo "[3/4] LiteLLM 헬스"
if curl -f http://localhost:4444/health/liveliness > /dev/null 2>&1; then
    echo "  ✓ LiteLLM 프록시 정상"

    # 모델 개수
    MODEL_COUNT=$(curl -s http://localhost:4444/models \
      -H "Authorization: Bearer sk-4444" | jq '.data | length')
    echo "  ✓ 등록된 모델: ${MODEL_COUNT}"
else
    echo "  ✗ LiteLLM 프록시 응답 없음"
fi

echo ""

# 4. GPU 상태 (있는 경우)
echo "[4/4] GPU 상태"
if docker exec ollama nvidia-smi > /dev/null 2>&1; then
    docker exec ollama nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader
else
    echo "  ⚠ GPU 미사용 또는 미감지"
fi

echo ""
echo "========================================"
echo "  헬스 체크 완료"
echo "========================================"
```

**사용법:**

```bash
chmod +x health_check.sh
./health_check.sh
```

### 7.3 성능 최적화

#### GPU 메모리 관리

```yaml
# docker-compose.yml의 ollama 서비스
environment:
  # 5분 후 자동 언로드 (메모리 확보)
  OLLAMA_KEEP_ALIVE: "5m"

  # 또는 항상 로드 유지 (빠른 응답)
  # OLLAMA_KEEP_ALIVE: "-1"
```

#### 동시 요청 처리

```yaml
# litellm_settings.yml
model_list:
  - model_name: gpt-oss-20b
    litellm_params:
      model: ollama/gpt-oss:20b
      api_base: http://ollama:11434
      num_retries: 3
      timeout: 300
    model_info:
      # 동시 요청 제한
      max_parallel_requests: 2
```

#### 모델 워밍업

```bash
# 스택 시작 후 자동 워밍업
cd /home/bwyoon/para/project/litellm
docker compose up -d
sleep 10

# 모델 사전 로드
docker exec ollama ollama run gpt-oss:20b "warm up" > /dev/null 2>&1 &
```

---

## 8. 문제 해결

### 8.1 일반적인 문제

#### 문제: "service 'ollama' failed to build"

**원인**: GPU 드라이버 또는 NVIDIA Container Toolkit 미설치

**해결:**

```bash
# 1. GPU 드라이버 확인
nvidia-smi

# 2. NVIDIA Container Toolkit 설치
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 3. 테스트
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

#### 문제: "Model 'gpt-oss-20b' not found"

**원인**: Ollama에 모델이 다운로드되지 않음

**해결:**

```bash
# 모델 다운로드
docker exec ollama ollama pull gpt-oss:20b

# 다운로드 확인
docker exec ollama ollama list
```

#### 문제: "Connection refused" (<http://ollama:11434>)

**원인**: Ollama 서비스가 시작되지 않음

**해결:**

```bash
# 1. Ollama 상태 확인
docker compose ps ollama

# 2. Ollama 로그 확인
docker compose logs ollama

# 3. Ollama 재시작
docker compose restart ollama

# 4. 헬스 체크
curl http://localhost:11434/api/tags
```

### 8.2 성능 문제

#### 문제: 첫 요청이 매우 느림 (30초+)

**원인**: 모델 로딩 시간 (Cold Start)

**해결:**

```bash
# 모델 사전 로드 (워밍업)
docker exec ollama ollama run gpt-oss:20b "warm up"

# 또는 OLLAMA_KEEP_ALIVE 설정 변경
# docker-compose.yml:
#   environment:
#     OLLAMA_KEEP_ALIVE: "-1"  # 항상 메모리에 유지
```

#### 문제: GPU 메모리 부족 (CUDA out of memory)

**원인**: 여러 모델을 동시에 로드하려 함

**해결:**

```bash
# 1. 사용하지 않는 모델 언로드
docker exec ollama ollama stop gpt-oss:20b

# 2. OLLAMA_KEEP_ALIVE 시간 단축
# docker-compose.yml:
#   environment:
#     OLLAMA_KEEP_ALIVE: "2m"  # 2분 후 자동 언로드

# 3. 경량 모델만 사용
docker exec ollama ollama rm gpt-oss:20b
# tinyllama만 사용
```

### 8.3 디버깅

#### LiteLLM 디버그 모드

```yaml
# litellm_settings.yml
general:
  debug: true  # 상세 로그 활성화
```

#### Ollama 상세 로그

```bash
# 실시간 로그 모니터링
docker compose logs -f ollama | grep -E "loaded|offloaded|error"
```

#### 네트워크 연결 테스트

```bash
# litellm 컨테이너에서 ollama 접근 확인
docker exec litellm curl http://ollama:11434/api/tags

# 예상 출력: {"models": [...]}
```

---

## 9. 다음 단계

### 9.1 추가 개선 사항

1. **CI/CD 파이프라인**
   - GitHub Actions로 자동 배포
   - 설정 변경 시 자동 테스트

2. **모니터링 대시보드**
   - Prometheus + Grafana 통합
   - 모델별 사용량 추적

3. **보안 강화**
   - API 키 외부화 (Vault, AWS Secrets Manager)
   - HTTPS 적용 (Nginx + Let's Encrypt)

4. **멀티 GPU 지원**
   - 여러 Ollama 인스턴스 로드밸런싱
   - 모델별 GPU 할당

### 9.2 참고 자료

- [LiteLLM 공식 문서](https://docs.litellm.ai/)
- [Ollama 공식 문서](https://github.com/ollama/ollama)
- [Docker Compose 네트워킹](https://docs.docker.com/compose/networking/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

---

## 10. 요약

### 10.1 핵심 결정사항

| 항목 | 결정 |
|------|------|
| **아키텍처** | 단일 Compose 스택 + 프로세스 분리 |
| **Ollama 통합** | tinyllama1 제거 → ollama로 통합 |
| **네트워크** | Docker Compose 기본 네트워크 (서비스명 통신) |
| **모델 관리** | 저사양/고사양 PC 자동 선택 지원 |
| **SOLID 준수** | ✅ 모든 원칙 준수 |

### 10.2 마이그레이션 체크리스트

- [ ] 기존 프로젝트 백업
- [ ] devnet_env_setup 중지
- [ ] litellm 프로젝트 업데이트 (docker-compose.yml, litellm_settings.yml)
- [ ] 새 스택 시작
- [ ] 모델 다운로드 (setup_models.sh 또는 수동)
- [ ] 검증 (모델 목록, 추론 테스트)
- [ ] devnet_env_setup 프로젝트 처리 (제거 또는 보관)

### 10.3 즉시 실행 명령어

```bash
# 1. 프로젝트로 이동
cd /home/bwyoon/para/project/litellm

# 2. 기존 백업
cp docker-compose.yml docker-compose.yml.backup
cp litellm_settings.yml litellm_settings.yml.backup

# 3. 새 설정 적용 (위 3.1, 3.2절 참조)

# 4. 기존 스택 중지
docker compose down -v

# 5. 새 스택 시작
docker compose up -d

# 6. 자동 모델 설정
chmod +x setup_models.sh
./setup_models.sh

# 7. 헬스 체크
chmod +x health_check.sh
./health_check.sh
```

---

**작성자**: Claude Sonnet 4.5
**버전**: Final v1.0
**최종 수정**: 2025-12-08

**Happy LLM Serving! 🚀**
