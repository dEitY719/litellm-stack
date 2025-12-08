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
