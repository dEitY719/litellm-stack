#!/bin/bash

# LiteLLM 및 LangChain 에이전트 설정 테스트 스크립트

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LiteLLM + LangChain 에이전트 테스트${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 1. Docker 컨테이너 상태 확인
echo -e "${YELLOW}[1/5] Docker 컨테이너 상태 확인...${NC}"
if docker compose ps | grep -q "litellm.*Up"; then
    echo -e "${GREEN}✓ LiteLLM 서비스 실행 중${NC}"
else
    echo -e "${RED}✗ LiteLLM 서비스가 실행 중이 아닙니다${NC}"
    echo "  해결: docker compose up -d"
    exit 1
fi

if docker compose ps | grep -q "tinyllama1.*Up"; then
    echo -e "${GREEN}✓ Ollama 서비스 실행 중${NC}"
else
    echo -e "${RED}✗ Ollama 서비스가 실행 중이 아닙니다${NC}"
    echo "  해결: docker compose up -d"
    exit 1
fi

# 2. LiteLLM 헬스체크
echo -e "\n${YELLOW}[2/5] LiteLLM 프록시 헬스체크...${NC}"
if curl -sf http://localhost:4444/health/liveliness > /dev/null; then
    echo -e "${GREEN}✓ LiteLLM 프록시 응답 정상${NC}"
else
    echo -e "${RED}✗ LiteLLM 프록시 응답 없음${NC}"
    echo "  로그: docker compose logs litellm"
    exit 1
fi

# 3. 사용 가능한 모델 확인
echo -e "\n${YELLOW}[3/5] 사용 가능한 모델 확인...${NC}"
MODELS=$(curl -s http://localhost:4444/models \
    -H "Authorization: Bearer sk-4444" \
    -H "Content-Type: application/json" 2>/dev/null)

if echo "$MODELS" | grep -q "gemini-pro"; then
    echo -e "${GREEN}✓ gemini-pro 모델 등록됨${NC}"
else
    echo -e "${YELLOW}⚠ gemini-pro 모델을 찾을 수 없습니다${NC}"
    echo "  확인: docker compose logs litellm | grep -i gemini"
    echo "  설정: docker-compose.yml에서 GEMINI_API_KEY 확인"
fi

if echo "$MODELS" | grep -q "tinyllama"; then
    echo -e "${GREEN}✓ Ollama 로컬 모델 등록됨 (tinyllama)${NC}"
else
    echo -e "${RED}✗ Ollama 로컬 모델을 찾을 수 없습니다${NC}"
    echo "  해결: docker exec -it tinyllama1 ollama run tinyllama"
    exit 1
fi

# 4. Python 패키지 확인
echo -e "\n${YELLOW}[4/5] Python 패키지 확인...${NC}"
if python -c "import langchain" 2>/dev/null; then
    echo -e "${GREEN}✓ langchain 설치됨${NC}"
else
    echo -e "${RED}✗ langchain이 설치되지 않았습니다${NC}"
    echo "  해결: pip install -r requirements.txt 또는 uv sync"
    exit 1
fi

if python -c "from langchain_community.chat_models.litellm import ChatLiteLLM" 2>/dev/null; then
    echo -e "${GREEN}✓ langchain-community 설치됨${NC}"
else
    echo -e "${RED}✗ langchain-community가 설치되지 않았습니다${NC}"
    exit 1
fi

if python -c "import litellm" 2>/dev/null; then
    echo -e "${GREEN}✓ litellm 설치됨${NC}"
else
    echo -e "${RED}✗ litellm이 설치되지 않았습니다${NC}"
    exit 1
fi

# 5. 간단한 API 요청 테스트
echo -e "\n${YELLOW}[5/5] LiteLLM API 요청 테스트...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:4444/v1/chat/completions \
    -H "Authorization: Bearer sk-4444" \
    -H "Content-Type: application/json" \
    -d '{"model": "tinyllama1", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 5}' 2>/dev/null)

if echo "$RESPONSE" | grep -q "Hello\|content"; then
    echo -e "${GREEN}✓ API 요청 성공${NC}"
else
    echo -e "${RED}✗ API 요청 실패${NC}"
    echo "  응답: $RESPONSE"
fi

# 최종 결과
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ 모든 테스트 완료!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${YELLOW}다음 명령으로 에이전트를 실행하세요:${NC}"
echo -e "  ${BLUE}python src/run_langchain_agent.py${NC}\n"
