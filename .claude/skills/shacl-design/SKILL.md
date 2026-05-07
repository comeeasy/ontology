# /shacl-design

**schema_ingest 3단계**: 단일 CQ에 대한 SHACL Shape을 설계하고 검증한다.

## 입력

`/shacl-design [cq_file] [cq_n]`

- `cq_file`: CQ 목록 파일 경로 (예: `ontology/projects/industry_safety/resources/cq.md`)
- `cq_n`: 설계할 CQ 번호 (예: `1` → `CQ_1`)

예: `/shacl-design ontology/projects/industry_safety/resources/cq.md 1`

---

## 설계 원칙

### 1. 먼저 생각하라 (Think Before Building)

가정하지 말 것. 혼란을 숨기지 말 것. 트레이드오프를 드러낼 것.

구현 전에:
- CQ의 준수 조건을 SPARQL로 표현할 때 경계 케이스가 전부 커버되는지 확인한다.
- `sh:SPARQLConstraint`(복잡한 집계·존재 조건)와 `sh:property`(단순 존재·카디널리티) 중 선택 근거를 명시한다.
- 적용 제외 조건(예: 상시근로자 49인 이하 → 무조건 PASS)을 어떻게 처리할지 결정한다 — FILTER로 제외할지, 별도 SHACL 조건으로 분리할지.
- 불확실한 것이 있으면 멈춘다. 무엇이 혼란스러운지 명시하고 묻는다.

### 2. 단순함 우선 (Simplicity First)

문제를 푸는 최소한의 Shape. 추측성 모델링 금지.

- 이 CQ를 검증하는 데 필요한 Shape·Constraint만 작성한다.
- 재사용을 위한 추상 Shape을 만들지 않는다.
- `sh:select` 내 SPARQL은 실제로 필요한 JOIN만 포함한다.
- Shape 파일이 20줄로 끝날 수 있으면 60줄로 쓰지 않는다.
- 자문한다: "온톨로지 전문가가 보면 과하다고 할까?" — 그렇다면 줄인다.

### 3. 외과적 수정 (Surgical Changes)

건드려야 할 것만 건드린다. 자신이 만든 문제만 치운다.

기존 Shape 파일을 읽을 때:
- SPARQL 패턴·sh:message 스타일을 파악하되, 기존 파일을 수정하지 않는다.
- 기존 네이밍 관례를 그대로 따른다.

새 파일에서:
- 정의한 Shape이 이 CQ에서 실제로 쓰이는지 확인한다.
- 쓰이지 않는 Shape·Constraint는 삭제한다.

### 4. 목표 기반 실행 (Goal-Driven Execution)

성공 기준을 정의하고, 검증될 때까지 반복한다.

이 스킬의 성공 기준:
1. `cq_[n].shacl.ttl` 작성 → 검증: 파일 존재, Turtle 문법 오류 없음
2. pyshacl 검증 → PASS 케이스: Conformant / FAIL 케이스: Violation 정확히 감지
3. 경계 케이스 커버 → 임계값·적용 제외 조건이 모두 올바른 결과를 냄

pyshacl 실패 시:
- 오류 메시지와 위반 보고서를 읽고 원인을 분석한다.
- SPARQL 수정 후 재실행한다.
- 2회 실패 시 멈추고 사용자에게 오류 내용을 보고한다.

---

## 실행 절차

### 1단계 — 컨텍스트 읽기

- `[cq_file]` 전체를 읽어 `CQ_[cq_n]` 섹션(준수 조건·검증 대상·경계 케이스)을 확인한다.
- `ontology/projects/industry_safety/schema/cq_[cq_n].ttl` — 사용할 클래스·프로퍼티 확인.
- `ontology/projects/industry_safety/shapes/` — 기존 Shape 파일 전체 (패턴·스타일 파악).

### 2단계 — 설계 결정 명시

파일 작성 전에 다음을 서술한다:

