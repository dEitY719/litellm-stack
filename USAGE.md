# LangChain 에이전트 사용 가이드

## 개요

`src/run_langchain_agent.py`는 LiteLLM 프록시를 통해 Gemini 모델을 사용하는 LangChain 기반 에이전트 예제입니다.

## 전제조건

### 1. Docker 서비스 실행 확인

```bash
# 모든 서비스가 실행 중인지 확인
docker compose ps

# 출력 예:
# NAME         IMAGE                                       STATUS
# litellm      ghcr.io/berriai/litellm:main-v1.73.0-stable Up (healthy)
# tinyllama1   ollama/ollama                               Up (healthy)
# litellm_db   postgres:16                                 Up (healthy)
```

서비스가 실행 중이 아니면 시작:

```bash
docker compose up -d
```

### 2. Gemini API 키 설정

`docker-compose.yml`에서 GEMINI_API_KEY를 설정해야 합니다:

```yaml
environment:
  GEMINI_API_KEY: "your-actual-gemini-api-key"
```

API 키는 [Google AI Studio](https://makersuite.google.com/app/apikey)에서 무료로 발급받을 수 있습니다.

설정 후 LiteLLM 재시작:

```bash
docker compose up -d --force-recreate litellm
```

### 3. 모델이 litellm_settings.yml에 등록되어 있는지 확인

```bash
cat litellm_settings.yml
```

출력에 `gemini-pro`가 포함되어 있어야 합니다:

```yaml
model_list:
  - model_name: gemini-pro
    litellm_params:
      model: gemini/gemini-pro
```

### 4. Python 패키지 확인

```bash
python -m pip list | grep -E "langchain|litellm"
```

필수 패키지:

- `langchain` (>= 1.0.0)
- `langchain-community` (>= 0.4.0)
- `litellm` (>= 1.34.0)
- `duckduckgo-search` (최신)

## 실행 방법

### 기본 실행

```bash
python src/run_langchain_agent.py
```

### 예상 출력

```
======================================================================
  LangChain 에이전트 (LiteLLM 프록시 기반)
======================================================================

[*] LiteLLM 프록시에서 Gemini 모델 초기화 중...
[*] 검색 도구 초기화 중...
[*] ReAct 프롬프트 템플릿 로드 중...
[✓] 에이전트 생성 완료

[?] 질문: 오늘 한국의 주요 뉴스는 무엇인가?

======================================================================

Entering new AgentExecutor...

> Entering new AgentExecutor...
[Agent가 문제를 분석하고 검색을 수행합니다...]

[✓] 답변:
[에이전트의 최종 답변이 출력됩니다]

[✓] 모든 테스트 완료!
```

## 트러블슈팅

### 오류: "Connection refused" 또는 "Connection timeout"

**원인**: LiteLLM 프록시가 실행 중이 아닙니다.

**해결**:

```bash
# 프록시 상태 확인
docker compose ps litellm

# 프록시 로그 확인
docker compose logs litellm

# 프록시 재시작
docker compose restart litellm

# 헬스체크
curl http://localhost:4444/health/liveliness
```

### 오류: "401 Unauthorized" 또는 "Invalid API key"

**원인**: GEMINI_API_KEY가 설정되지 않았거나 잘못되었습니다.

**해결**:

```bash
# docker-compose.yml에서 GEMINI_API_KEY 확인
grep "GEMINI_API_KEY" docker-compose.yml

# API 키 설정 후 재시작
docker compose up -d --force-recreate litellm

# 프록시 로그 확인
docker compose logs litellm | grep -i gemini
```

### 오류: "Model 'gemini-pro' not found"

**원인**: litellm_settings.yml에 gemini-pro가 등록되지 않았습니다.

**해결**:

```bash
# 사용 가능한 모델 확인
curl -X GET "http://localhost:4444/models" \
  -H "Authorization: Bearer sk-4444"

# litellm_settings.yml에 추가 후 LiteLLM 재시작
docker compose up -d --force-recreate litellm
```

### 오류: "LiteLLM 프록시가... 실행 중인지 확인"

**원인**: localhost:4444에 연결할 수 없습니다.

**해결**:

```bash
# 포트 포워딩 확인
docker compose ps litellm
# PORTS에 "0.0.0.0:4444->4000/tcp" 가 보여야 함

# 직접 테스트
curl http://localhost:4444/health/liveliness

# 방화벽 확인 (필요 시)
sudo ufw allow 4444
```

### 오류: "hub.pull() failed" 또는 "Cannot download prompt"

**원인**: LangChain Hub에서 ReAct 프롬프트를 다운로드할 수 없습니다.

**해결**:

```bash
# 네트워크 연결 확인
ping github.com

# 프록시 설정 필요 시 환경 변수 설정
export HTTP_PROXY=your_proxy
export HTTPS_PROXY=your_proxy

# 다시 실행
python src/run_langchain_agent.py
```

### 오류: "timeout" 또는 "No response from model"

**원인**: 모델 응답이 느립니다 (네트워크 또는 모델 처리 시간).

**해결**:

```bash
# Ollama 모델 상태 확인
docker exec -it tinyllama1 ollama list

# 모델이 로드되어 있는지 확인
docker exec -it tinyllama1 ollama show tinyllama

# 직접 Ollama 테스트
curl http://localhost:11431/api/generate -X POST \
  -H "Content-Type: application/json" \
  -d '{"model": "tinyllama", "prompt": "hello", "stream": false}'

# Timeout 값 증가 (code에서 수정 가능)
# timeout=30 을 더 큰 값으로 변경
```

## 커스터마이징

### 다른 모델 사용

`create_agent_with_gemini()` 함수에서 model 파라미터 변경:

```python
llm = ChatLiteLLM(
    model="tinyllama1",  # gemini-pro 대신 tinyllama1 사용
    api_base="http://localhost:4444",
    api_key="sk-4444",
)
```

### 다른 도구 추가

`create_agent_with_gemini()` 함수의 tools 리스트에 추가:

```python
from langchain_community.tools import DuckDuckGoSearchRun, WikipediaQueryRun

tools = [
    DuckDuckGoSearchRun(),
    WikipediaQueryRun(),
]
```

### 다른 질문으로 테스트

`main()` 함수에서 question1 수정:

```python
question1 = "서울의 날씨는 어떻습니까?"
```

## 성능 최적화

### 응답 속도 개선

1. **로컬 모델 사용**: gemini 대신 tinyllama 사용 (더 빠름)

   ```python
   model="tinyllama1"
   ```

2. **Temperature 낮추기**: 빠른 응답 (덜 창의적)

   ```python
   temperature=0.3
   ```

3. **Max tokens 낮추기**: 응답 길이 제한

   ```python
   max_tokens=1024
   ```

4. **Timeout 단축**: 느린 응답 제한

   ```python
   timeout=15
   ```

## 참고

- [LangChain 문서](https://python.langchain.com/)
- [LiteLLM 문서](https://docs.litellm.ai/)
- [Gemini API 문서](https://ai.google.dev/)
