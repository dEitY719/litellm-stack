#!/bin/bash
# setup_models.sh - PC 사양에 따른 자동 모델 설정 (Idempotent)

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

# 모델 목록 조회 (현재 설치된 모델)
echo ""
echo "[2/3] 모델 설정 중..."
echo ""

INSTALLED_MODELS=$(docker exec ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' | sed 's/:latest//' || echo "")

# 설정할 모델 목록 결정
MODELS_TO_INSTALL=()
MODELS_INSTALLED=()

# 기본 모델 (항상)
if echo "$INSTALLED_MODELS" | grep -q "^tinyllama"; then
    echo "  ✅ tinyllama (이미 설치됨, ~50MB)"
    MODELS_INSTALLED+=("tinyllama")
else
    echo "  📥 tinyllama 설치 중 (~50MB)..."
    docker exec ollama ollama pull tinyllama > /dev/null 2>&1
    MODELS_INSTALLED+=("tinyllama")
fi

# 사양별 모델
if [ "$VRAM_GB" -ge 14 ]; then
    echo ""
    echo "  ✓ 고사양 PC 감지 (${VRAM_GB}GB VRAM)"
    echo ""

    # gpt-oss:20b
    if echo "$INSTALLED_MODELS" | grep -q "^gpt-oss"; then
        echo "  ✅ gpt-oss:20b (이미 설치됨, ~11GB)"
        MODELS_INSTALLED+=("gpt-oss-20b")
    else
        echo "  📥 gpt-oss:20b 설치 중 (~11GB, 약 10분 소요)..."
        docker exec ollama ollama pull gpt-oss:20b > /dev/null 2>&1
        MODELS_INSTALLED+=("gpt-oss-20b")
    fi

    # bge-m3
    if echo "$INSTALLED_MODELS" | grep -q "^bge-m3"; then
        echo "  ✅ bge-m3 (이미 설치됨, ~2GB)"
        MODELS_INSTALLED+=("bge-m3")
    else
        echo "  📥 bge-m3 설치 중 (~2GB)..."
        docker exec ollama ollama pull bge-m3:latest > /dev/null 2>&1
        MODELS_INSTALLED+=("bge-m3")
    fi

    # gpt-oss:20b 사전 로드 (최소 5초 이상 실행해서 메모리에 로드)
    echo "  🔄 gpt-oss:20b 사전 로드 중..."
    timeout 30 docker exec ollama ollama run gpt-oss:20b "warmup" > /dev/null 2>&1 || true

    MODELS="tinyllama, gpt-oss-20b, bge-m3"
else
    echo ""
    echo "  ✓ 저사양 PC 감지 (${VRAM_GB}GB VRAM)"
    echo "  ⚠️  gpt-oss:20b는 생략합니다 (14GB+ VRAM 권장)"
    echo ""

    MODELS="tinyllama"
fi

# 테스트
echo "[3/3] 설정 확인 중..."
echo ""

# LiteLLM 헬스 체크
if curl -f http://localhost:4444/health/liveliness > /dev/null 2>&1; then
    echo "  ✅ LiteLLM 프록시 정상"
else
    echo "  ❌ LiteLLM 프록시 응답 없음"
    exit 1
fi

# 설정된 모델 목록 표시
echo "  ✅ 설정된 모델: ${MODELS}"

echo ""
echo "=================================="
echo "설정 완료! (Idempotent - 안전하게 여러 번 실행 가능)"
echo "=================================="
echo ""
echo "📝 설명:"
echo "  • ✅ = 이미 설치됨 (다시 실행해도 skip)"
echo "  • 📥 = 새로 설치 (첫 실행 시에만)"
echo ""
echo "🧪 테스트 명령어:"
echo ""
echo "  curl http://localhost:4444/v1/chat/completions \\"
echo "    -H \"Authorization: Bearer sk-4444\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{"
echo "      \"model\": \"tinyllama\","
echo "      \"messages\": [{\"role\": \"user\", \"content\": \"안녕?\"}]"
echo "    }'"
echo ""
