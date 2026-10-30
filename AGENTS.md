# insane-codex 작업 규칙

이 파일은 저장소 전체에 적용됩니다.

## 버전 업데이트

- 새 Codex CLI 태그가 나오면 이전 기준 태그와 새 태그의 차이를 먼저 검토합니다.
- Guardian, Daybreak, 안전 차단 후속 처리 등 클라이언트 측 보안 검토 경로가 새로 추가되었는지 확인합니다.
- 기존 패치를 새 태그에 이식하고, 새로 추가된 클라이언트 측 검토 경로도 같은 범위에서 제거합니다.
- 캐시, MCP, 스킬, 플러그인 등 보안 검토와 무관한 새 기능은 원본 구현을 유지합니다.
- 서버나 모델의 정책을 바꾼다고 문서에 표현하지 않습니다.
- 기준 태그를 바꾸면 빌드 스크립트, 릴리스 워크플로, README와 상세 문서의 버전도 함께 갱신합니다.

## 검증

- 깨끗한 공식 태그에서 `git apply --check`로 패치 적용 여부를 확인합니다.
- 패치를 실제로 적용한 소스에서 `cargo check --locked --bin codex`를 실행합니다.
- 관련 테스트가 있으면 최소한 테스트 바이너리 컴파일까지 확인합니다.
- 새 바이너리는 직접 실행하여 `--version`이 예상 버전인지 확인한 뒤 설치합니다.
- 공개 배포는 macOS, Linux와 Windows의 x86_64·ARM64 바이너리가 모두 성공한 뒤 완료로 봅니다.

## 로컬 설치 방식

- `~/.local/bin/insane-codex`는 항상 같은 진입점으로 유지합니다.
- 실제 바이너리는 버전별 디렉터리에 설치합니다.

  ```text
  ~/.local/libexec/insane-codex-v0.166.0/insane-codex
  ~/.local/libexec/insane-codex-v0.167.0/insane-codex
  ```

- 새 버전은 다음 순서로 설치합니다.

  1. `~/.local/libexec/insane-codex-v<version>/insane-codex`에 설치합니다.
  2. 해당 경로의 바이너리를 직접 실행하여 검증합니다.
  3. 검증에 성공한 경우에만 `~/.local/bin/insane-codex` 심볼릭 링크를 새 버전으로 교체합니다.
  4. `codex --version`과 `insane --version`을 모두 확인합니다.

- 새 바이너리를 검증하기 전에는 현재 심볼릭 링크를 바꾸지 않습니다.
- `codex`는 기존 Ctrl+C 보호 래퍼를 거쳐 `~/.local/bin/insane-codex`를 실행하도록 유지합니다.
- `codex`와 `insane`에 설정된 `--yolo` 동작을 유지합니다.

## 저장소와 배포 파일

- 실행 바이너리를 Git 저장소에 커밋하지 않습니다.
- 저장소에는 패치, 빌드·설치 스크립트, CI 설정과 문서만 둡니다.
- 플랫폼별 바이너리는 GitHub Releases의 자산으로만 배포합니다.
