# WF Description 생성기 — 툴 동작 문서

Description 다나와! 툴(danashin-shopl.github.io/wf-desc-tool/)의 내부 동작 방식을 기록한 문서입니다.
디스크립션 **작성 규칙(규칙 0~11)** 은 shopl-pm 레포의 작성 지침 파일에서 별도 관리됩니다.

---

## 시스템 프롬프트 구조

AI에게 전달되는 시스템 프롬프트는 다음 두 부분으로 구성됩니다.

### 기본 지시문 (코드에 고정)

```
너는 B2B SaaS 기획서의 와이어프레임 Description을 작성하는 전문가야.
아래 규칙을 반드시 따라서 작성해.
```

### 작성 규칙 (가변 — 작성 지침 파일 우선)

- Context > **작성 지침** 파일이 성공적으로 불러와진 경우 → 해당 파일 내용을 규칙으로 사용
- 불러오지 못한 경우 → 아래 디폴트 작성 규칙(DEFAULT_RULES)으로 폴백

---

## 디폴트 작성 규칙 (DEFAULT_RULES)

작성 지침 파일이 없을 때 코드 내에서 폴백으로 사용되는 기본 규칙입니다.
(`wf_description_generator.html` 내 `const DEFAULT_RULES` 상수에 정의)

```
## 작성 범위
- 이미지에 번호 annotation이 있는 경우: annotation이 달린 항목에 대해서만 작성 (annotation 없는 항목은 작성하지 않음)
- 번호 annotation이 없는 경우: 이미지를 직접 분석하여 기술이 필요한 항목을 스스로 정의하고 작성

## 작성 규칙
- 문체: 개조식 명사형 ("~된다" 아닌 "~형태", "~처리", "~노출")
- 컴포넌트명: 굵게 표기 + 괄호로 UI 유형 명시 (예: 정보 항목 선택(Tabs))
- 내용: bullet 형태, 조건/예외/하위 정책은 들여쓰기로 처리
- 상태 기술 순서: 기본 → 조건부 → 예외/엣지케이스
- 권한, 실시간 반영 여부, 파일명 규칙 등 정책성 내용은 반드시 포함
- 각 번호는 줄바꿈으로 구분해서 출력

## 출력 형식
아래 형식을 반드시 지켜서 출력한다.

# 화면 명세

진입 경로: {진입 경로 작성}

| 항목 | Description |
|---|---|
| 1 | (1번 annotation 항목의 디스크립션. 줄바꿈은 <br>으로 처리) |
| 2 | (2번 annotation 항목의 디스크립션) |
```

---

## 사용자 메시지 구조 (buildUserText)

AI에게 전달되는 사용자 메시지는 아래 순서로 구성됩니다.

```
[와이어프레임 이미지]          ← Figma URL로 가져온 PNG (필수)

## 공통 정책                  ← Context > Common 파일 내용 (로드된 경우에만 포함)
...

## Policy                    ← Context > Policy 파일 내용 (로드된 경우에만 포함)
...

위 와이어프레임 이미지의 번호 annotation을 기준으로 각 컴포넌트의 Description을 작성해줘.

[NOTES 요청 지시문]           ← 항상 포함 (아래 참고)
```

### Figma annotation 기반 작성 방식

컴포넌트 목록을 별도로 입력하지 않습니다. Figma 프레임에 번호 annotation이 직접 포함되어 있으며, AI는 이미지에서 번호를 읽어 각 항목의 Description을 작성합니다.

---

## 생성기 노트 (NOTES 기능)

AI 응답에 `---NOTES---` 구분자가 포함된 경우, 구분자 이후 내용은 결과창 하단 "✦ 생성기" 영역에 별도 표시됩니다. 해당 사항이 없으면 구분자를 생략하도록 지시하며, 노트 영역은 표시되지 않습니다.

NOTES 요청 지시문 (`buildUserText`에 항상 포함):

```
디스크립션 작성 후, 아래에 해당하는 사항이 있으면 구분자 "---NOTES---" 를 추가하고 bullet 형태로 작성해줘. 해당 없으면 구분자를 완전히 생략해.
- 참조한 Common / Policy 명세와 충돌하거나 불일치하는 부분
- 명세에 없어서 임의로 판단하고 작성한 내용
- PM에게 추가 확인이 필요한 모호한 부분
```

---

## Context 불러오기 방식

Context 3개 필드(Common, Policy, 작성 지침)는 모두 GitHub API로 불러옵니다.
raw URL이 아닌 `GET /repos/{owner}/{repo}/contents/{path}` API를 사용하므로 **private 레포도 지원**됩니다.

| 경로 형식 | 동작 |
|---|---|
| `경로/파일명.md` | 단일 파일 불러오기 |
| `경로/폴더/` (끝에 `/`) | 해당 폴더 내 모든 .md 파일 병렬 불러오기 |
| `/` | 레포 전체 모든 .md 파일 병렬 불러오기 |

폴더 선택 시 동작: `GET /repos/{owner}/{repo}/git/trees/HEAD?recursive=1`으로 전체 트리를 조회한 뒤, 해당 경로 내 `.md` 파일만 필터링하여 병렬로 fetch합니다. 각 파일은 `### {파일경로}` 구분자로 이어붙여 하나의 context로 구성됩니다.

**작성 지침 경로는 고정**입니다. 파일 탐색기(📁 버튼) 없이 localStorage에 저장된 경로를 자동 사용하며, 페이지 로드 시 자동으로 불러옵니다.

---

## Figma 이미지 가져오기

1. Figma URL에서 `fileKey`(URL 경로)와 `node-id`(쿼리 파라미터) 파싱
2. `GET https://api.figma.com/v1/images/{fileKey}?ids={nodeId}&format=png&scale=2` 호출
3. 반환된 이미지 URL로 PNG 다운로드 → base64 변환 → 미리보기 표시

`node-id` 포맷: URL 상 `123-456` 형식을 Figma API 포맷인 `123:456`으로 자동 변환합니다.

---

## GitHub 저장

생성된 Description은 `PUT /repos/{owner}/{repo}/contents/{path}`로 저장됩니다.

- 파일이 이미 존재하는 경우: SHA 조회 후 업데이트 (덮어쓰기)
- 파일이 없는 경우: 신규 생성

---

## 프롬프트 수정 방법

`wf_description_generator.html` 내에서 수정합니다.

```js
// 폴백 작성 규칙 수정 (작성 지침 파일 미연결 시 사용)
const DEFAULT_RULES = `...`;

// 시스템 프롬프트 기본 지시문 수정
function getSystemPrompt() { ... }

// 사용자 메시지 구조 수정 (context 포함 방식, NOTES 기준 등)
function buildUserText() { ... }
```

디스크립션 **작성 규칙(규칙 0~11)** 은 shopl-pm 레포의 작성 지침 파일에서 수정합니다.
