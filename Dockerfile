# syntax=docker/dockerfile:1
#
# 팀 공통 Isaac Sim / Isaac Lab 환경
# ---------------------------------------------------------------
# 이 이미지가 필요한 이유:
#
#   AIEEV 의 "시작 명령" 필드는 ENTRYPOINT 를 덮어쓰지 않고 인자로 붙습니다.
#   베이스 이미지의 ENTRYPOINT 는 /isaac-sim/runheadless.sh 이므로,
#   콘솔에 'sleep infinity' 를 넣으면 실제로는 이렇게 실행됩니다:
#
#       /isaac-sim/runheadless.sh sleep infinity
#
#   그 결과 Isaac Sim headless 가 매번 떴다가 몇 초 만에 죽고
#   레플리카가 무한 재시작됩니다. ENTRYPOINT 를 비우려면
#   이미지를 새로 만드는 수밖에 없습니다.
#
#   또한 AIEEV 는 포트를 하나만 노출하는 HTTP 게이트웨이(Istio)입니다.
#   Isaac Sim 공식 WebRTC 스트리밍은 영상이 UDP(47995~, 49000~)로 나가서
#   통과하지 못합니다. 그래서 HTTP + WebSocket 만 쓰는 noVNC 로 GUI 를
#   내보냅니다. 포트 80 에 실제 서비스가 생기므로 중계 UNHEALTHY 도
#   함께 해결됩니다.
# ---------------------------------------------------------------
#
# 베이스가 제공하는 것 (절대 덮어쓰지 말 것):
#   Isaac Sim 5.1 · Isaac Lab 2.3.1 · Python 3.11 · CUDA 12.8
#   내부 ROS 2 Humble 라이브러리 (Python 3.11 빌드)
#   ISAACSIM_ROOT_PATH=/isaac-sim   ISAACLAB_PATH=/workspace/isaaclab
#
# 재현성을 위해 다이제스트로 고정합니다. 버전을 올릴 때만 이 줄을 바꾸세요.
FROM nvcr.io/nvidia/isaac-lab@sha256:feb7e318b5c5abb1a385e9b5ec027cdc6fc03567dd1f318657428bde9bca19f2
# 가독성용 태그 참조: nvcr.io/nvidia/isaac-lab:2.3.1

SHELL ["/bin/bash", "-c"]

# --- 개발 편의 도구 ---
# ROS 2 패키지(ros-humble-*)는 여기에 절대 추가하지 마세요.
# Humble 은 Python 3.10 을 끌어와 Isaac Sim 의 3.11 과 충돌합니다.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        vim \
        tmux \
        htop \
        curl \
        wget \
        iputils-ping \
        net-tools \
    && rm -rf /var/lib/apt/lists/*

# --- GUI 스택: Xvfb 가상 디스플레이 + VNC + noVNC ---
# Omniverse Kit 는 Vulkan 으로 GPU 렌더링하고(VK_DRIVER_FILES 는 베이스에 설정됨),
# 창만 Xvfb 디스플레이에 띄웁니다.
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        openbox \
        novnc \
        websockify \
        x11-utils \
        xauth \
    && rm -rf /var/lib/apt/lists/*

# --- ROS 2 DDS 설정 (로봇측 컨테이너와 동일하게 맞출 것) ---
ENV ROS_DOMAIN_ID=0
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# --- headless 자동 실행용 동의 ---
ENV ACCEPT_EULA=Y
ENV PRIVACY_CONSENT=Y

WORKDIR /workspace/isaaclab

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

ENV DISPLAY=:0
ENV SCREEN_GEOMETRY=1920x1080x24

EXPOSE 80

# --- 핵심: ENTRYPOINT 비우기 ---
# 이게 없으면 AIEEV 에서 무슨 시작 명령을 넣든 runheadless.sh 가 실행됩니다.
ENTRYPOINT []

CMD ["/usr/local/bin/start.sh"]
