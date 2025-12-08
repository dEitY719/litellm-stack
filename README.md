# LiteLLM Stack

> 로컬 LLM + AI Gateway 통합 스택

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Ollama](https://img.shields.io/badge/Ollama-GPU-green.svg)](https://github.com/ollama/ollama)

## 개요

Ollama (로컬 LLM)와 LiteLLM (AI Gateway)을 단일 Docker Compose 스택으로 통합한 프로젝트입니다.

### 주요 컴포넌트

- **Ollama**: gpt-oss:20b, tinyllama, bge-m3 등 로컬 모델 서빙 (GPU 가속 지원)
- **LiteLLM**: 통합 API Gateway (Ollama + Gemini + OpenAI + ...)
- **PostgreSQL**: LiteLLM 설정 및 로그 저장소

### 아키텍처

```text
사용자 애플리케이션
        ↓
   LiteLLM Proxy (4444)
     /    |    \
    /     |     \
Ollama  Gemini  OpenAI
(11434)  (API)   (API)
```

## 빠른 시작

### 사전 요구사항

- Docker 및 Docker Compose v2+
- NVIDIA GPU + 드라이버 (선택적, GPU 가속용)
- 최소 8GB RAM (16GB 권장)

### 설치

```bash
# 1. Clone
git clone https://github.com/dEitY719/litellm-stack
cd litellm-stack

# 2. 환경 변수 설정
cp .env.example .env
# .env 파일에서 GEMINI_API_KEY 등 설정

# 3. 스택 시작
docker compose up -d

# 4. 모델 자동 설정 (저사양/고사양 PC 자동 감지)
chmod +x scripts/setup_models.sh
./scripts/setup_models.sh

# 5. 헬스 체크
chmod +x scripts/health_check.sh
./scripts/health_check.sh
```

### 빠른 테스트

#### 1️⃣ curl로 테스트 (간단함)

```bash
# 모델 목록 확인
curl http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"

# tinyllama 테스트 (저사양 PC)
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "messages": [{"role": "user", "content": "안녕?"}]
  }'

# gpt-oss:20b 테스트 (고사양 PC, 16GB VRAM)
curl http://localhost:4444/v1/chat/completions \
  -H "Authorization: Bearer sk-4444" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss-20b",
    "messages": [{"role": "user", "content": "한국의 수도는?"}]
  }'
```

#### 2️⃣ Python으로 테스트 (권장)

**사전 요구사항:**

```bash
# 필요한 패키지 설치
pip install openai langchain langchain-openai python-dotenv

# 또는 requirements.txt에서 설치
pip install -r requirements.txt
```

**Test 1: OpenAI SDK 직접 사용**

```bash
cd example
python test_openai.py
```

**출력 예시:**
```
I'm doing well—thanks for asking! How can I help you today?
```

**Test 2: LangChain 사용 (Streaming + Chat)**

```bash
cd example
python test_langchain_openai.py
```

**출력 예시:**
```
## 한국의 4계절(季節) 개요

한국은 **고리성 대륙성 기후**와 **해양성 기후**가 복합적으로 섞여 있는 곳이기 때문에,
4계절이 뚜렷하지만 지역에 따라 기온·강수량 차이가 큽니다. ...

AIMessage(content='안녕하세요! 무엇을 도와드릴까요?', response_metadata={...})
```

**Python 예제 파일 위치:**

```text
example/
├── test_openai.py             # OpenAI SDK 예제
└── test_langchain_openai.py   # LangChain 예제
└── test_langchain_agent.py    # Agent 예제
```

**사용 시 주의사항:**

- LiteLLM API URL: `http://localhost:4444`
- API Key: `sk-4444` (기본값)
- 모델명: `gpt-oss-20b`, `tinyllama`, `bge-m3` 등
- 기본 헤더 설정은 예제 파일에서 커스터마이징 가능

#### 3️⃣ 통합 설정 검증 (전체 시스템 확인)

```bash
./scripts/test_setup.sh
```

**검증 항목:**

```
[1/5] Docker 컨테이너 상태 확인
  ✓ LiteLLM 서비스 실행 중
  ✓ Ollama 서비스 실행 중

[2/5] LiteLLM 프록시 헬스체크
  ✓ LiteLLM 프록시 응답 정상

[3/5] 사용 가능한 모델 확인
  ✓ Gemini 모델 등록됨
  ✓ Ollama 로컬 모델 등록됨

[4/5] Python 패키지 확인
  ✓ langchain 설치됨
  ✓ langchain-community 설치됨
  ✓ litellm 설치됨

[5/5] LiteLLM API 요청 테스트
  ✓ API 요청 성공

✓ 모든 테스트 완료!
```

#### 4️⃣ LangChain Agent 실행 (AI 에이전트 테스트)

**준비:**

```bash
# 필요한 패키지 설치
pip install -r requirements.txt

# 또는 uv 사용
uv sync
```

**실행:**

```bash
python example/test_langchain_agent.py
```

**출력 예시:**

```
Agent initialized with Ollama backend
Agent: "Let me analyze this information..."

Response: "Here's my analysis of the Korean cultural context..."

Tool usage: Retrieved context from knowledge base
Final answer: "Based on the information provided..."
```

**LangChain Agent 특징:**

- 🤖 **자동 추론**: 복잡한 작업을 단계별로 해결
- 🔗 **Tool 호출**: 필요시 자동으로 외부 API/도구 사용
- 💭 **Chain-of-thought**: 추론 과정을 설명하며 진행
- 📊 **상태 관리**: 이전 대화 컨텍스트 유지

**테스트 워크플로우:**

```bash
# 1단계: 전체 시스템 설정 확인
./scripts/test_setup.sh

# 2단계: 간단한 API 호출 테스트
cd example
python test_openai.py          # OpenAI SDK 직접 사용
python test_langchain_openai.py # LangChain 기본 사용

# 3단계: LangChain Agent 테스트
python test_langchain_agent.py  # 복잡한 추론 작업

# 4단계: 성능 모니터링
make health                      # 상세 시스템 상태 확인
```

## 주요 기능

### 로컬 LLM 서빙

- ✅ **GPU 가속 지원** (NVIDIA CUDA)
- ✅ **여러 모델 동시 관리** (tinyllama, gpt-oss:20b, bge-m3)
- ✅ **자동 메모리 관리** (OLLAMA_KEEP_ALIVE)
- ✅ **저사양/고사양 PC 자동 감지**

### AI Gateway

- ✅ **OpenAI 호환 API** (기존 코드 재사용 가능)
- ✅ **여러 LLM 통합** (Ollama, Gemini, OpenAI, Claude 등)
- ✅ **라우팅 및 로드밸런싱**
- ✅ **인증 및 로깅** (PostgreSQL)
- ✅ **비용 추적** (외부 API 사용량 모니터링)

### 운영 편의성

- ✅ **단일 docker-compose.yml**로 전체 스택 관리
- ✅ **자동 헬스 체크** (스크립트 제공)
- ✅ **통합 로깅** (모든 컴포넌트)
- ✅ **데이터 영속성** (Docker 볼륨)

## 사용법

### Makefile 명령어

```bash
# 초기 설정
make init              # .env 파일 + Volume 초기화

# Docker 관리
make up                # 전체 스택 시작
make down              # 전체 스택 종료
make restart           # 재시작
make rebuild           # clean + up

# 모델 관리
make setup-models      # 모델 자동 설정 (GPU 감지)

# 로깅 & 모니터링
make logs              # 전체 로그
make logs-follow       # 실시간 로그
make ps                # 컨테이너 상태
make health            # 헬스 체크 (상세 정보)

# 컨테이너 접속
make shell             # LiteLLM 셸 접속
make shell-db          # Database 셸 접속
make shell-ollama      # Ollama 셸 접속

# 정리
make clean             # 캐시 정리

# 도움말
make help              # 모든 명령어 확인
```

### 모델 관리

```bash
# 모델 다운로드
docker exec ollama ollama pull <model-name>

# 모델 목록
docker exec ollama ollama list

# 모델 삭제 (VRAM 확보)
docker exec ollama ollama rm <model-name>

# GPU 메모리 확인
docker exec ollama nvidia-smi
```

### 설정 변경

#### 새 Ollama 모델 추가

`litellm_settings.yml`을 수정:

```yaml
model_list:
  - model_name: llama-3-8b
    litellm_params:
      model: ollama/llama-3-8b
      api_base: http://ollama:11434
```

그 다음 재시작:

```bash
docker compose restart litellm
```

#### 외부 API 추가 (Gemini, OpenAI 등)

1. `.env`에 API 키 추가:

   ```bash
   GEMINI_API_KEY=your-api-key
   ```

2. `litellm_settings.yml`에 모델 추가:

   ```yaml
   - model_name: gemini-2.5-pro
     litellm_params:
       model: gemini/gemini-2.5-pro
       api_key: os.environ/GEMINI_API_KEY
   ```

3. 재시작:

   ```bash
   docker compose up -d --force-recreate litellm
   ```

## 문서

자세한 문서는 `docs/` 디렉토리를 참조하세요:

- [아키텍처 설계](docs/architecture-litellm-ollama-final.md) - 전체 아키텍처 및 설계 결정
- [Git Repository 전략](docs/git-repository-strategy.md) - Monorepo 관리 방법

## 시스템 요구사항

### 저사양 PC (최소)

- **CPU**: 4코어 이상
- **RAM**: 8GB
- **GPU**: 불필요 (CPU 모드)
- **디스크**: 10GB

**사용 가능한 모델:**

- tinyllama (~50MB)
- 외부 API (Gemini, OpenAI 등)

### 고사양 PC (권장)

- **CPU**: 8코어 이상
- **RAM**: 16GB 이상
- **GPU**: NVIDIA GPU 16GB+ VRAM
- **디스크**: 50GB

**사용 가능한 모델:**

- tinyllama (~50MB)
- gpt-oss:20b (~11GB)
- bge-m3 (~2GB)
- 외부 API (Gemini, OpenAI 등)

## 문제 해결

### GPU가 인식되지 않음

```bash
# 1. NVIDIA 드라이버 확인
nvidia-smi

# 2. Docker에서 GPU 테스트
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

# 3. NVIDIA Container Toolkit 설치 (미설치 시)
# docs/architecture-litellm-ollama-final.md의 8.1절 참조
```

### 모델이 느리게 응답함

```bash
# 모델 사전 로드 (Cold Start 방지)
docker exec ollama ollama run gpt-oss:20b "warm up"

# 또는 docker-compose.yml에서 OLLAMA_KEEP_ALIVE="-1" 설정
```

### LiteLLM이 응답하지 않음

```bash
# 헬스 체크
curl http://localhost:4444/health/liveliness

# 로그 확인
docker compose logs litellm

# 재시작
docker compose restart litellm
```

더 자세한 문제 해결은 [아키텍처 문서](docs/architecture-litellm-ollama-final.md)의 8장을 참조하세요.

## 개발

### 프로젝트 구조

```text
litellm-stack/
├── docker-compose.yml              # 전체 스택 정의
├── litellm_settings.yml            # LiteLLM 모델 설정
├── .env.example                    # 환경 변수 템플릿
├── Makefile                        # 편의 명령어 (make help 참조)
│
├── scripts/                        # 유틸리티 스크립트
│   ├── setup_models.sh             # 모델 자동 설정 (GPU 감지)
│   ├── health_check.sh             # 스택 헬스 체크
│   ├── list_models.sh              # LiteLLM 모델 목록
│   └── migrate.sh                  # Volume 마이그레이션
│
├── example/                        # Python 테스트 예제
│   ├── test_openai.py              # OpenAI SDK 예제
│   └── test_langchain_openai.py    # LangChain 예제
│
├── docs/                           # 상세 문서
│   ├── architecture-litellm-ollama-final.md
│   └── git-repository-strategy.md
│
├── src/                            # Python 클라이언트 코드
│   └── run_langchain_agent.py      # LangChain Agent 예제
│
└── tests/                          # 통합 테스트
```

### 기여 방법

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 버전 관리

이 프로젝트는 [Semantic Versioning](https://semver.org/)을 따릅니다.

- **Major (v2.0.0)**: Breaking changes (API 변경, 구조 변경)
- **Minor (v1.1.0)**: 새 기능 추가 (새 모델, 새 API 등)
- **Patch (v1.0.1)**: 버그 수정, 설정 조정

### 최신 릴리스

- **v1.0.0** (2025-12-08): 첫 안정 릴리스
  - Ollama + LiteLLM 통합
  - 저사양/고사양 PC 자동 감지
  - gpt-oss:20b, tinyllama, bge-m3 지원

## 라이선스

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 감사의 말

- [Ollama](https://github.com/ollama/ollama) - 로컬 LLM 추론 엔진
- [LiteLLM](https://github.com/BerriAI/litellm) - AI Gateway
- [Docker](https://www.docker.com/) - 컨테이너 플랫폼

## 지원

- **Issues**: [GitHub Issues](https://github.com/dEitY719/litellm-stack/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dEitY719/litellm-stack/discussions)

---

**Made with ❤️ by the community**
