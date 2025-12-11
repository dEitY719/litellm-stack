# WSL2 환경에서 GPU 사용 가이드

**작성일**: 2025-12-11
**대상 환경**: Windows 11 + WSL2 + NVIDIA GPU
**프로젝트**: LiteLLM Stack

---

## 목차

1. [WSL2 GPU 아키텍처 이해](#1-wsl2-gpu-아키텍처-이해)
2. [nvidia-smi 접근 제한 설명](#2-nvidia-smi-접근-제한-설명)
3. [GPU 상태 확인 방법](#3-gpu-상태-확인-방법)
4. [성능 최적화](#4-성능-최적화)
5. [문제 해결](#5-문제-해결)
6. [참고 자료](#6-참고-자료)

---

## 1. WSL2 GPU 아키텍처 이해

### 1.1 WSL2 GPU 구조

WSL2에서 GPU는 다음과 같은 계층 구조로 작동합니다:

```
Windows 호스트
 └─ NVIDIA GPU 드라이버 (Windows용)
     └─ /usr/lib/wsl/lib/ (WSL2 공유 라이브러리)
         ├─ nvidia-smi (WSL2용 stub)
         ├─ libcuda.so (CUDA 런타임)
         └─ libcudnn.so (cuDNN)
             └─ Docker 컨테이너
                 └─ CUDA 애플리케이션 (Ollama)
```

**핵심 포인트:**
- Windows 드라이버가 WSL2에 GPU 접근 제공
- WSL2 내에 별도 NVIDIA 드라이버 설치 불필요
- Docker 컨테이너는 WSL2를 통해 간접적으로 GPU 접근

### 1.2 네이티브 Linux vs WSL2 차이

| 항목 | 네이티브 Linux | WSL2 |
|------|----------------|------|
| GPU 드라이버 설치 위치 | Linux 커널 | Windows 호스트 |
| nvidia-smi 위치 | `/usr/bin/nvidia-smi` | `/usr/lib/wsl/lib/nvidia-smi` |
| Docker 컨테이너 내 nvidia-smi | 실행 가능 | 실행 불가 (구조적 제약) |
| CUDA 연산 | 정상 작동 | 정상 작동 |
| 성능 | 100% | 95-98% (오버헤드 미미) |

---

## 2. nvidia-smi 접근 제한 설명

### 2.1 왜 Docker 컨테이너에서 nvidia-smi가 안 되는가?

#### 문제 상황
```bash
# Makefile의 health 체크 시도
docker exec ollama nvidia-smi
# 오류: nvidia-smi: command not found
# 또는: GPU access blocked by the operating system
```

#### 원인

1. **WSL2 구조적 제약**:
   - nvidia-smi는 `/usr/lib/wsl/lib/`에만 존재
   - Docker 컨테이너는 해당 경로를 마운트하지 않음
   - NVIDIA Container Toolkit이 nvidia-smi를 포함하지 않음 (CUDA 런타임만 제공)

2. **설계상 의도**:
   - WSL2는 Windows 드라이버를 직접 공유
   - 컨테이너는 GPU 연산만 수행 (모니터링 도구 불필요)

### 2.2 오해하기 쉬운 점

| 오해 | 실제 | 근거 |
|------|------|------|
| "nvidia-smi 안 되면 GPU 안 쓰는 거다" | ❌ CUDA 연산은 정상 작동 | Ollama 로그에서 GPU 메모리 사용 확인됨 |
| "nvidia-container-toolkit 문제다" | ❌ WSL2 환경에서 정상 동작 | Container Toolkit은 CUDA 지원 (모니터링 도구 미포함) |
| "Docker GPU 설정이 잘못됐다" | ❌ GPU 연산 자체는 성공 | 모델이 GPU에서 정상 실행됨 |

### 2.3 실제 GPU 사용 확인 방법

**❌ 잘못된 방법:**
```bash
docker exec ollama nvidia-smi  # WSL2에서 작동 안 함
```

**✅ 올바른 방법:**

방법 1: WSL2 호스트에서 nvidia-smi 사용 (권장)
```bash
/usr/lib/wsl/lib/nvidia-smi
```

방법 2: Ollama 로그로 GPU 사용 확인
```bash
# GPU 메모리 인식
docker logs ollama 2>&1 | grep "gpu memory"

# 레이어 오프로드 (가장 중요)
docker logs ollama 2>&1 | grep "offloaded.*layers"
```

방법 3: 프로젝트 스크립트 사용 (가장 편함)
```bash
./scripts/gpu_status.sh
# 또는
make gpu-status
```

---

## 3. GPU 상태 확인 방법

### 3.1 WSL2 호스트에서 확인

#### GPU 하드웨어 정보
```bash
# 기본 정보
/usr/lib/wsl/lib/nvidia-smi

# 상세 메모리 정보
/usr/lib/wsl/lib/nvidia-smi --query-gpu=name,memory.total,memory.free,memory.used --format=csv
```

**출력 예시:**
```
name, memory.total [MiB], memory.free [MiB], memory.used [MiB]
NVIDIA GeForce RTX 5070 Ti, 16303 MiB, 14109 MiB, 1799 MiB
```

#### 실시간 모니터링
```bash
watch -n 1 '/usr/lib/wsl/lib/nvidia-smi'
```

### 3.2 Ollama 로그를 통한 GPU 확인

#### GPU 메모리 인식 확인
```bash
docker logs ollama 2>&1 | grep "gpu memory"
```

**정상 출력 예시:**
```
level=INFO source=sched.go:450 msg="gpu memory" id=GPU-00704267... library=CUDA available="13.5 GiB" free="13.9 GiB" minimum="457.0 MiB" overhead="0 B"
```

#### 레이어 오프로드 확인 (가장 중요!)
```bash
docker logs ollama 2>&1 | grep "offloaded.*layers to GPU" | tail -1
```

**출력 해석:**
- `offloaded 25/25 layers to GPU` → ✅ **정상**: 모든 레이어가 GPU에서 실행
- `offloaded 20/25 layers to GPU` → ⚠️ **부분 GPU**: 일부만 GPU 사용, 나머지 CPU
- `offloaded 0/25 layers to GPU` → ❌ **CPU 모드**: GPU 미사용 (성능 저하)

### 3.3 프로젝트 전용 스크립트 사용

#### gpu_status.sh (권장)
```bash
# 전체 GPU 상태 진단
./scripts/gpu_status.sh

# 또는 Makefile 사용
make gpu-status
```

**제공 정보:**
- WSL2 호스트 GPU 하드웨어
- Docker GPU 설정 검증
- Ollama GPU 인식 상태
- 레이어 오프로드 현황
- 환경변수 설정 확인
- 성능 최적화 권장사항

#### Makefile 단축 명령어
```bash
# 간략 정보
make gpu-info

# 헬스체크 (GPU 포함)
make health
```

---

## 4. 성능 최적화

### 4.1 GPU 레이어 오프로드 문제 해결

#### 증상
```bash
# Ollama 로그에서
docker logs ollama 2>&1 | grep "offloaded.*layers"
# 출력: "offloaded 0/25 layers to GPU"  ❌ CPU 모드
```

#### 해결 방법 (단계별)

**1단계: Ollama 재시작**
```bash
docker compose restart ollama
```

**2단계: 환경변수 설정 (docker-compose.yml)**

파일을 열어서 `ollama` 서비스의 `environment` 섹션을 확인:

```yaml
ollama:
  environment:
    # GPU 최적화
    OLLAMA_GPU_OVERHEAD: "1073741824"  # 1GB
    OLLAMA_NUM_GPU: "25"                # 모델 레이어 수
```

**3단계: 스택 재구축**
```bash
docker compose down
docker compose up -d
sleep 30
```

**4단계: 확인**
```bash
make gpu-status
# 또는
docker logs ollama 2>&1 | grep "offloaded.*layers" | tail -1
```

기대 결과:
```
offloaded 25/25 layers to GPU  ✅ 성공
```

**5단계: 지속 실패 시**
```bash
# CUDA 호환성 확인
docker logs ollama 2>&1 | grep -i 'cuda'

# 자세한 진단
./scripts/gpu_status.sh

# 문제 해결 참고
cat docs/wsl2-gpu-guide.md  # 이 문서의 섹션 5
```

### 4.2 GPU 메모리 최적화

#### RTX 5070 Ti (16GB VRAM) 권장 설정

현재 `docker-compose.yml`의 기본값:
```yaml
ollama:
  environment:
    # 메모리 관리
    OLLAMA_KEEP_ALIVE: "5m"              # 5분 후 모델 언로드

    # GPU 최적화
    OLLAMA_GPU_OVERHEAD: "1073741824"    # 1GB (시스템 예약)
    OLLAMA_NUM_PARALLEL: "2"             # 동시 요청 2개
    OLLAMA_MAX_LOADED_MODELS: "2"        # 최대 2개 모델 동시 로드
    OLLAMA_FLASH_ATTENTION: "1"          # Flash Attention 활성화
```

#### VRAM 사용량 예측

| 모델 | 모델 크기 | VRAM 사용량 (추론) | 권장 최소 VRAM |
|------|-----------|-------------------|----------------|
| tinyllama | ~50MB | ~500MB | 2GB |
| llama-3-8b | ~4.5GB | ~6GB | 8GB |
| gpt-oss:20b | ~11GB | ~13.5GB | 16GB |
| llama-3-70b | ~38GB | ~42GB | 48GB (A100 등) |

**계산식:**
```
필요 VRAM = 모델 크기 × 1.3 + GPU Overhead + KV Cache
```

### 4.3 Flash Attention 최적화

#### 지원 GPU
- NVIDIA Ampere 이상 (Compute Capability 8.0+)
  - RTX 30xx 시리즈 ✅
  - RTX 40xx 시리즈 ✅
  - RTX 50xx 시리즈 ✅ (RTX 5070 Ti 포함)
  - A100, H100 ✅

#### 활성화 확인
```bash
docker exec ollama env | grep OLLAMA_FLASH_ATTENTION
# 출력: OLLAMA_FLASH_ATTENTION=1  ✅ 활성화됨
```

#### 성능 개선 효과
- 추론 속도: 20-30% 향상
- 메모리 사용: 15-20% 감소
- Long context 처리: 더 빠름

---

## 5. 문제 해결

### 5.1 GPU 레이어 오프로드 실패 (0/25)

**증상:**
```bash
docker logs ollama 2>&1 | grep "offloaded.*layers"
# 출력: "offloaded 0/25 layers to GPU"
```

**진단 명령:**
```bash
./scripts/gpu_status.sh  # 상세 진단
```

**해결 방법 (우선순위):**

**1️⃣ CUDA 드라이버 버전 불일치**
```bash
# Ollama 로그 확인
docker logs ollama 2>&1 | grep -i "CUDA driver version is insufficient"

# 해결: Windows NVIDIA 드라이버 업데이트
# https://www.nvidia.com/drivers
```

**2️⃣ GPU 메모리 부족**
```bash
# 사용 가능한 VRAM 확인
/usr/lib/wsl/lib/nvidia-smi --query-gpu=memory.free --format=csv

# 해결 방법:
# - 다른 GPU 사용 프로그램 종료 (Chrome, VS Code, Games)
# - 작은 모델 사용 (tinyllama 권장)
# - OLLAMA_GPU_OVERHEAD 감소 (1GB → 512MB)
```

**3️⃣ 환경변수 미설정**
```yaml
# docker-compose.yml 확인
ollama:
  environment:
    OLLAMA_GPU_OVERHEAD: "1073741824"  # 필수
    OLLAMA_NUM_GPU: "25"                # 선택 (auto 기본값)
```

**4️⃣ Docker GPU 설정 오류**
```bash
# GPU 설정 검증
docker inspect ollama --format '{{json .HostConfig.DeviceRequests}}' | jq

# 기대 출력:
# [
#   {
#     "Driver": "nvidia",
#     "Count": -1,  # -1 = all GPUs
#     "Capabilities": [["gpu"]]
#   }
# ]
```

**5️⃣ 지속 실패 시**
```bash
# WSL2 환경 재부팅
wsl --shutdown
# Windows Powershell에서 실행

# 이후 다시 시작
docker compose up -d
sleep 30
make gpu-status
```

### 5.2 "nvidia-smi: command not found" 오류

**원인**: WSL2 환경에서 정상 (섹션 2 참조)

**해결:**
```bash
# 호스트에서 실행 (올바른 방법)
/usr/lib/wsl/lib/nvidia-smi

# 또는 프로젝트 스크립트 사용
./scripts/gpu_status.sh
```

### 5.3 VRAM 사용량이 높은데 레이어 오프로드 안 됨

**증상:**
```bash
# GPU 메모리는 사용 중
/usr/lib/wsl/lib/nvidia-smi
# Used: 5000 MiB

# 하지만 Ollama는 CPU 모드
docker logs ollama | grep offloaded
# offloaded 0/25 layers to GPU  ❌
```

**원인**: 다른 프로그램이 GPU 메모리 점유
- Chrome (GPU 가속 활성화)
- VS Code (GPU 기능 사용)
- 게임
- 다른 CUDA 애플리케이션

**해결:**
```bash
# GPU 사용 프로세스 확인
/usr/lib/wsl/lib/nvidia-smi pmon

# GPU 사용 프로그램 종료
# 예: Chrome 종료, VS Code 재시작 등

# Ollama 재시작
docker compose restart ollama

# 확인
./scripts/gpu_status.sh
```

### 5.4 모델이 느리게 작동 (GPU는 정상인데)

**확인:**
```bash
docker logs ollama 2>&1 | grep "offloaded.*layers"
# 출력: "offloaded 25/25 layers to GPU"  ✅ GPU 정상

# 그럼에도 느릴 수 있는 원인:
```

**원인과 해결:**

1. **모델 첫 실행 (Cold Start)**
   - 원인: 모델을 처음 로드하는 데 시간 소요
   - 해결: 두 번째 실행부터 빠름

2. **VRAM 부족으로 인한 CPU 폴백**
   - 확인: `gpu_status.sh` [3/5] 섹션에서 오버헤드 확인
   - 해결: `OLLAMA_GPU_OVERHEAD` 조정 (1GB → 512MB)

3. **메모리 스와핑 (디스크 사용)**
   - 증상: 아주 느린 반응
   - 확인: 디스크 I/O 확인 (작업 관리자)
   - 해결: 더 작은 모델 사용

---

## 6. 참고 자료

### 6.1 공식 문서

- [NVIDIA CUDA on WSL User Guide](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)
- [Microsoft: Enable NVIDIA CUDA on WSL 2](https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl)
- [Docker: WSL 2 GPU Support](https://www.docker.com/blog/wsl-2-gpu-support-for-docker-desktop-on-nvidia-gpus/)
- [Ollama GPU Documentation](https://docs.ollama.com/gpu)
- [Ollama Environment Variables Guide](https://markaicode.com/ollama-environment-variables-configuration-guide/)

### 6.2 프로젝트 문서

- [README.md](../README.md) - 전체 개요
- [Architecture Guide](./architecture-litellm-ollama-final.md) - 아키텍처
- [CLAUDE.md](../CLAUDE.md) - 개발 노트

### 6.3 관련 GitHub 이슈

- [WSL: GPU access blocked by the operating system](https://github.com/microsoft/WSL/issues/9962)
- [Ollama: OLLAMA_NUM_GPU ignored](https://github.com/ollama/ollama/issues/11437)
- [nvidia-docker: Permission denied in WSL2](https://github.com/NVIDIA/nvidia-docker/issues/1029)

---

## 빠른 참조

### A. 일반 작업 흐름

```bash
# 1. GPU 상태 확인
make gpu-status

# 2. 문제 발견 시 재시작
docker compose restart ollama

# 3. 환경변수 조정 필요 시
vim docker-compose.yml  # environment 섹션 수정
docker compose up -d --force-recreate ollama

# 4. 재확인
make gpu-status
```

### B. 주요 명령어 치트시트

```bash
# WSL2 호스트 (GPU 정보)
/usr/lib/wsl/lib/nvidia-smi                    # GPU 정보
/usr/lib/wsl/lib/nvidia-smi pmon               # 프로세스 모니터링
watch -n 1 '/usr/lib/wsl/lib/nvidia-smi'       # 실시간 모니터링

# Docker/Ollama (GPU 상태)
docker logs ollama 2>&1 | grep "gpu memory"    # GPU 인식 확인
docker logs ollama 2>&1 | grep "offloaded"     # 레이어 오프로드
docker exec ollama env | grep OLLAMA           # 환경변수

# 프로젝트 스크립트
./scripts/gpu_status.sh                        # 전체 진단
make gpu-status                                # 전체 진단 (Makefile)
make gpu-info                                  # 간략 정보
make health                                    # 헬스체크 (GPU 포함)
```

### C. 환경변수 권장값 (RTX 5070 Ti 16GB 기준)

**docker-compose.yml:**
```yaml
OLLAMA_GPU_OVERHEAD: "1073741824"              # 1GB
OLLAMA_NUM_PARALLEL: "2"                       # 동시 요청 2개
OLLAMA_MAX_LOADED_MODELS: "2"                  # 최대 2 모델
OLLAMA_KEEP_ALIVE: "5m"                        # 5분 후 언로드
OLLAMA_FLASH_ATTENTION: "1"                    # 활성화
```

**GPU VRAM별 권장:**
```
8GB 이하:
  - OLLAMA_GPU_OVERHEAD: "536870912" (512MB)
  - OLLAMA_MAX_LOADED_MODELS: "1"
  - 모델: tinyllama만 권장

8-16GB:
  - OLLAMA_GPU_OVERHEAD: "1073741824" (1GB) ← 기본값
  - OLLAMA_MAX_LOADED_MODELS: "2"
  - 모델: tinyllama + 작은 모델 (7B 이하)

16GB+:
  - OLLAMA_GPU_OVERHEAD: "2147483648" (2GB)
  - OLLAMA_MAX_LOADED_MODELS: "3"
  - 모델: gpt-oss:20b 등 대형 모델 가능
```

---

**마지막 업데이트**: 2025-12-11
**작성자**: Claude Code (Haiku 4.5)
