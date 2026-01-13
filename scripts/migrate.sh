#!/bin/bash
# migrate.sh - 이전 litellm 프로젝트에서 마이그레이션 또는 초기 설정
# 역할: Docker 볼륨과 네트워크 생성 (기존 것이 없을 경우)

set -e

echo "========================================"
echo "  Docker 리소스 초기화 도구"
echo "========================================"
echo ""

# 필요한 volume 목록
REQUIRED_VOLUMES=(
    "litellm_postgres_data"
    "litellm_ollama_data"
)

# 필요한 network
REQUIRED_NETWORK="litellm-network"

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

# Network 상태 확인
echo "📋 필요한 Network:"
if docker network ls --format "{{.Name}}" | grep -q "^$REQUIRED_NETWORK$"; then
    echo "  ✅ $REQUIRED_NETWORK (이미 존재)"
else
    echo "  ⚠️  $REQUIRED_NETWORK (없음 - 생성 필요)"
fi

echo ""
echo "========================================"
echo ""

# 누락된 volume 생성
MISSING_VOLUMES=0
for vol in "${REQUIRED_VOLUMES[@]}"; do
    if ! echo "$EXISTING_VOLUMES" | grep -q "^$vol$"; then
        echo "🔨 Volume 생성 중: $vol"
        docker volume create "$vol"
        MISSING_VOLUMES=$((MISSING_VOLUMES + 1))
    fi
done

# 누락된 network 생성
if ! docker network ls --format "{{.Name}}" | grep -q "^$REQUIRED_NETWORK$"; then
    echo "🔨 Network 생성 중: $REQUIRED_NETWORK"
    docker network create "$REQUIRED_NETWORK" --driver bridge
fi

echo ""
if [ $MISSING_VOLUMES -eq 0 ]; then
    echo "✅ 모든 Volume이 준비되어 있습니다"
else
    echo "✅ $MISSING_VOLUMES개의 Volume을 생성했습니다"
fi

echo "✅ Network가 준비되어 있습니다"

echo ""
echo "========================================"
echo "  초기화 완료!"
echo "========================================"
echo ""
echo "다음 명령어로 스택을 시작하세요:"
echo "  docker compose up -d"
echo ""
