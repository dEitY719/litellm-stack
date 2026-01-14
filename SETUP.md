# 환경별 설정 가이드

이 프로젝트는 3가지 환경에서 실행됩니다. 각 환경에 맞게 설정하세요.

---

## 📋 환경 선택

| 환경 | 설명 | SSL 검증 | 빌드 | 설정 |
|------|------|---------|------|------|
| **Home** | 개인 PC (로컬 개발) | ✅ 활성화 | 미리빌드 이미지 | 최소 설정 |
| **External** | 회사 외부 PC (공개 GitHub) | ✅ 활성화 | 미리빌드 이미지 | 최소 설정 |
| **Internal** | 회사 내부 PC (프록시) | ❌ 비활성화 | 맞춤 Dockerfile | CA 인증서 필수 |

---

## 🏠 Home / External PC 설정

**가장 간단한 설정입니다. 추가 파일 불필요.**

### 1단계: 환경 변수 설정

```bash
cp .env.example .env
```

`.env` 파일 확인:
```bash
LITELLM_ENV=home    # 또는 external
```

### 2단계: 실행

```bash
docker compose up -d
```

**끝!** docker-compose.yml의 기본 설정으로 실행됩니다.

### 상세 설정값

```yaml
# docker-compose.yml (자동으로 사용됨)
litellm:
  image: ghcr.io/berriai/litellm:main-v1.73.0-stable  # 미리빌드 이미지
  user: "1000"                                         # 안전한 권한
  # SSL 검증: 기본값 (활성화) ✅
```

---

## 🏢 Internal PC 설정

**회사 프록시/방화벽 대응이 필요합니다.**

### 1단계: 파일 준비

```bash
# 1. override 파일 생성
cp docker-compose.override.yml.example docker-compose.override.yml

# 2. 회사 CA 인증서 복사
cp /path/to/samsungsemi-prx.com.crt ./samsungsemi-prx.com.crt

# 확인
ls -la docker-compose.override.yml samsungsemi-prx.com.crt
```

### 2단계: 환경 변수 설정

```bash
cp .env.example .env
```

`.env` 파일 수정:
```bash
LITELLM_ENV=internal
```

### 3단계: 실행

```bash
docker compose up -d
```

**docker-compose가 자동으로 override 파일을 적용합니다.**

### 상세 설정값

```yaml
# docker-compose.yml (기본)
# + docker-compose.override.yml (오버라이드)

litellm:
  build:
    context: .
    dockerfile: Dockerfile
    args:
      BUILD_TYPE: enterprise      # 맞춤 빌드

  user: "0:0"                      # Root 권한 (CA 설치용)
  environment:
    LITELLM_SSL_VERIFY: "False"    # SSL 검증 비활성화
```

### Docker 빌드 상세 설정

Dockerfile의 다단계 빌드 흐름:

```
Base Stage (ghcr.io image)
  ↓
Enterprise Stage (CA 인증서 + SSL 검증 비활성화)
  ├─ CA 인증서 추가
  ├─ Python sitecustomize.py 패치
  ├─ nodejs-bin 설치 (Prisma)
  └─ Prisma CLI 초기화
  ↓
Final Stage (BUILD_TYPE=internal 선택)
```

---

## 🔍 현재 환경 확인

### 실행 중인 환경 확인

```bash
# 사용 중인 이미지 확인
docker compose ps
docker inspect litellm | grep -E '"Image"'

# Enterprise인 경우 ("build" 확인)
docker compose config | grep -A 10 "services.litellm"
```

### 빌드 타입 확인

```bash
# 이미지 라벨 확인
docker inspect litellm | grep -i build_type

# 또는 컨테이너에서 직접 확인
docker exec litellm ls -la /app/.cache/prisma-python
# 존재하면 Internal (nodejs-bin 설치됨)
```

---

## 🛠️ 환경 변경하기

### Home → Internal로 변경

```bash
# 1. override 파일과 CA 인증서 준비
cp docker-compose.override.yml.example docker-compose.override.yml
cp /path/to/samsungsemi-prx.com.crt ./samsungsemi-prx.com.crt

# 2. .env 수정
echo "LITELLM_ENV=internal" > .env

# 3. 재빌드 및 재시작
docker compose down
docker compose up -d --build

# 4. 확인
docker compose logs -f litellm
```

### Internal → Home으로 변경

```bash
# 1. override 파일 제거
rm docker-compose.override.yml

# 2. .env 수정
echo "LITELLM_ENV=home" > .env

# 3. 재시작
docker compose down
docker compose up -d

# 4. 확인
docker compose ps
```

---

## ⚠️ 주의사항

### Internal PC 필수 사항

- ✅ `docker-compose.override.yml` 파일 존재
- ✅ `samsungsemi-prx.com.crt` 파일 존재
- ✅ `.env`에서 `LITELLM_ENV=internal` 설정
- ✅ `LITELLM_SSL_VERIFY: "False"` 환경변수 설정

**하나라도 없으면 오류 발생!**

### 파일 위치

```
litellm-stack/
├── docker-compose.yml              # 기본 설정 (모든 환경)
├── docker-compose.override.yml     # Enterprise만 (✓ .gitignore)
├── Dockerfile                      # 다단계 빌드
├── samsungsemi-prx.com.crt         # Enterprise CA 인증서 (✓ .gitignore)
├── litellm_settings.yml            # 모델 설정
└── .env                            # 환경 변수 (✓ .gitignore)
```

---

## 🔐 보안 주의

### Internal PC

- ❌ `docker-compose.override.yml` 공개 GitHub에 푸시 금지 (.gitignore)
- ❌ `samsungsemi-prx.com.crt` 공개 GitHub에 푸시 금지 (.gitignore)
- ✅ 로컬에만 보관 또는 안전한 채널로 배포

### 환경 변수

- `LITELLM_SSL_VERIFY: "False"`는 **Enterprise에서만** 필요
- Home/Public PC에서는 이 변수를 설정하지 않음

---

## 🚀 빠른 시작

### Home/External PC (5초)

```bash
cp .env.example .env
docker compose up -d
```

### Internal PC (30초)

```bash
cp .env.example .env
echo "LITELLM_ENV=internal" >> .env

cp docker-compose.override.yml.example docker-compose.override.yml
cp /path/to/samsungsemi-prx.com.crt ./samsungsemi-prx.com.crt

docker compose up -d --build
```

---

## 📞 문제 해결

### "Cannot find docker-compose.override.yml" 오류

**Internal PC에서만 필요합니다.**
```bash
cp docker-compose.override.yml.example docker-compose.override.yml
```

### "samsungsemi-prx.com.crt not found" 오류

**Internal PC에서만 필요합니다.**
```bash
cp /path/to/samsungsemi-prx.com.crt ./samsungsemi-prx.com.crt
```

### SSL 인증서 검증 오류 (Home/Public PC)

이 오류가 발생하면 안 됨 (SSL 검증이 활성화되어야 함).

해결책:
1. `docker compose config`에서 `LITELLM_SSL_VERIFY` 확인
2. `litellm_settings.yml`에서 `ssl_verify` 설정 확인
3. docker-compose.override.yml이 실수로 적용되지 않았는지 확인

---

## 📚 참고

- [Dockerfile 다단계 빌드 가이드](https://docs.docker.com/build/building/multi-stage/)
- [docker-compose override 가이드](https://docs.docker.com/compose/extends/)
- [LiteLLM SSL 설정](https://docs.litellm.ai/docs/proxy/configs)
