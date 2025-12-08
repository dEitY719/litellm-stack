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
