# 패치 상세 문서

`insane-codex` 0.169.0 패치의 범위와 검증 내용을 정리합니다.

## 1. 기준 소스

| 항목 | 값 |
| --- | --- |
| 원본 저장소 | `openai/codex` |
| 태그 | `rust-v0.169.0` |
| 커밋 | `d32063f96c2dff1dc96af839b3952abb6acfeda4` |
| 패치 파일 | `patches/no-client-guardrails.patch` |

패치는 깨끗한 공식 태그에 적용하도록 작성했습니다. Guardian·Daybreak 이외의 소스는
수정하지 않습니다. 공식 태그의 `Cargo.toml` 버전과 맞지 않는 `Cargo.lock`의 로컬
워크스페이스 패키지 버전만 `0.169.0`으로 정규화해 `--locked` 빌드가 가능하게 합니다.

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
- Guardian v2 app-server 확장 기능
- 네이티브 도구의 실행 전 검토
- 서버 Guardian 평가를 도구 실행 컨텍스트에 연결하는 처리
- Guardian 거절 재검토와 응답 재샘플링
- `thread/guardianReview` 직접 검토 요청

`thread/guardianReview` 프로토콜 타입은 호환성을 위해 유지하지만, 요청하면 이
빌드에서는 사용할 수 없다는 오류를 반환합니다.

### Daybreak

`CyberAccessProgram::for_provider`와 `for_auth`는 접근 프로그램을 만들지 않습니다.
따라서 ChatGPT 로그인, API 키와 0.169.0의 헤더 인증 모두 API 요청에 Daybreak
프로그램을 전달하지 않습니다. 호스트가 스레드에 필수 프로그램을 첨부하는 경로와
부모 선택을 네이티브 헬퍼에 전달하는 경로도 결과를 만들지 않습니다.

TUI의 안전 차단 후속 처리에서는 “Enable Daybreak” 항목만 제거합니다. 차단 이유,
안전한 재작성 후보, 대화 분기와 재제출 기능은 원본대로 유지합니다.

## 3. 파일별 변경 사항

### 기능 설정

`codex-rs/features/src/lib.rs`에서 다음 기능은 `Removed` 상태이며
`Features::enabled()`가 항상 `false`를 반환합니다.

- `GuardianApproval`, `GuardianIncludeAdditionalContext`, `GuardianRecordedItems`
- `GuardianThreadContext`, `GuardianReuseParentCompaction`, `GuardianRootHandoffContext`
- `GuardianNativeMultiAgentHistory`, `GuardianEnhancedNodeReplTranscripts`
- `GuardianNodeReplTranscriptImages`, `GuardianTrustOrchestratorConnectors`
- `GuardianConversationHistoryTools`, `GuardianDenialReconsideration`
- `GuardianV2`, `GuardianV2DecisionsComparison`, `GuardianV3`, `GuardianExt`
- `CliDaybreak`, `ApiKeyCyberAccessPrograms`, `DaybreakProgramPropagation`

설정 파일이나 기능 오버라이드에서 위 기능을 켜도 활성화되지 않는 테스트를 추가했습니다.

### Guardian 실행 경로

- `codex-rs/config/src/config_requirements.rs`: 모델별 자동 검토 요구를 끕니다.
- `codex-rs/app-server/src/extensions.rs`: Guardian v2 확장 기능을 등록하지 않습니다.
- `codex-rs/app-server/src/request_processors/turn_processor.rs`:
  `thread/guardianReview` 실행을 거부합니다.
- `codex-rs/core/src/guardian/decision.rs`: Guardian 판단 결과를 만들지 않습니다.
- `codex-rs/core/src/guardian/response_resampling.rs`: 거절 재검토와 재샘플링을 시작하지 않습니다.
- `codex-rs/core/src/session/turn.rs`: 스트림의 Guardian 평가를 도구 실행에 연결하지 않습니다.
- `codex-rs/core/src/tools/registry.rs`: 네이티브 도구 실행 전 Guardian 검토를 호출하지 않습니다.
- `codex-rs/core/src/tools/mod.rs`: 기존 검토 모듈은 테스트 호환성을 위해 테스트 빌드에만 노출합니다.

### Daybreak 실행 경로

- `codex-rs/core/src/cyber_access_program.rs`: 일반·헤더 인증과 호스트 필수 경로에서
  접근 프로그램을 선택하거나 전달하지 않습니다.
- `codex-rs/core/src/session/session.rs`: 호스트가 스레드에 첨부한 필수 접근 프로그램을
  모델 클라이언트의 검증 상태로 전달하지 않습니다.
- 네이티브 헬퍼의 Daybreak 선택 전파는 `DaybreakProgramPropagation` 기능을 항상
  비활성화해 시작되지 않도록 합니다.
- `codex-rs/tui/src/chatwidget/safety_recourse.rs`: Daybreak 활성화 제안만 제거합니다.

## 4. 수정하지 않는 영역

0.167 패치에서 발생했던 권한 갱신 회귀를 피하기 위해 다음 코드는 건드리지 않습니다.

- `permission_profile`, `active_permission_profile`, `profile_workspace_roots`
- `sandbox_policy`, `approval_policy`, `approvals_reviewer`
- 세션 설정 적용과 실행 중 `/permissions` 갱신
- `sandbox_workspace_write.network_access`
- 관리형 네트워크의 `review_domains`
- 안전 차단 설명, 재작성, 대화 분기와 재제출
- 캐시, MCP, 스킬, 플러그인과 그 밖의 0.169.0 기능

이 패치는 클라이언트 소스만 수정합니다. 서버나 모델의 정책을 변경한다고 표현하지 않습니다.

## 5. 검증

공식 Rust 1.95.0 도구 체인으로 다음 검증을 수행했습니다.

```bash
git apply --check patches/no-client-guardrails.patch
cargo fmt --check
cargo check --locked --bin codex
cargo test --locked -p codex-app-server -p codex-tui --no-run
```

추가로 다음 동작을 테스트했습니다.

- Guardian과 Daybreak 기능을 설정으로 켜도 비활성 상태인지 확인
- Daybreak 프로그램이 인증 방식과 관계없이 전달되지 않는지 확인
- 실행 중 설정 새로고침이 원본의 갱신 가능 필드와 고정 필드를 보존하는지 확인
- 권한 프로필 갱신이 다음 턴 환경에 적용되는지 확인
- 샌드박스 변경 시 관리형 네트워크 프록시 설정이 다시 구성되는지 확인

## 6. 빌드와 설치

```bash
./scripts/build.sh rust-v0.169.0
```

빌드 스크립트는 임시 디렉터리에 공식 태그를 복제하고 패치 적용을 확인한 뒤
`cargo build --locked --release --bin codex`를 실행합니다. 로컬 설치는 바이너리의
`--version`을 먼저 확인한 다음 버전별 디렉터리에 두고 공용 심볼릭 링크를 교체합니다.

공개 배포는 macOS, Linux와 Windows의 x86_64·ARM64 여섯 빌드가 모두 성공한 뒤에만
완료로 간주합니다. 실행 바이너리는 Git 저장소가 아니라 GitHub Releases 자산으로만
배포합니다.
