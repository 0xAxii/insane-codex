# 패치 상세 문서

`insane-codex` 0.172.0 패치의 범위와 검증 내용을 정리합니다.

## 1. 기준 소스

| 항목 | 값 |
| --- | --- |
| 원본 저장소 | `openai/codex` |
| 태그 | `rust-v0.172.0` |
| 커밋 | `3d86e43b075adeba2193ec5c22ac92f55afd82e6` |
| 패치 파일 | `patches/no-client-guardrails.patch` |

패치는 깨끗한 공식 태그에 적용하도록 작성했습니다. Guardian·Daybreak 실행 경로,
사이버 모델의 권한 강제 변경, 콘텐츠 필터 후속 지침과 배포본의 기본 권한
모드만 수정합니다. 서버나 모델 자체의 정책을 변경하지는 않습니다.

## 2. 동작 변화

### Guardian 승인

패치 적용본의 Guardian 판단 함수는 호출 형식을 유지하지만 항상 결과 없음(`None`)을
반환합니다. 따라서 Guardian이 승인을 대신 결정하지 않으며, 승인이 필요한 작업은 원본
Codex의 승인 정책과 사용자 승인 절차가 처리합니다.

```text
추가 권한이 필요한 도구 호출
        │
        v
Guardian 자동 판단 없음
        │
        v
원본 사용자 승인 절차
```

다음 Guardian 연결도 비활성화합니다.

- 모델별 자동 검토 요구
- Guardian v2·v3 app-server 확장 기능
- 네이티브 도구의 실행 전 검토
- 서버 Guardian 평가를 도구 실행 컨텍스트에 연결하는 처리
- Guardian 거절 재검토와 응답 재샘플링
- `thread/guardianReview` 직접 검토 요청
- 자동 검토와 `node_repl` 강제 검토 메타데이터 전송
- Guardian v3 기능, 중첩 승인 컨텍스트와 증거 보드 정리 경로
- Guardian이 하위 에이전트에 재시도 금지 지침을 남기는 경로

`thread/guardianReview` 프로토콜 타입은 호환성을 위해 유지하지만, 요청하면 이
빌드에서는 사용할 수 없다는 오류를 반환합니다.

### Daybreak

`CyberAccessProgram::for_provider`와 `for_auth`는 접근 프로그램을 만들지 않습니다.
따라서 ChatGPT 로그인, API 키와 0.172.0의 헤더 인증 모두 API 요청에 Daybreak
프로그램을 전달하지 않습니다. 호스트가 스레드에 필수 프로그램을 첨부하는 경로와
부모 선택을 네이티브 헬퍼에 전달하는 경로도 결과를 만들지 않습니다.

TUI의 안전 차단 후속 처리에서는 “Enable Daybreak” 항목만 제거합니다. 차단 이유,
안전한 재작성 후보, 대화 분기와 재제출 기능은 원본대로 유지합니다.

### 기본 YOLO와 권한 보존

대화형 TUI와 `codex exec` 모두 권한 모드를 명시하지 않으면 `--yolo`와 같은
구성을 적용합니다. 다음 명시적 선택이 있으면 기본 YOLO를 적용하지 않습니다.

- `--sandbox`
- `--approve-for-me`
- `--ask-for-approval`
- `--yolo`

사이버 모델을 선택할 때 클라이언트가 기존 세션의 권한 프로필, 승인 정책과
검토자를 `workspace-write + on-request + auto_review`로 강제 변경하던 코드는 제거합니다.
실행 중 `/permissions`로 변경하는 원본 경로는 그대로 남습니다.

### 프롬프트 경로

0.172.0의 번들 모델 기본 지침, 현재 로컬 모델 캐시의 Astra·Sol 지침,
`codex-rs/prompts`와 런타임 컨텍스트 조각을 전체 내용 기준으로 확인했습니다.
모델 기본 지침에서 사이버보안 작업 자체를 금지하는 별도 문구는 확인되지
않았습니다. 위험 평가와 거절 문구는 Guardian 검토 프롬프트에 집중돼 있으며,
이 패치에서는 그 실행 경로를 비활성화합니다.

