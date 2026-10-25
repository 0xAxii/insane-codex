# insane-codex

Codex CLI의 자동 승인 검토, Daybreak, 관리형 네트워크 검토 경로를 제거하는 패치입니다.

Codex CLI는 터미널에서 AI에게 코드 작성이나 명령 실행을 맡기는 도구입니다.
이 저장소에는 원본 코드의 변경 사항을 담은 패치와 빌드 스크립트가 있습니다.
직접 빌드하지 않아도 사용할 수 있도록 GitHub Releases에서 실행 파일도 제공합니다.

## 무엇이 달라지나요?

### Guardian: 실행 승인 요청을 자동으로 검토하는 기능

Codex가 명령을 실행할 때 추가 승인을 요청하는 경우가 있습니다.
Guardian은 이런 요청을 자동으로 검토해 승인 여부를 판단합니다.

패치를 적용하면 Guardian은 판단을 내리지 않고, 기존 사용자 승인 절차에 처리를 맡깁니다.
특정 모델에서 자동 검토를 요구하던 조건과 Guardian v2 등록도 제거합니다.
v0.165.0에 추가된 Guardian v3 기반 코드와 검토 기록 전달 기능도 포함하지 않습니다.

### Daybreak: 보안 관련 접근 프로그램 선택

Daybreak는 서버의 보안 관련 접근 프로그램(access program) 이름입니다.
원본 Codex는 사용할 접근 프로그램을 선택하고, 그 식별 정보를 서버 요청에 포함할 수 있습니다.

패치를 적용하면 접근 프로그램을 선택하고 그 식별 정보를 요청에 포함하던 처리가 제거됩니다.

### 관리형 네트워크 검토

v0.165.0은 관리 설정의 `review_domains`에 지정된 주소를 일반 허용 규칙보다 먼저
승인 절차로 보내는 기능을 추가했습니다. 패치는 이 설정과 전달·적용 경로를 제거합니다.
기존 네트워크 샌드박스와 사용자가 직접 승인하는 기능은 그대로 유지합니다.

### 재시도할 때의 승인 처리

명령이 샌드박스 제한에 막혀 더 넓은 권한으로 재시도할 때의 승인 처리도 바뀝니다.
앞서 승인한 주체를 구분하던 처리를 되돌려, 조건에 따라 최초 승인을 재사용합니다.

## 변경 범위

캐시, 외부 도구 연결(MCP), 스킬, 플러그인 등은 기준 버전의 구현을 유지합니다.
명령의 접근 범위를 제한하는 샌드박스와 사용자 승인 기능도 유지합니다.
서버와 모델 자체의 정책은 이 패치의 수정 대상에 포함되지 않습니다.

관련 타입과 저장 필드 등 일부 코드는 남아 있습니다. 파일별 변경 내용과
남아 있는 코드는 [상세 문서](docs/patch-details.md)에 정리했습니다.

## 설치하기

### macOS와 Linux

macOS와 Linux에서는 설치 스크립트가 운영체제와 CPU를 확인하고 알맞은 실행 파일을
내려받아 `~/.local/bin/insane-codex`에 설치합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/0xAxii/insane-codex/main/scripts/install.sh | bash
```

설치가 끝나면 실행합니다.

```bash
insane-codex --version
insane-codex
```

명령을 찾지 못하면 `~/.local/bin`을 `PATH`에 추가합니다.

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

PowerShell에서 다음 명령을 실행합니다. CPU에 맞는 실행 파일을 내려받고 사용자
`PATH`에 설치 경로를 추가합니다.

```powershell
irm https://raw.githubusercontent.com/0xAxii/insane-codex/main/scripts/install.ps1 | iex
```

설치가 끝나면 새 PowerShell이나 터미널을 열고 실행합니다.

```powershell
insane-codex --version
insane-codex
```

현재 제공하는 실행 파일은 다음과 같습니다.

| 운영체제 | CPU                     |
| -------- | ----------------------- |
| macOS    | Apple Silicon (`arm64`) |
| macOS    | Intel (`x86_64`)        |
| Linux    | `x86_64`                |
| Linux    | `arm64`                 |
| Windows  | `x86_64`                |
| Windows  | `arm64`                 |

각 실행 파일은 [Releases](https://github.com/0xAxii/insane-codex/releases)에서도
직접 받을 수 있습니다. Release에는 플랫폼별 실행 파일 패키지만 올립니다.

## 소스에서 빌드하기

Git과 Rust 빌드 도구가 설치되어 있어야 합니다. 저장소를 받은 뒤 기준 버전으로
빌드합니다.

```bash
git clone https://github.com/0xAxii/insane-codex.git
cd insane-codex
./scripts/build.sh rust-v0.165.0
```

빌드한 실행 파일을 `insane-codex` 명령으로 등록합니다.

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/dist/codex-rust-v0.165.0-$(uname -m)" \
  "$HOME/.local/bin/insane-codex"
```

`insane-codex` 명령을 찾지 못하면 `PATH`에 디렉터리를 추가합니다.
zsh와 bash에서는 다음 명령을 실행합니다.

```bash
export PATH="$HOME/.local/bin:$PATH"
```

fish에서는 다음 명령을 실행합니다. 이 설정은 새 터미널에서도 유지됩니다.

```fish
fish_add_path "$HOME/.local/bin"
```

zsh나 bash에서도 설정을 계속 유지하려면 위의 `export` 명령을 사용하는 셸의
설정 파일에 추가합니다.

설정을 마치면 어느 디렉터리에서나 실행할 수 있습니다.

```bash
insane-codex --version
insane-codex
```

직접 빌드하는 경우에도 버전마다 한 번만 빌드하면 됩니다. 평소에는
`insane-codex` 명령만 실행하면 됩니다.

## 버전과 배포 방식

| 항목          | 내용                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------ |
| 기준 원본     | OpenAI Codex CLI **0.165.0** (`rust-v0.165.0`)                                             |
| 저장소에 포함 | 패치, 빌드·설치 스크립트, 문서                                                             |
| 실행 파일     | GitHub Releases에서 macOS·Linux·Windows용 파일을 제공합니다.                               |
| 업데이트      | 자동으로 업데이트되지 않습니다. 새 버전은 패치 적용 여부를 확인한 뒤 다시 빌드해야 합니다. |
