# ═══════════════════════════════════════════════════════════════════════════════
# Dockerfile: 환경별 조건부 빌드 (Home/External vs Internal)
# ═══════════════════════════════════════════════════════════════════════════════
#
# 빌드 방법:
# - Home/External: docker build --build-arg BUILD_TYPE=home .
# - Internal:      docker build --build-arg BUILD_TYPE=internal .
#
# docker-compose는 자동으로 적절한 BUILD_TYPE을 전달합니다.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# 빌드 인자 (기본값: home)
# ─────────────────────────────────────────────────────────────────────────────
ARG BUILD_TYPE=home

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: 기본 이미지 + Prisma 초기화 (모든 환경)
# ─────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/berriai/litellm:main-v1.73.0-stable as base
LABEL build_type="${BUILD_TYPE}"

USER root

# Prisma 환경 설정
ENV HOME=/app
ENV XDG_CACHE_HOME=/app/.cache
RUN mkdir -p /app/.cache/prisma-python

# Python SSL 검증 비활성화 (nodeenv, npm 등의 바이너리 다운로드용)
# Home/External: 개발 환경이므로 SSL 검증 비활성화 필요
# Internal: 회사 프록시 대응을 위해 이미 비활성화됨

# urllib이 사용하는 기본 context를 무시하기 위해 monkey-patch 적용
RUN python3 - <<'PY'
import urllib.request
import ssl

# 기본 SSL context를 생성하는 함수를 재정의
_original_create_default_context = ssl.create_default_context

def _patched_create_default_context(purpose=ssl.Purpose.SERVER_AUTH, *, cafile=None, capath=None, cadata=None):
    context = _original_create_default_context(purpose=purpose, cafile=cafile, capath=capath, cadata=cadata)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context

ssl.create_default_context = _patched_create_default_context
urllib.request.ssl.create_default_context = _patched_create_default_context

# sitecustomize.py에도 저장하여 persistence 확보
import site
site_packages = site.getsitepackages()[0]
with open(f"{site_packages}/sitecustomize.py", 'w') as f:
    f.write('''import ssl
import urllib.request

_original_create_default_context = ssl.create_default_context

def _patched_create_default_context(purpose=ssl.Purpose.SERVER_AUTH, *, cafile=None, capath=None, cadata=None):
    context = _original_create_default_context(purpose=purpose, cafile=cafile, capath=capath, cadata=cadata)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context

ssl.create_default_context = _patched_create_default_context
urllib.request.ssl.create_default_context = _patched_create_default_context
''')
print("SSL verification disabled for all environments (urllib + nodeenv compatibility)")
PY

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Internal 빌드 (CA 인증서 + SSL 검증 비활성화)
# ─────────────────────────────────────────────────────────────────────────────
FROM base as internal

# 회사 CA 인증서 복사
COPY ./samsungsemi-prx.com.crt /usr/local/share/ca-certificates/corp-ca.crt

# CA 번들 생성: certifi + 회사 CA
RUN python3 - <<'PY'
import certifi
import shutil
import os

# certifi 번들을 /etc/ssl/certs/ca-certificates.crt로 복사
os.makedirs("/etc/ssl/certs", exist_ok=True)
ca_bundle_path = "/etc/ssl/certs/ca-certificates.crt"
shutil.copyfile(certifi.where(), ca_bundle_path)

# 회사 CA 추가
with open(ca_bundle_path, "ab") as bundle:
    bundle.write(b"\n")
    with open("/usr/local/share/ca-certificates/corp-ca.crt", "rb") as ca:
        bundle.write(ca.read())

print(f"Created CA bundle: {ca_bundle_path} ({os.path.getsize(ca_bundle_path)} bytes)")
PY

# 환경변수 설정 (빌드 시점에 pip, npm이 사용)
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Python SSL 검증 비활성화 패치 (런타임용)
# ⚠️ Internal 필수: 회사 프록시/방화벽 대응
# (동료 검증 결과: CA 인증서만으로는 부족)
RUN python3 - <<'PY'
sitecustomize_content = '''
import ssl

# Internal 환경: SSL 검증 완전 비활성화
# 회사 프록시/방화벽 대응 (동료 검증 완료)
_original_create_default_context = ssl.create_default_context

def _patched_create_default_context(purpose=ssl.Purpose.SERVER_AUTH, *, cafile=None, capath=None, cadata=None):
    context = _original_create_default_context(purpose=purpose, cafile=cafile, capath=capath, cadata=cadata)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context

ssl.create_default_context = _patched_create_default_context
'''

import site
site_packages = site.getsitepackages()[0]
with open(f"{site_packages}/sitecustomize.py", 'w') as f:
    f.write(sitecustomize_content)
print("SSL verification disabled for Enterprise environment")
PY

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3: Home/Public 빌드 (기본값, 추가 설정 없음)
# ─────────────────────────────────────────────────────────────────────────────
FROM base as home

# ─────────────────────────────────────────────────────────────────────────────
# Stage 4: 최종 이미지 선택 (BUILD_TYPE에 따라)
# ─────────────────────────────────────────────────────────────────────────────
FROM ${BUILD_TYPE} as final
