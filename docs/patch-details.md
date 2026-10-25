# 패치 상세 문서

`insane-codex`의 동작 변화와 파일별 수정 내용을 정리한 문서입니다.

## 1. 기준 소스

| 항목        | 값                                   |
| ----------- | ------------------------------------ |
| 원본 저장소 | `openai/codex`                       |
| 태그        | `rust-v0.165.0`                      |
| 커밋        | `360319d8de`                         |
| 패치 파일   | `patches/no-client-guardrails.patch` |

패치에는 원본 코드와의 차이가 기록되어 있습니다.
빌드 스크립트는 원본 저장소에서 지정한 태그의 소스를 받아 패치를 적용합니다.

## 2. 전체 동작 변화

### Guardian 승인 경로

원본 흐름:

```text
도구가 추가 권한 요청
        │
        v
request_guardian_approval
        │
        v
Guardian 자동 검토
        │
        ├── 승인
        ├── 거절
        └── 사용자에게 질문
```

패치 적용 후:

```text
도구가 추가 권한 요청
        │
        v
기존 호출 형식을 유지한 함수
        │
        └── 항상 판정 없음(None)
                    │
                    v
              사용자 승인 흐름
```

`None`은 Guardian이 승인 여부를 판단하지 않았다는 뜻입니다.
이 값을 받은 코드는 기존 사용자 승인 절차에 처리를 맡깁니다.

### Daybreak 요청 경로

원본 흐름:

```text
CLI/TUI 설정
   │
   v
모델 카탈로그에서 접근 프로그램 선택
   │
   v
turn_context.cyber_access_program
   │
   v
Responses API 요청의 access_programs.cyber
```

패치 적용 후:

```text
CLI/TUI 설정 또는 --cyber-access-program
   │
   v
접근 프로그램 선택·전달 처리 제거
   │
   v
Responses API 요청에 access_programs.cyber 없음
```

### v0.165.0에서 추가된 경로

v0.165.0에는 Guardian v3의 설정과 로컬 증거 저장소 기반 코드가 추가되었습니다.
이 버전에서는 아직 승인 판단 경로에 연결되지 않았고 기본값도 꺼져 있지만, 패치는
관련 기능 설정과 크레이트를 제거합니다.

같은 버전에 추가된 `experimental_network.review_domains`는 관리자가 지정한 도메인을
일반 허용 규칙보다 먼저 네트워크 승인 절차로 보냅니다. 패치는 이 설정을 읽고
프록시와 원격 실행기로 전달해 적용하는 경로를 제거합니다.

## 3. 파일별 변경 사항

### `codex-rs/features/src/lib.rs`

- 다음 기능을 `Removed` 상태로 변경합니다.
  - `GuardianApproval`
  - `GuardianV2`
  - `GuardianV2DecisionsComparison`
  - `CliDaybreak`
  - `ApiKeyCyberAccessPrograms`
- `Features::enabled()`는 위 기능에 대해 항상 `false`를 반환합니다.
- 사용자 설정이나 관리 설정에서 기능을 켜도록 지정해도 비활성 상태를 유지합니다.
- v0.165.0에서 추가된 `GuardianV3`와 `GuardianRecordedItems` 기능 항목은 제거합니다.

### Guardian v3와 검토 기록 관련 파일

- `codex-rs/ext/guardian-v3` 크레이트와 워크스페이스 등록을 제거합니다.
- `GuardianV3ConfigToml`, 설정 스키마와 테스트를 제거합니다.
- Guardian 검토 기록을 상위 세션으로 전달하던 경로와 관련 메타데이터를 제거합니다.

### `codex-rs/config/src/config_requirements.rs`

- `auto_review_required_for_model()`이 항상 `false`를 반환합니다.
- 특정 모델에서 자동 검토를 의무화하던 조건을 제거합니다.

### `codex-rs/core/src/guardian/decision.rs`

- 호출하는 코드가 계속 사용할 수 있도록 함수의 인자와 반환 타입을 유지합니다.
- 함수 내부에서 검토용 스레드를 만들거나 Guardian 확장 기능을 호출하던 코드를 제거합니다.
- 두 함수 모두 검토 결과로 `None`을 전달하도록 바꿉니다.

### `codex-rs/app-server/src/extensions.rs`

- `codex_guardian_v2::install()` 호출을 제거합니다.
- 이에 따라 앱 서버가 Guardian v2 확장 기능을 등록하지 않습니다.

### `codex-rs/app-server/Cargo.toml`

- 앱 서버의 의존성 목록에서 `codex-guardian-v2`를 제거합니다.

### `codex-rs/exec/src/daybreak.rs`

- 파일 전체를 제거합니다.
- 이 모듈은 계정 상태와 모델 카탈로그를 조회해 각 턴에 사용할 접근 프로그램을
  선택했습니다.

### `codex-rs/exec/src/lib.rs`

- `daybreak` 모듈 등록을 제거합니다.
- exec 턴을 시작할 때 `cyber_access_program`을 선택하지 않습니다.

### `codex-rs/core/src/cyber_access_program.rs`

- 모델 제공자에 따라 선택된 접근 프로그램을 유지하던 처리를 제거합니다.
- ChatGPT 로그인과 API 키 인증 모두에서 `AccessPrograms`를 생성하지 않습니다.
- 결과적으로 API 요청에 `access_programs.cyber`가 실리지 않습니다.