서버가 콘텐츠 필터 오류를 반환한 뒤 클라이언트가 세션에 추가하던
`content_filter_guidance`는 더 이상 기록하지 않습니다. 서버의 필터 자체나 응답은
수정하지 않습니다.

## 3. 파일별 변경 사항

### 기능 설정

`codex-rs/features/src/lib.rs`에서 다음 기능은 `Removed` 상태이며
`Features::enabled()`가 항상 `false`를 반환합니다.

- `GuardianApproval`, `GuardianIncludeAdditionalContext`, `GuardianRecordedItems`
- `GuardianThreadContext`, `GuardianReuseParentCompaction`, `GuardianRootHandoffContext`
- `GuardianNativeMultiAgentHistory`, `GuardianNestedApprovalContext`
- `GuardianEnhancedNodeReplTranscripts`
- `GuardianNodeReplTranscriptImages`, `GuardianTrustOrchestratorConnectors`
- `GuardianConversationHistoryTools`, `GuardianDenialReconsideration`
- `GuardianV2`, `GuardianV2DecisionsComparison`, `GuardianV3`, `GuardianExt`
- `CliDaybreak`, `ApiKeyCyberAccessPrograms`, `DaybreakProgramPropagation`

설정 파일이나 기능 오버라이드에서 위 기능을 켜도 활성화되지 않는 테스트를 추가했습니다.

### Guardian 실행 경로

- `codex-rs/config/src/config_requirements.rs`: 모델별 자동 검토 요구를 끕니다.
- `codex-rs/app-server/Cargo.toml`: Guardian v2를 제품 빌드 의존성에서 제거하고,
  Guardian v3는 테스트 전용 의존성으로만 남깁니다.
- `codex-rs/app-server/src/extensions.rs`: Guardian v2·v3 확장 기능을 등록하지 않습니다.
- `codex-rs/app-server/src/message_processor.rs`: Guardian v3 증거 보드 정리 코드를
  제품 런타임에 연결하지 않습니다.
- `codex-rs/app-server/src/request_processors/turn_processor.rs`:
  `thread/guardianReview` 실행을 거부합니다.
- `codex-rs/core/src/guardian/decision.rs`: Guardian 판단 결과를 만들지 않습니다.
- `codex-rs/core/src/guardian/response_resampling.rs`: 거절 재검토와 재샘플링을 시작하지 않습니다.
- `codex-rs/core/src/session/turn.rs`: 스트림의 Guardian 평가를 도구 실행에 연결하지 않습니다.
- `codex-rs/core/src/tools/registry.rs`: 네이티브 도구 실행 전 Guardian 검토를 호출하지 않습니다.
- `codex-rs/core/src/tools/mod.rs`: 기존 검토 모듈은 테스트 호환성을 위해 테스트 빌드에만 노출합니다.
- `codex-rs/core/src/turn_metadata.rs`: 자동 검토 요구 메타데이터를 전송하지 않습니다.
- `codex-rs/codex-mcp/src/elicitation.rs`: Guardian 판단이 없으면 강제 거절하지 않고
  원본 MCP 권한 및 사용자 승인 경로를 따릅니다.
- `codex-rs/core/src/session_prefix.rs`: Guardian의 재시도 금지 후속 지침을 일반
  하위 에이전트 오류 지침으로 바꿉니다.

### Daybreak 실행 경로

- `codex-rs/core/src/cyber_access_program.rs`: 일반·헤더 인증과 호스트 필수 경로에서
  접근 프로그램을 선택하거나 전달하지 않습니다.
- `codex-rs/core/src/session/session.rs`: 호스트가 스레드에 첨부한 필수 접근 프로그램을
  모델 클라이언트의 검증 상태로 전달하지 않습니다.
