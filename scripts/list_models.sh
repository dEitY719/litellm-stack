#!/bin/bash
# list_models.sh - LiteLLM 등록된 모델 상세 정보 출력

LITELLM_URL="http://localhost:4444"
LITELLM_API_KEY="sk-4444"

# 모델 정보 (추후 litellm_settings.yml에서 자동 추출 가능)
declare -A MODEL_INFO=(
    ["tinyllama"]="Ollama|50MB|저사양용"
    ["gpt-oss-20b"]="Ollama|13GB|고사양용"
    ["bge-m3"]="Ollama|1.2GB|임베딩 모델"
    ["gemini-2.0-flash"]="외부 API|---|Claude 경쟁 모델"
    ["gemini-2.5-flash-lite"]="외부 API|---|경량 모델"
    ["gemini-2.5-flash"]="외부 API|---|고성능 모델"
    ["gemini-2.5-pro"]="외부 API|---|최고 성능"
)

# LiteLLM에서 모델 목록 조회
MODELS=$(curl -s "${LITELLM_URL}/models" \
  -H "Authorization: Bearer ${LITELLM_API_KEY}" 2>/dev/null | \
  jq -r '.data[].id' 2>/dev/null | sort)

if [ -z "$MODELS" ]; then
    echo "❌ 모델 조회 실패"
    exit 1
fi

# 모델 카운트
MODEL_COUNT=$(echo "$MODELS" | wc -l)

echo ""
echo "   📋 LiteLLM 등록된 모델 (${MODEL_COUNT}개)"
echo ""

# Ollama 모델 (순서 지정)
echo "   ✅ Ollama 로컬 모델:"
local_models=("tinyllama" "gpt-oss-20b" "bge-m3")
local_model_idx=1
for model in "${local_models[@]}"; do
    if echo "$MODELS" | grep -q "^${model}$"; then
        info="${MODEL_INFO[$model]}"
        size=$(echo "$info" | cut -d'|' -f2)
        desc=$(echo "$info" | cut -d'|' -f3)

        printf "      %d. %-20s %-10s - %s\n" "$local_model_idx" "$model" "($size)" "$desc"
        local_model_idx=$((local_model_idx + 1))
    fi
done

echo ""
echo "   ✅ 외부 API 모델:"
external_idx=$((local_model_idx))
while IFS= read -r model; do
    if [[ "$model" != "tinyllama" ]] && [[ "$model" != "gpt-oss-20b" ]] && [[ "$model" != "bge-m3" ]]; then
        printf "      %d. %s\n" "$external_idx" "$model"
        external_idx=$((external_idx + 1))
    fi
done <<< "$MODELS"

echo ""