### `codex-rs/core/src/tools/orchestrator.rs`

- v0.164.0에서 도입한, 권한을 높여 재시도할 때 Guardian의 재검토를 요구하는
  변경을 되돌립니다.
- 최초 승인 주체를 구분하던 처리를 승인 여부만 기록하는 방식으로 바꿉니다.
  재시도 시 승인 생략 조건을 충족하면 최초 승인을 재사용합니다.

### `codex-rs/protocol/src/openai_models/guardian_v2.rs`

- 비동기 검토 방식의 기본값을 `Conversation`에서 `Snapshot`으로 되돌립니다.
- Guardian이 검토를 수행하지 않는 현재 패치에서는 이 기본값 변경의 효과가 제한적입니다.

### 관리형 네트워크 검토 관련 파일

- `config_requirements`, app-server 프로토콜과 TUI에서 `review_domains` 설정을 제거합니다.
- 네트워크 프록시가 검토 대상 주소를 보관하거나 원격 실행기로 전달하지 않습니다.
- 허용 규칙보다 먼저 네트워크 승인 절차를 실행하던 분기와 관련 기능 협상 코드를
  제거합니다.
- 기존 네트워크 허용·거부 규칙과 일반 사용자 승인 절차는 유지합니다.

## 4. 남아 있는 코드와 데이터 형식

패치는 관련 코드를 모두 삭제하지 않고, 다음 항목을 유지합니다.

- 앱 서버 통신에 쓰이는 Daybreak 및 접근 프로그램 관련 타입
- 대화 스레드의 `daybreak_enabled` 메타데이터
- 대화 기록(rollout)과 SQLite의 저장 필드
- 모델 카탈로그에 있는 사용 가능한 접근 프로그램 정보
- 일부 Guardian 프로토콜 및 컨텍스트 타입
- app-server가 내장하는 압축 형식의 사전 생성 스키마 묶음

이 항목들은 기준 버전의 통신·저장 형식을 유지하기 위해 남겨 둔 것입니다.
삭제할 경우 기존 대화 기록을 읽거나 SDK와 데이터를 주고받는 코드에도 수정이
필요할 수 있습니다. 일부 Guardian v2 모듈과 프로토콜 의존성은 남아 있으므로,
실행 경로의 변경과 관련 코드의 완전한 삭제는 구분해야 합니다. v0.165.0에서 새로
추가된 Guardian v3 크레이트는 제거합니다.

압축된 사전 생성 스키마에는 `review_domains` 항목이 남아 있을 수 있지만, 설정을
실행 정책에 반영하거나 네트워크 프록시로 전달하는 코드는 제거됩니다.

## 5. 변경하지 않는 것

- 파일시스템과 네트워크의 접근 범위를 제한하는 샌드박스
- 사용자에게 실행 여부를 묻는 승인 기능
- 서버에서 관리하는 계정의 접근 권한과 이용 자격
- 모델과 API 서버 자체의 안전 정책
- MCP, 플러그인, 스킬, 웹 검색, 이미지 생성, 멀티 에이전트
- 모델 카탈로그 및 캐시

## 6. 빌드 스크립트 동작

`scripts/build.sh`는 다음 순서로 실행됩니다.

```text
원본 저장소에서 지정한 태그의 소스 받기
        │
        v
git apply --check
        │
        v
패치 적용
        │
        v
cargo build --release --bin codex
        │
        v
dist/에 로컬 바이너리 생성
```

빌드 캐시는 기본적으로 `.build/target/`에 저장됩니다. 빌드에 사용한 임시 원본 소스는
작업이 끝나면 삭제하며, `dist/`와 `.build/`는 Git 추적 대상에서 제외합니다.

## 7. 다른 버전에 적용

패치는 `rust-v0.165.0`을 기준으로 작성했습니다. 다른 태그를 지정할 수는 있지만,
원본 코드가 바뀌면 패치 수정과 재검증이 필요합니다.

```bash
./scripts/build.sh rust-v0.166.0
```

스크립트는 먼저 `git apply --check`를 수행합니다.

- 성공하면 해당 버전에 패치를 적용하고 빌드합니다.
- 실패하면 빌드를 시작하지 않고 중단합니다.

패치 적용 여부와 실제 동작의 호환성은 별개입니다. 원본 코드가 바뀌면 패치가
충돌 없이 적용되더라도 실행 결과가 달라질 수 있습니다.

## 8. 검증 방법

```bash
binary="./dist/codex-rust-v0.165.0-$(uname -m)"

"${binary}" --version
"${binary}" \
  --enable guardian_approval \
  --enable guardianv2 \
  --enable cli_daybreak \
  --enable api_key_cyber_access_programs \
  features list
```

다음 기능의 상태가 모두 `removed`, 활성화 여부가 `false`로 표시되어야 합니다.

```text
api_key_cyber_access_programs
cli_daybreak
guardian_approval
guardianv2
guardianv2_decisions_comparison
```

추가로 `cargo build --release --bin codex`가 성공해야 하며, 실제 네트워크 요청을
검증할 때는 `access_programs` 필드가 생성되지 않는지 확인해야 합니다.
