# /doc-wiki

**schema_ingest 전처리**: 도메인 문서를 읽고 구조화된 도메인 wiki를 생성한다.
CQ 도출의 입력이 되는 중간 산물이다.

## 입력

`/doc-wiki [문서경로]`

- 문서경로 생략 시 기본값: `ontology/projects/industry_safety/resources/산업안전보건법.md`

---

## 실행 절차

### 1단계 — 문서 구조 파악

파일 첫 100줄을 읽어 다음을 파악한다:

1. **구조 단위**: 문서가 어떤 단위로 쪼개지는가?
   - 예: 조항(`제N조`), 섹션(`# Section N`), 요구사항(`REQ-N`), 규칙(`Rule N`), 조항(`Article N`) 등
2. **의무 표현**: 이 문서에서 의무를 나타내는 표현이 무엇인가?
   - 예: `하여야 한다`, `shall`, `must`, `is required to` 등
3. **문서 크기**: 전체를 한 번에 읽을 수 있는가? (25,000 토큰 초과 시 청크 처리 필요)

파악한 구조를 한 줄로 요약한다:
```
구조 단위: [패턴], 의무 표현: [패턴], 총 크기: [토큰 수]
```

---

### 2단계 — 전체 단위 열거 (코드 생성 후 실행)

1단계에서 파악한 구조에 맞는 Python 스크립트를 작성하여 실행한다.

**스크립트 요건 (문서 포맷에 관계없이 공통):**
- 문서의 **모든 구조 단위**를 빠짐없이 열거
- 각 단위에 대해: (번호/ID, 헤더, 의무 표현 포함 여부, 첫 문장 요약) 출력
- 결과를 임시 파일(`/tmp/doc_units.txt`)에 저장

**예시 — 한국 법령 (`제N조` 패턴):**
```python
import re
with open("[문서경로]", encoding="utf-8") as f:
    content = f.read()
chunks = re.split(r"(?=^제\d+조)", content, flags=re.MULTILINE)
obligation_keywords = r"하여야\s*한다|해야\s*한다|아니\s*된다|하여서는\s*아니"
# ... 열거 및 분류
```

**예시 — 영문 규격/표준 (`Article N` 또는 `# Section N` 패턴):**
```python
import re
with open("[문서경로]", encoding="utf-8") as f:
    content = f.read()
chunks = re.split(r"(?=^(Article|Section)\s+\d+)", content, flags=re.MULTILINE|re.IGNORECASE)
obligation_keywords = r"\bshall\b|\bmust\b|\bis required to\b|\bshall not\b"
# ... 열거 및 분류
```

**코드 실행 실패 또는 구조 단위가 불분명한 경우 — Fallback:**
코드 대신 아래 방법으로 전환한다:
1. 파일을 5,000줄씩 청크로 읽는다
2. 각 청크에서 의무 표현이 포함된 문단을 모두 추출한다
3. 추출된 문단을 번호와 함께 목록화한다

Fallback 사용 시 반드시 명시: `[Fallback 사용: 코드 기반 열거 실패 사유 — ...]`

---

### 3단계 — 조항별 분류

2단계에서 얻은 전체 목록을 기반으로 각 의무 단위를 분류한다.

**분류 기준:**

| 항목 | 선택지 |
|---|---|
| 의무 주체 | 사업주·도급인 / 정부·장관 / 전문기관 / 기타 |
| SHACL 검증 가능성 | 가능 / 부분 / 불가 |
| 수치 기준 | 본문 명시 / 하위법령 위임 / 없음 |

**SHACL 검증 가능성 판단 기준:**
- `가능`: 정량 기준이 있고 RDB 데이터로 확인 가능
- `부분`: 일부 요소만 검증 가능 (예: 실시 여부는 가능, 적절성은 불가)
- `불가`: 주관적 판단 필요 / 현장 상황 의존 / 외부 전문가 판단 필요

---

### 4단계 — wiki 작성

분류 결과를 기반으로 `ontology/projects/industry_safety/resources/wiki/[문서명].md`를 작성한다.

```markdown
---
type: domain-wiki
source: [원본 문서 경로]
enumeration-method: [code | fallback]
total-units: N
updated: YYYY-MM-DD
---

> 분석 범위: 총 N개 구조 단위 전수 조사.
> 열거 방법: [code 기반 / fallback 기반 (사유: ...)]

## 1. 핵심 엔티티

| 엔티티 | 정의 | 근거 |
|---|---|---|

## 2. 사업주 의무 조항 (SHACL 검증 대상)

주체 = 사업주·도급인 이고 SHACL 가능성 = 가능 또는 부분인 항목만 수록.

| 단위 | 의무 내용 | 조건/기준 | SHACL 가능성 |
|---|---|---|---|

## 3. 수치 기준

### 본문 명시 수치
| 기준 | 값 | 근거 |
|---|---|---|

### 하위법령·외부 위임 수치
| 기준 | 위임 대상 | 근거 |
|---|---|---|

## 4. 관계
주체 → 동사 → 객체 형태로 열거.

## 5. 검증 불가 조항

주체 = 사업주이지만 SHACL 불가로 분류된 항목.

| 단위 | 이유 |
|---|---|
```

---

### 5단계 — 검토 요청

```
=== Domain Wiki 생성 완료 — Human Review ===

파일: ontology/projects/industry_safety/resources/wiki/[문서명].md
열거 방법: [code | fallback (사유: ...)]

전수 조사 결과:
  총 구조 단위: N개
  의무 단위: N개
    └ 사업주 의무: N개
      └ SHACL 가능: N개  → "사업주 의무 조항" 표 수록
      └ SHACL 불가: N개  → "검증 불가 조항" 표 수록
    └ 정부/기관/기타 의무: N개  → 미수록

검토 항목:
□ 열거 방법이 code인 경우: 구조 단위 패턴이 문서와 맞는가?
□ 열거 방법이 fallback인 경우: 의무 문단이 충분히 추출되었는가?
□ SHACL 가능/불가 분류가 타당한가?
□ 핵심 엔티티가 빠짐없이 추출되었는가?
□ 하위법령 위임 항목이 정확히 표기되었는가?

승인 후 /cq-extract 으로 다음 단계 진행.
```
