# Isaac Sim 팀 공통 환경

ROSpider 시뮬레이션용 Isaac Sim / Isaac Lab 환경입니다.
**팀원 전원이 아래 설정을 그대로 사용하세요.** 버전이 하나라도 어긋나면 재현이 깨집니다.

---

## 1. 고정 버전

| 구성요소 | 버전 | 비고 |
|---|---|---|
| Isaac Sim | **5.1** | 이미지에 포함 |
| Isaac Lab | **2.3.1** | 이미지에 포함 |
| Python | **3.11** | Isaac Sim 5.x 전용. 3.10/3.12 는 **실행 불가** |
| CUDA | **12.8** | 이미지에 포함 |
| 드라이버 | **≥ 570.169** | 이미지의 `MIN_DRIVER_VERSION` |
| ROS 2 | **Humble (내부 라이브러리)** | apt 설치 금지 — 아래 3절 참고 |

### 이미지

```
nvcr.io/nvidia/isaac-lab:2.3.1
```

- **NGC 로그인 불필요** — 익명으로 pull 됩니다. 레지스트리 액세스를 "공개"로 두세요.
- 압축 크기 약 7.8GB (29 레이어)
- 다이제스트로 완전 고정하려면:
  `nvcr.io/nvidia/isaac-lab@sha256:feb7e318b5c5abb1a385e9b5ec027cdc6fc03567dd1f318657428bde9bca19f2`

### 이미지가 제공하는 경로

| 환경변수 | 값 |
|---|---|
| `ISAACSIM_ROOT_PATH` | `/isaac-sim` |
| `ISAACLAB_PATH` | `/workspace/isaaclab` |
| `OMNI_SERVER` | Isaac 5.1 에셋 S3 |

기본 Entrypoint 는 `/isaac-sim/runheadless.sh` 입니다. 셸 작업용으로 띄우려면 커스텀 이미지가 필요합니다(2절 경고, 6절).

---

## 2. AIEEV 컨테이너 설정

콘솔 → Air Container → 컨테이너 생성. 아래 값을 그대로 입력하세요.

| 필드 | 값 | 이유 |
|---|---|---|
| 컨테이너 이미지 | `ghcr.io/cosmo0511/isaac-sim-env/isaac-lab:2.3.1` | 7절에서 빌드한 커스텀 이미지 |
| 레지스트리 공급자 | GitHub Container Registry | |
| 레지스트리 액세스 | **공개** | 익명 pull 가능, 인증 불필요 |
| 시작 명령 | **비워둘 것** | 이미지의 CMD 가 처리합니다. ⚠️ 아래 경고 참고 |
| **영구 볼륨** | **활성화** | ⚠️ 끄면 재시작 때 전부 소실 |
| 마운트 경로 | `/workspace/projects,/root/.cache` | 작업물 + Isaac 셰이더·에셋 캐시 |
| 공유 메모리 | 끈 상태로 두기 | 꺼도 기본 24GB 가 적용됩니다 |
| GPU | RTX 4070 Ti SUPER (16GB) | 변경 불가 — 바꾸려면 새 컨테이너 |
| 레플리카 | 1 | |

### ⚠️ "시작 명령" 필드의 함정

AIEEV 의 시작 명령은 **ENTRYPOINT 를 교체하지 않고 그 뒤에 인자로 붙습니다.**
베이스 이미지의 ENTRYPOINT 는 `/isaac-sim/runheadless.sh` 입니다.

```
시작 명령에 'sleep infinity' 입력
  → 실제 실행: /isaac-sim/runheadless.sh sleep infinity
  → Isaac Sim 이 잘못된 인자로 뜨다가 수 초 만에 사망
  → 레플리카 무한 재시작 (실제로 1시간에 24개가 쌓였습니다)
  → ContainerRelayDeployment UNHEALTHY
```

필드의 placeholder 가 `-g daemon off; -c /etc/nginx/nginx.conf` 인 것이 단서입니다.
명령이 아니라 **인자** 예시입니다.

**ENTRYPOINT 를 바꾸려면 커스텀 이미지를 만드는 수밖에 없습니다.** 이 레포의
`Dockerfile` 이 `ENTRYPOINT []` 로 비우고 셸 유지용 `CMD` 를 넣어 둡니다.
공식 이미지를 그대로 쓸 때는 시작 명령 필드를 **비워두세요.**

### 환경 변수

```
ACCEPT_EULA=Y
PRIVACY_CONSENT=Y
OMNI_KIT_ACCEPT_EULA=YES
NVIDIA_DRIVER_CAPABILITIES=all
```

> ⚠️ `/workspace/isaaclab` 은 **마운트하지 마세요.** 이미지 안의 Isaac Lab 설치본이 빈 볼륨에 가려집니다.
> 작업 코드는 `/workspace/projects` 에 두세요.

### 현재 구성된 볼륨

| 항목 | 값 |
|---|---|
| 볼륨 ID | `vol-14347d44-33c` |
| 크기 | 30 GB |
| 마운트 | `/workspace/projects`, `/root/.cache` |

### GPU 는 4070 Ti SUPER 로 고정됩니다

영구 볼륨을 쓰는 컨테이너는 **전용 노드에 배포되어 "동급 이상 GPU 자동 대체"와 무관하게 배정**됩니다.
따라서 팀 전원이 동일하게 **RTX 4070 Ti SUPER / 16GB VRAM / 48GB RAM / 8 vCPU** 를 받습니다.

> 환경 수(`--num_envs`)와 해상도는 **16GB 기준으로 튜닝하세요.**
> 과거에 24GB(4090)가 잡힌 적이 있는데 그건 자동 대체가 켜져 있을 때의 일시적인 배정이었습니다.
> 이제는 재현 가능한 쪽으로 고정돼 있습니다.