- 네이티브 헬퍼의 Daybreak 선택 전파는 `DaybreakProgramPropagation` 기능을 항상
  비활성화해 시작되지 않도록 합니다.
- `codex-rs/tui/src/chatwidget/safety_recourse.rs`: Daybreak 활성화 제안만 제거합니다.

### 기본 권한과 프롬프트 후속 처리

- `codex-rs/utils/cli/src/shared_options.rs`: 권한 모드가 명시되지 않으면 YOLO를 기본으로 선택합니다.
- `codex-rs/tui/src/startup_orchestration.rs`, `codex-rs/exec/src/lib.rs`: TUI와 exec 시작 경로에
  같은 기본값을 적용합니다.
- `codex-rs/tui/src/app/thread_settings.rs`: 모델 선택은 권한·승인 설정을 덮어쓰지 않습니다.
- `codex-rs/core/src/responses_retry.rs`: 콘텐츠 필터 오류 후속 지침을 대화에 추가하지 않습니다.

## 4. 수정하지 않는 영역

0.167 패치에서 발생했던 권한 갱신 회귀를 피하기 위해 다음 코드는 건드리지 않습니다.

- `permission_profile`, `active_permission_profile`, `profile_workspace_roots`
- `sandbox_policy`, `approval_policy`, `approvals_reviewer`
- 세션 설정 적용과 실행 중 `/permissions` 갱신
- `sandbox_workspace_write.network_access`
- 관리형 네트워크의 `review_domains`
- 안전 차단 설명, 재작성, 대화 분기와 재제출
- 캐시, MCP, 스킬, 플러그인과 그 밖의 0.172.0 기능

이 패치는 클라이언트 소스만 수정합니다. 서버나 모델의 정책을 변경한다고 표현하지 않습니다.

## 5. 검증

공식 Rust 1.95.0 도구 체인으로 다음 검증을 수행했습니다.

```bash
git apply --check patches/no-client-guardrails.patch
cargo fmt --all --check
cargo check --locked --bin codex
cargo test --locked -p codex-features guardian_and_daybreak_features_cannot_be_enabled
cargo test --locked -p codex-utils-cli yolo
cargo test --locked -p codex-core cyber_access_program --lib
cargo test --locked -p codex-mcp strict_auto_review --lib
cargo test --locked -p codex-app-server --no-run
RUST_MIN_STACK=67108864 cargo test --locked -p codex-tui \
  daybreak_refusal_does_not_offer_enable_for_the_next_turn --lib
```

추가로 다음 동작을 테스트했습니다.

- Guardian과 Daybreak 기능을 설정으로 켜도 비활성 상태인지 확인
- Daybreak 프로그램이 인증 방식과 관계없이 전달되지 않는지 확인
- 실행 중 설정 새로고침이 원본의 갱신 가능 필드와 고정 필드를 보존하는지 확인
- 권한 프로필 갱신이 다음 턴 환경에 적용되는지 확인
- 샌드박스 변경 시 관리형 네트워크 프록시 설정이 다시 구성되는지 확인
- 사이버 모델 선택이 기존 권한·승인 설정을 덮어쓰지 않는지 확인
- 자동 검토 메타데이터와 콘텐츠 필터 후속 지침이 제외되는지 확인
- 명시적 권한 모드가 없을 때만 YOLO 기본값이 적용되는지 확인

## 6. 빌드와 설치

```bash
./scripts/build.sh rust-v0.172.0
```

빌드 스크립트는 임시 디렉터리에 공식 태그를 복제하고 패치 적용을 확인한 뒤
`cargo build --locked --release --bin codex`를 실행합니다. 로컬 설치는 바이너리의
`--version`을 먼저 확인한 다음 버전별 디렉터리에 두고 공용 심볼릭 링크를 교체합니다.

공개 배포는 macOS, Linux와 Windows의 x86_64·ARM64 여섯 빌드가 모두 성공한 뒤에만
완료로 간주합니다. 실행 바이너리는 Git 저장소가 아니라 GitHub Releases 자산으로만
배포합니다.
