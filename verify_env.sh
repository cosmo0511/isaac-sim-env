#!/usr/bin/env bash
# =============================================================
#  팀 공통 환경 검증 — Isaac Sim 5.1 / Isaac Lab 2.3.1
#  컨테이너 안에서 실행:  bash verify_env.sh
#  기대값과 다르면 이미지가 어긋난 것이니 README 의 설정을 다시 확인하세요.
# =============================================================
set -uo pipefail

PASS=0; FAIL=0
ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
info() { echo "  [..]   $1"; }

echo "============================================="
echo " 기대 환경"
echo "   Isaac Sim 5.1 · Isaac Lab 2.3.1"
echo "   Python 3.11 · CUDA 12.8 · 드라이버 >= 570.169"
echo "============================================="
echo

# ---------- 1. 이미지 경로 ----------
echo "[1] Isaac 경로"
[ -d "${ISAACSIM_ROOT_PATH:-/isaac-sim}" ] \
  && ok "Isaac Sim: ${ISAACSIM_ROOT_PATH:-/isaac-sim}" \
  || bad "Isaac Sim 경로 없음 (ISAACSIM_ROOT_PATH=${ISAACSIM_ROOT_PATH:-unset})"
[ -d "${ISAACLAB_PATH:-/workspace/isaaclab}" ] \
  && ok "Isaac Lab: ${ISAACLAB_PATH:-/workspace/isaaclab}" \
  || bad "Isaac Lab 경로 없음 (ISAACLAB_PATH=${ISAACLAB_PATH:-unset})"
echo "  OMNI_SERVER=${OMNI_SERVER:-unset}"
echo

# ---------- 2. GPU / 드라이버 ----------
echo "[2] GPU / 드라이버"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader \
      | sed 's/^/  /'
    DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1 | cut -d. -f1)
    if [ "${DRV:-0}" -ge 570 ] 2>/dev/null; then
        ok "드라이버 ${DRV}.x >= 570 (최소 570.169)"
    else
        bad "드라이버가 570.169 미만 — Isaac Sim 5.1 실행 불가"
    fi
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    info "VRAM ${VRAM} MiB — 팀 기준선은 16GB 입니다. 24GB 전제로 튜닝하지 마세요."
else
    bad "nvidia-smi 없음 — GPU 가 붙지 않았습니다"
fi
echo

# ---------- 3. 번들 Python ----------
echo "[3] Python (Isaac Sim 번들)"
PY=""
for cand in "${ISAACLAB_PATH:-/workspace/isaaclab}/isaaclab.sh" ; do
    [ -x "$cand" ] && PY="$cand -p" && break
done
[ -z "$PY" ] && [ -x "${ISAACSIM_ROOT_PATH:-/isaac-sim}/python.sh" ] \
    && PY="${ISAACSIM_ROOT_PATH:-/isaac-sim}/python.sh"

if [ -z "$PY" ]; then
    bad "번들 Python 런처를 찾지 못함 (isaaclab.sh / python.sh)"
    echo
else
    ok "런처: $PY"
    VER=$($PY -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>/dev/null | tail -1)
    case "$VER" in
      3.11*) ok "Python $VER" ;;
      "")    bad "Python 버전 확인 실패" ;;
      *)     bad "Python $VER — Isaac Sim 5.x 는 3.11 전용입니다" ;;
    esac
    echo
    echo "[4] 패키지 버전"
    $PY - <<'PY' 2>&1 | tail -20
def show(label, fn):
    try:
        print(f"  {label:<16} {fn()}")
    except Exception as e:
        print(f"  {label:<16} !! {type(e).__name__}: {e}")

show("isaacsim",  lambda: __import__("isaacsim").__version__)
show("isaaclab",  lambda: __import__("isaaclab").__version__)
try:
    import torch
    print(f"  {'torch':<16} {torch.__version__}")
    print(f"  {'torch.cuda':<16} {torch.version.cuda}")
    print(f"  {'cuda available':<16} {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        p = torch.cuda.get_device_properties(0)
        print(f"  {'device':<16} {p.name} ({p.total_memory/1024**3:.0f} GB)")
except Exception as e:
    print(f"  torch            !! {e}")
PY
fi
echo

# ---------- 5. ROS 2 ----------
echo "[5] ROS 2 설정"
if [ -n "${ROS_DISTRO:-}" ]; then
    bad "ROS_DISTRO=$ROS_DISTRO — 시스템 ROS 2 가 source 되어 있습니다."
    echo "         Isaac Sim 은 Python 3.11, Humble 은 3.10 이라 rclpy 가 깨집니다."
    echo "         Isaac Sim 터미널에서는 setup.bash 를 source 하지 마세요."
else
    ok "ROS_DISTRO 비어 있음 (정상 — 내부 ROS 2 라이브러리 사용)"
fi
echo "  ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-unset}   RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-unset}"
info "로봇측 컨테이너와 위 두 값이 같아야 통신됩니다."
echo

# ---------- 6. 저장소 ----------
echo "[6] 영구 저장소"
if mount | grep -qE ' (/workspace|/data|/mnt/data) .*(nfs|fuse)'; then
    ok "영구 볼륨이 마운트되어 있습니다"
    mount | grep -E ' (/workspace|/data|/mnt/data) ' | sed 's/^/    /'
else
    bad "영구 볼륨 미마운트 — 컨테이너 재시작 시 작업 내용이 사라집니다"
fi
SHM=$(df -h /dev/shm 2>/dev/null | awk 'NR==2{print $2}')
echo "  /dev/shm: ${SHM:-unknown}"
echo

echo "============================================="
echo " 결과: 통과 $PASS · 실패 $FAIL"
[ "$FAIL" -eq 0 ] && echo " 환경이 팀 기준과 일치합니다." \
                  || echo " 실패 항목을 README 의 설정표와 대조하세요."
echo "============================================="