```
[설계 결정]
- Shape 방식: [sh:SPARQLConstraint | sh:property] + 선택 이유
- 검증 대상 (sh:targetClass): [클래스]
- 적용 제외 조건 처리: [FILTER 방식 | 별도 조건 분리]
- 경계 케이스 반영 방법: [구체적 FILTER/HAVING 조건]
- 제외한 후보: [목록 + 제외 이유]
- 불확실한 사항: [있으면 명시, 없으면 "없음"]
```

불확실한 사항이 있으면 이 시점에 사용자에게 묻는다. 임의로 선택하지 않는다.

### 3단계 — 파일 작성

`ontology/projects/industry_safety/shapes/cq_[cq_n].shacl.ttl` 생성.

```turtle
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix is: <http://infiniq.co.kr/2026/industry_safety#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

is:CQ[n]Shape
    a sh:NodeShape ;
    sh:targetClass is:사업장 ;
    sh:sparql [
        sh:message "..." ;
        sh:select """
            PREFIX is: <http://infiniq.co.kr/2026/industry_safety#>
            SELECT $this ...
            WHERE { ... }
        """ ;
    ] .
```

**주의사항**:
- `sh:select` 내부에 반드시 `PREFIX` 선언 포함 (TTL prefix 미상속).
- `sh:message`: 도메인 전문가가 읽을 수 있는 한국어, 근거 조항 명시.

### 4단계 — pyshacl 검증

테스트 ABox(`ontology/projects/industry_safety/abox/cq_[n].abox.ttl`)가 없으면 최소 인라인 데이터를 `/tmp/cq_[n]_test.ttl`로 작성한다.

테스트 데이터는 반드시 다음을 포함한다:
- PASS 케이스 (준수): 조건을 충족하는 인스턴스
- FAIL 케이스 (위반): 조건을 위반하는 인스턴스
- 경계 케이스: CQ의 임계값·적용 제외 조건 검증

```bash
pyshacl \
    -s ontology/projects/industry_safety/shapes/cq_[cq_n].shacl.ttl \
    -d /tmp/cq_[n]_test.ttl \
    --ont-graph ontology/projects/industry_safety/schema/cq_[cq_n].ttl
```

- Conformant: 다음 단계 진행
- Violation 발생 시: 오류 분석 → SPARQL 수정 → 재실행 (최대 2회)
- 2회 실패 시: 멈추고 오류 내용 보고

### 5단계 — Fuseki 업로드

```bash
bash ontology/scripts/upload.sh ontology/projects/industry_safety/shapes/cq_[cq_n].shacl.ttl
```

- **Dataset**: `industry_safety`
- **Graph IRI**: `http://infiniq.co.kr/2026/industry_safety/cq_[cq_n].shacl`
- Fuseki가 실행 중이 아니면 경고만 출력하고 진행한다.

### 6단계 — 검토 요청

```
=== SHACL 설계 완료 — Human Review ===

파일: ontology/projects/industry_safety/shapes/cq_[cq_n].shacl.ttl
pyshacl: PASS
Fuseki: [UPLOADED | SKIPPED (서버 미실행)]
Graph: http://infiniq.co.kr/2026/industry_safety/cq_[cq_n].shacl

Shape 방식: [sh:SPARQLConstraint | sh:property]
검증 대상: is:[클래스]

테스트 결과:
  PASS 케이스: [설명] → Conformant ✓
  FAIL 케이스: [설명] → Violation ✓
  경계 케이스: [설명] → [결과] ✓

검토 항목:
□ SPARQL 조건이 CQ 준수 조건을 정확히 구현하는가?
□ 경계 케이스(임계값·적용 제외)가 올바른 결과를 내는가?
□ sh:message가 도메인 전문가가 이해할 수 있는 한국어인가?
□ PREFIX 선언이 sh:select 내부에 포함되어 있는가?

승인 후 /mapping-design [cq_file] [cq_n] 으로 다음 단계 진행.
```
