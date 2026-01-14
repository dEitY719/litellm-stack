#!/bin/bash
# migrate.sh - 이전 litellm 프로젝트에서 마이그레이션

set -e

echo "========================================"
echo "  Volume 마이그레이션 도구"
echo "========================================"
echo ""

# 필요한 volume 목록
REQUIRED_VOLUMES=(
    "litellm_postgres_data"
    "litellm_ollama_data"
    "litellm_cache"
)

# 존재하는 volume 목록
EXISTING_VOLUMES=$(docker volume ls --format "{{.Name}}")

echo "📋 필요한 Volume:"
for vol in "${REQUIRED_VOLUMES[@]}"; do
    if echo "$EXISTING_VOLUMES" | grep -q "^$vol$"; then
        echo "  ✅ $vol (이미 존재)"
    else
        echo "  ⚠️  $vol (없음 - 생성 필요)"
    fi
done

echo ""
echo "========================================"
echo ""

# 누락된 volume 생성
MISSING_COUNT=0
for vol in "${REQUIRED_VOLUMES[@]}"; do
    if ! echo "$EXISTING_VOLUMES" | grep -q "^$vol$"; then
        echo "🔨 $vol 생성 중..."
        docker volume create "$vol"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

if [ $MISSING_COUNT -eq 0 ]; then
    echo "✅ 모든 Volume이 준비되어 있습니다"
else
    echo "✅ $MISSING_COUNT개의 Volume을 생성했습니다"
fi

echo ""
echo "========================================"
echo "  마이그레이션 완료!"
echo "========================================"
echo ""
echo "다음 명령어로 스택을 시작하세요:"
echo "  make up"
echo ""
