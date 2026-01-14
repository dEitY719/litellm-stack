# 🏢 회사 내부 PC 설정 가이드 (Internal Network)

이 가이드는 **회사 내부 네트워크(프록시)를 사용하는 개발자**를 위한 설정 방법입니다.

---

## 📋 개요

회사 내부 PC에서 LiteLLM을 실행하려면 **회사 CA 인증서(samsungsemi-prx.com.crt)**가 필요합니다.

| 단계 | 작업 | 소요시간 |
|------|------|---------|
| 1️⃣ | CA 인증서 다운로드 | 2분 |
| 2️⃣ | 프로젝트 초기 설정 | 1분 |
| 3️⃣ | 스택 시작 | 3분 |

---

## 🔑 Step 1: CA 인증서 다운로드

### 1-1️⃣ 인증서 다운로드 페이지 접속

다음 링크에 접속합니다:

```
http://12.53.3.52:5465/apc/AgentInstall/list_agent.htm
```

> 💡 **TIP**: 이 링크는 회사 내부 네트워크에서만 접근 가능합니다.
> 만약 접근이 안 되면 IT 팀(it-support@company.com)에 문의하세요.

### 1-2️⃣ 인증서 파일 다운로드

페이지에서 다음 파일을 찾아 다운로드합니다:

```
samsungsemi-prx.com.crt
```

**다운로드 후:**
```
다운로드폴더/
└── samsungsemi-prx.com.crt  ← 이 파일
```

---

## 📁 Step 2: 프로젝트 초기 설정

### 2-1️⃣ 프로젝트 클론 및 디렉토리 이동

```bash
git clone https://github.com/your-org/litellm-stack.git
cd litellm-stack
```

### 2-2️⃣ CA 인증서 폴더 생성 및 복사

```bash
# 1. certs 폴더 생성
mkdir -p certs

# 2. 다운로드한 인증서를 certs 폴더로 복사
# (다운로드폴더의 경로를 실제 경로로 변경하세요)
cp ~/Downloads/samsungsemi-prx.com.crt certs/corp-ca.crt
```

**파일 구조 확인:**
```bash
litellm-stack/
├── certs/
│   └── corp-ca.crt          ← 여기에 있는지 확인
├── docker-compose.yml
└── ...
```

### 2-3️⃣ 환경 초기 설정

```bash
# Interactive 초기 설정 실행
make init
```

**선택 메뉴:**
```
╔════════════════════════════════════════════════════╗
║       🔧 LiteLLM 환경 초기 설정                   ║
╚════════════════════════════════════════════════════╝

실행 환경을 선택하세요:

  1) home      - 개인 PC (로컬 개발)
  2) external  - 회사 외부 PC
  3) internal  - 회사 내부 PC (프록시)  ← 3번 선택!

선택 (1-3, Enter로 기본값 1 선택): 3
```

**자동 설정 과정:**
```
🏢 선택됨: Internal (회사 내부 - 프록시)

📝 .env 파일 생성 중...
   ✅ .env 파일 생성됨

⚙️  환경 설정 적용 중 (LITELLM_ENV=internal)...
   ✅ .env 파일 업데이트됨

🏢 Internal PC 추가 설정...
   ✅ docker-compose.override.yml 파일 생성됨

⚠️  주의: CA 인증서 필요
   ✅ certs/corp-ca.crt 파일 확인됨  ← 이미 준비됨!

🔄 Volume 마이그레이션 중...
   ✅ Volume 마이그레이션 완료

✅ 초기 설정 완료!
```

---

## 🚀 Step 3: 스택 시작

### 3-1️⃣ Docker 이미지 빌드 및 스택 시작

```bash
make up
```

**시작 과정:**
```
🚀 스택 시작 중...
[Docker 이미지 빌드 및 컨테이너 실행...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 시작 완료!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NAME        STATUS          PORTS
ollama      Up 2 minutes    11434:11434
litellm     Up 1 minute     4444:4000
litellm_db  Up 2 minutes    5431:5432
```

### 3-2️⃣ 헬스 체크 (선택사항)

```bash
make health
```

**성공 시:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
헬스 체크
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  Ollama (http://localhost:11434)
   ✅ Ollama API 정상
   tinyllama

2️⃣  LiteLLM (http://localhost:4444)
   ✅ LiteLLM 프록시 정상
   등록된 모델: 5

3️⃣  Database (localhost:5431)
   ✅ Database 정상

4️⃣  GPU 상태 (간략)
   ✓ GPU 레이어 오프로드: 30/40
```

---

## 🔍 검증 및 확인

### CA 인증서 확인

```bash
# 인증서 파일 위치 확인
ls -la certs/corp-ca.crt

# 출력 예시:
# -r--r--r-- 1 user group 2345 Jan 14 10:30 certs/corp-ca.crt
```

### Docker 컨테이너 확인

```bash
# 실행 중인 컨테이너 확인
docker ps

# 또는
make ps
```

### 환경 설정 확인

```bash
# .env 파일 확인
grep LITELLM_ENV .env

# 출력:
# LITELLM_ENV=internal
```

---

## ⚠️ 문제 해결

### 문제 1: "http://12.53.3.52:5465 에 접근할 수 없어요"

**원인:** 회사 내부 네트워크에 연결되지 않았을 가능성

**해결책:**
```bash
# 1. VPN 연결 확인
ping 12.53.3.52

# 2. 연결 안 되면 IT팀에 문의
# IT Support: it-support@company.com
# 요청: "회사 인증서 다운로드 페이지(12.53.3.52:5465) 접근 불가"
```

### 문제 2: "certs/corp-ca.crt 파일이 없어요"

**해결책:**
```bash
# 1. 파일이 제대로 복사되었는지 확인
ls -la certs/

# 2. 없으면 다시 복사
cp ~/Downloads/samsungsemi-prx.com.crt certs/corp-ca.crt

# 3. make init 다시 실행
make init  # 3번 선택
```

### 문제 3: "Docker 빌드 중 SSL 오류가 발생해요"

**보통 원인:** CA 인증서가 제대로 마운트되지 않음

**해결책:**
```bash
# 1. 컨테이너 재시작
make down
make up

# 2. 또는 완전 재빌드
make rebuild
```

### 문제 4: "make init 중 선택 메뉴가 안 나와요"

**해결책:**
```bash
# 1. 기존 파일 정리
rm .env docker-compose.override.yml

# 2. 다시 init
make init
```

---

## 📞 추가 지원

문제가 발생하면:

1. **이 문서 재확인** - 위의 "문제 해결" 섹션
2. **팀 리더에게 물어보기**
3. **IT팀 문의**: it-support@company.com
   - 이메일 제목: "LiteLLM Internal 설정 지원 요청"
   - 본문: 발생한 오류 메시지와 `make health` 결과

---

## ✅ 완료!

축하합니다! 🎉

회사 내부 네트워크에서 LiteLLM을 사용할 준비가 완료되었습니다.

### 다음 단계

```bash
# 1. 모델 설정
make setup-models

# 2. LiteLLM 접속
# 브라우저에서: http://localhost:4444

# 3. API 테스트
curl -X GET http://localhost:4444/models \
  -H "Authorization: Bearer sk-4444"
```

---

## 📚 참고 자료

- **Makefile 명령어**: `make help`
- **README.md**: 프로젝트 개요
- **SETUP.md**: 모든 환경 설정 가이드
- **docker-compose.override.yml.example**: Internal PC 설정 상세

---

**마지막 수정:** 2026-01-14
**작성자:** Development Team
