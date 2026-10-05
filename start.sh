#!/usr/bin/env bash
# =============================================================
#  컨테이너 기동 스크립트 — noVNC 데스크톱 + 셸 상주
#
#  포트 80 에 noVNC 를 띄웁니다. 이것이 두 가지를 동시에 해결합니다:
#    1) 브라우저에서 Isaac Sim GUI 를 보고 조작할 수 있음
#    2) 포트 80 에 응답이 생겨 ContainerRelayDeployment 가 정상 인식
#
#  Isaac Sim 은 자동 실행하지 않습니다. 접속한 뒤 터미널에서 직접 띄우세요:
#      DISPLAY=:0 /isaac-sim/isaac-sim.sh
# =============================================================
set -u

export DISPLAY=:0
SCREEN="${SCREEN_GEOMETRY:-1920x1080x24}"

echo "[start] Xvfb on ${DISPLAY} (${SCREEN})"
Xvfb "$DISPLAY" -screen 0 "$SCREEN" -ac +extension GLX +extension RANDR +render -noreset \
    >/var/log/xvfb.log 2>&1 &

# Xvfb 가 소켓을 열 때까지 대기
for i in $(seq 1 30); do
    [ -e "/tmp/.X11-unix/X${DISPLAY#:}" ] && break
    sleep 0.5
done

# 가벼운 창 관리자 — 없으면 Isaac Sim 창을 이동·리사이즈할 수 없습니다
if command -v openbox >/dev/null 2>&1; then
    echo "[start] openbox"
    openbox >/var/log/openbox.log 2>&1 &
fi

echo "[start] x11vnc on :5900"
x11vnc -display "$DISPLAY" -forever -shared -nopw -noxdamage -quiet \
    >/var/log/x11vnc.log 2>&1 &

echo "[start] noVNC on :80"
websockify --web=/usr/share/novnc 80 localhost:5900 \
    >/var/log/novnc.log 2>&1 &

echo "[start] ready — open the serving endpoint URL in a browser"
echo "[start] then run:  DISPLAY=:0 /isaac-sim/isaac-sim.sh"

# 보조 프로세스가 죽어도 컨테이너는 유지합니다.
sleep infinity