---

## 3. ROS 2 규칙 — 반드시 지킬 것

Isaac Sim 5.1 은 **Python 3.11**, ROS 2 Humble 은 **Python 3.10** 입니다.
같은 프로세스에서 섞으면 `rclpy` import 가 깨집니다.

| 해야 할 것 | 하지 말아야 할 것 |
|---|---|
| Isaac Sim 내부 ROS 2 라이브러리 사용 | 컨테이너에 `apt install ros-humble-*` |
| 로봇측 노드는 **별도 컨테이너**에서 실행 | Isaac Sim 터미널에서 `source /opt/ros/humble/setup.bash` |
| DDS 로 통신 | |

두 컨테이너에서 아래 값을 **동일하게** 맞추세요:

```bash
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

ROSpider 쪽은 기존 `rospider:humble` 이미지를 그대로 쓰면 됩니다.

---

## 4. GUI 로 Isaac Sim 쓰기

"headless" 는 GUI 를 못 쓴다는 뜻이 아닙니다. 모니터 없는 서버에서 렌더링하고
화면을 네트워크로 내보내는 방식을 말합니다. 이 환경은 **noVNC** 로 내보냅니다.

### 왜 WebRTC 가 아니라 noVNC 인가

| 방식 | 포트 | AIEEV |
|---|---|---|
| WebRTC (NVIDIA 공식) | TCP 8211 + **UDP** 47995~48012, 49000~49007 | ❌ UDP 미통과 |
| **noVNC** | **TCP 80 하나** (HTTP + WebSocket) | ✅ |

AIEEV 는 포트를 하나만 노출하는 HTTP 게이트웨이(Istio)입니다. WebRTC 는 영상이
UDP 로 나가서 통과하지 못합니다. noVNC 는 HTTP 와 WebSocket 만 쓰므로 그대로 통합니다.

### 접속

컨테이너가 뜨면 아래 주소를 브라우저에서 엽니다. **`?path=` 파라미터가 반드시 필요합니다.**

```
https://ap-1.aieev.cloud/endpoints/isaac-sim-test/vnc.html?path=endpoints/isaac-sim-test/websockify&autoconnect=true&resize=scale
```

AIEEV 게이트웨이가 `/endpoints/<이름>/` 프리픽스를 붙이는데, noVNC 는 기본적으로
루트(`/websockify`)로 WebSocket 을 열려고 해서 연결이 실패합니다. `path` 로 실제 경로를
알려줘야 붙습니다. 연결되면 탭 제목이 `<컨테이너ID>:0 - noVNC` 로 바뀝니다.

프리픽스 없이 `.../endpoints/isaac-sim-test` 만 열면 noVNC 페이지는 뜨지만
"noVNC에 오류가 발생했습니다" 가 표시됩니다.

접속 직후 화면은 **검은색**입니다. Xvfb 빈 데스크톱이라 정상이며,
아래처럼 앱을 띄우면 화면에 나타납니다.

### Isaac Sim 띄우기

GUI 는 자동 실행하지 않습니다. 터미널에서 직접 띄우세요.

```bash
DISPLAY=:0 /isaac-sim/isaac-sim.sh
```

Isaac Lab 스크립트를 GUI 로 볼 때도 같습니다. `--headless` 를 빼면 됩니다.

```bash
cd /workspace/isaaclab && DISPLAY=:0 ./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py
```

첫 실행은 셰이더 컴파일 때문에 수 분~수십 분 걸립니다. 캐시가 `/root/.cache` 에
쌓이고 그 경로는 영구 볼륨이라, 두 번째부터는 훨씬 빠릅니다.

### 해상도 바꾸기

AIEEV 환경 변수에 `SCREEN_GEOMETRY` 를 추가하세요 (기본 `1920x1080x24`).

## 5. 접속 후 첫 작업

```bash
bash verify_env.sh
```

`실패 0` 이 나와야 정상입니다. 실패가 있으면 위 설정표와 대조하세요.

### Isaac Lab 실행

```bash
cd /workspace/isaaclab && ./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py --headless
```

Python 을 직접 부르지 말고 항상 `isaaclab.sh -p` 를 거치세요. 번들 Python 3.11 이 그쪽에 있습니다.

---

## 6. PyTorch 버전에 대해

팀 논의에서 PyTorch 2.7.0 이 언급됐지만, **이미지에 포함된 버전을 그대로 쓰세요.**
Isaac Lab 2.3.1 은 특정 torch 빌드에 맞춰 검증돼 있어서, 강제로 바꾸면 깨집니다.

`verify_env.sh` 가 실제 버전을 출력합니다. 그 값을 팀 기준으로 삼으면 됩니다.
CUDA 12.8 은 이미 일치합니다.

---

## 7. 커스텀 이미지

공식 이미지를 그대로 쓰면 `ENTRYPOINT` 때문에 셸 작업용으로 띄울 수 없습니다(2절 경고).
셸을 상주시키려면 이 레포의 `Dockerfile` 로 이미지를 만들어 쓰세요.

```
Dockerfile 커밋
  → GitHub Actions (.github/workflows/build-image.yml)
  → ghcr.io/cosmo0511/isaac-sim-env/isaac-lab:2.3.1
  → AIEEV 컨테이너 이미지 URL 에 입력
```

GHCR 패키지를 public 으로 바꾸면 레지스트리 인증이 필요 없습니다.
베이스가 7.8GB 라 첫 빌드·푸시는 오래 걸립니다.

개인 작업용 패키지는 영구 볼륨(`/workspace/projects`)에 설치하고 이미지는 건드리지 마세요.
