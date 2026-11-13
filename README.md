# insane-codex

OpenAI Codex CLI에서 Guardian과 Daybreak의 클라이언트 측 경로만 비활성화하는 패치입니다.

이 저장소에는 공식 Codex CLI 소스에 적용하는 패치와 빌드·설치 스크립트가 있습니다.
플랫폼별 실행 파일은 GitHub Releases에서 제공합니다.

## 무엇이 달라지나요?

### Guardian

Guardian은 명령 실행이나 도구 호출에 필요한 승인을 자동으로 검토할 수 있습니다.
패치 적용본에서는 Guardian 판단이 결과를 내리지 않으며, 승인이 필요하면 원본 Codex의
사용자 승인 절차가 처리합니다.

0.168.0에 있는 다음 경로도 비활성화합니다.

- Guardian 기능 플래그와 모델별 자동 검토 요구
- Guardian v2 확장 기능 등록
- 네이티브 도구 호출의 Guardian 사전 검토
- 서버가 전달한 Guardian 평가의 도구 실행 연결
- 거절 재검토와 응답 재샘플링
- app-server의 `thread/guardianReview` 직접 검토

호환성에 필요한 타입과 모듈은 가능한 한 남겨 둡니다.

### Daybreak

Daybreak는 사이버 보안 관련 접근 프로그램입니다. 패치 적용본은 인증 방식이나 모델
카탈로그와 관계없이 Daybreak 접근 프로그램을 선택하거나 API 요청에 전달하지 않습니다.
안전 차단 화면에 표시되던 “Enable Daybreak” 선택지도 제거합니다.

## 그대로 유지하는 기능

Guardian과 Daybreak 이외의 동작은 공식 0.168.0 구현을 유지합니다.

- 승인 정책, 권한 프로필, 샌드박스와 `/permissions`
- 실행 중 권한·샌드박스·승인 검토자 갱신
- `workspace-write`의 네트워크 설정과 관리형 `review_domains`
- 안전 차단 설명, 안전한 재작성, 대화 분기와 재제출
- 캐시, MCP, 스킬, 플러그인과 다른 명령
- 사용자가 지정한 명령행 옵션과 설정

`codex`와 `insane` 실행 경로는 `--yolo`를 자동으로 추가하지 않습니다. 서버나
모델의 정책은 이 클라이언트 패치의 수정 대상이 아닙니다.

파일별 변경 내용과 검증 결과는 [상세 문서](docs/patch-details.md)에 정리했습니다.

## 설치하기

### macOS와 Linux

설치 스크립트는 운영체제와 CPU에 맞는 릴리스 파일을 내려받아
`~/.local/libexec/insane-codex-v0.168.0/insane-codex`에 설치합니다. 새 바이너리의
버전을 확인한 뒤 `~/.local/bin/insane-codex` 심볼릭 링크를 교체합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/0xAxii/insane-codex/main/scripts/install.sh | bash
```

```bash
insane-codex --version
insane-codex
```

명령을 찾지 못하면 `~/.local/bin`을 `PATH`에 추가합니다.

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

PowerShell에서 다음 명령을 실행합니다.

```powershell
irm https://raw.githubusercontent.com/0xAxii/insane-codex/main/scripts/install.ps1 | iex
```

새 PowerShell이나 터미널을 연 뒤 실행합니다.

```powershell
insane-codex --version
insane-codex
```

제공 대상은 다음 여섯 플랫폼입니다.

| 운영체제 | CPU |
| --- | --- |
| macOS | Apple Silicon (`arm64`) |
| macOS | Intel (`x86_64`) |
| Linux | `x86_64` |
| Linux | `arm64` |
| Windows | `x86_64` |
| Windows | `arm64` |

릴리스 파일은 [Releases](https://github.com/0xAxii/insane-codex/releases)에서도
직접 받을 수 있습니다. 실행 바이너리는 Git 저장소에 커밋하지 않습니다.

## 소스에서 빌드하기

Git과 Rust 빌드 도구가 필요합니다.

```bash
git clone https://github.com/0xAxii/insane-codex.git
cd insane-codex
./scripts/build.sh rust-v0.168.0
```

로컬에 버전별로 설치하려면 다음과 같이 실행합니다.

```bash
mkdir -p "$HOME/.local/libexec/insane-codex-v0.168.0" "$HOME/.local/bin"
install -m 755 "$(pwd)/dist/codex-rust-v0.168.0-$(uname -m)" \
  "$HOME/.local/libexec/insane-codex-v0.168.0/insane-codex"
"$HOME/.local/libexec/insane-codex-v0.168.0/insane-codex" --version
ln -sfn "$HOME/.local/libexec/insane-codex-v0.168.0/insane-codex" \
  "$HOME/.local/bin/insane-codex"
```

## 버전과 배포 방식

| 항목 | 내용 |
| --- | --- |
| 기준 원본 | OpenAI Codex CLI **0.168.0** (`rust-v0.168.0`) |
| 원본 커밋 | `9480ec100c3edee9fc69172e8e80a4730444094d` |
| 저장소에 포함 | 패치, 빌드·설치 스크립트, CI 설정과 문서 |
| 실행 파일 | GitHub Releases의 macOS·Linux·Windows용 패키지 |
| 업데이트 | 새 공식 태그마다 패치 적용과 테스트를 다시 확인 |
