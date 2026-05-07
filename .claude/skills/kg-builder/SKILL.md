# /kg-builder

단일 CQ에 대해 전체 KG 구축 파이프라인을 서브에이전트로 오케스트레이션하고 최종 리포트를 작성한다.

파이프라인: `/tbox-design` → `/shacl-design` → `/mapping-design` → `/abox-build`

## 입력

`/kg-builder [cq_file] [cq_n]`

예: `/kg-builder ontology/projects/industry_safety/resources/cq.md 2`

---

## 설계 원칙

### 1. 먼저 생각하라 (Think Before Building)

가정하지 말 것. 혼란을 숨기지 말 것. 트레이드오프를 드러낼 것.

실행 전에:
- 변수를 모두 확인하고 누락된 것이 있으면 즉시 멈추고 사용자에게 알린다.
- PostgreSQL·Fuseki 상태를 확인한다. 미실행이면 중단한다.
- 기존 산출물 파일의 존재 여부와 관계없이 4단계를 모두 실행한다. 파일을 복구하거나 건너뛰지 않는다.
- 각 단계의 리뷰 기준을 미리 명시한다. "잘 됐다"가 아닌 구체적 체크리스트로 판단한다.

### 2. 단순함 우선 (Simplicity First)

이 CQ에 필요한 단계만 실행한다.

- **항상 전체 4단계를 재실행한다.** 기존 파일이 있어도 건너뛰지 않고 덮어쓴다.
- 서브에이전트 프롬프트는 해당 단계에 필요한 정보만 담는다.
- 리포트는 재현에 필요한 정보만 담는다. 불필요한 주석·설명을 붙이지 않는다.

### 3. 외과적 수정 (Surgical Changes)

이 CQ의 산출물만 생성·수정한다.

- 다른 CQ의 파일을 읽는 것은 가능하지만 수정하지 않는다.
- TBox 패치 시 기존 클래스·프로퍼티를 변경하지 않고 누락 항목만 추가한다.
- Fuseki에서 이 CQ의 그래프만 갱신한다.

### 4. 목표 기반 실행 (Goal-Driven Execution)

성공 기준을 정의하고, 검증될 때까지 반복한다.

이 스킬의 성공 기준:
1. 4개 서브에이전트 모두 완료 → 산출물 파일 4개 존재
2. ROBOT reason PASS
3. pyshacl: 예상 PASS 노드 Conformant, 예상 FAIL 노드 Violation
4. Fuseki: TBox·SHACL·ABox 그래프 모두 적재
5. 리포트 파일 생성

리뷰 실패(FAIL) 시:
- **자동 복구 가능**(TBox 누락 프로퍼티, morph-kgc 경고 등): 해당 서브에이전트를 재생성해 수정 후 재개.
- **자동 복구 불가**(ROBOT FAIL, morph-kgc FAIL, SHACL 예상 외 결과): 멈추고 사용자에게 상세 내용 보고.
- 모든 리뷰 결과(PASS·FAIL·이유·조치)를 리포트에 기록한다.

---

## 변수 도출

실행 전 아래 변수를 모두 확정한다. 누락 시 중단하고 사용자에게 알린다.

```
입력에서:
  CQ_FILE   = [cq_file]  (예: ontology/projects/industry_safety/resources/cq.md)
  CQ_N      = [cq_n]     (예: 2)

CQ_FILE 경로에서:
  PROJECT   = CQ_FILE의 두 번째 경로 세그먼트  (예: industry_safety)

경로 조합:
  PROJECT_DIR  = ontology/projects/${PROJECT}
  ENV_FILE     = ${PROJECT_DIR}/.env
  SCHEMA_DIR   = ${PROJECT_DIR}/schema
  SHAPES_DIR   = ${PROJECT_DIR}/shapes
  ABOX_DIR     = ${PROJECT_DIR}/abox
  R2RML_DIR    = ${PROJECT_DIR}/abox/r2rml
  REPORTS_DIR  = ${PROJECT_DIR}/resources/reports

.env에서 (source ${ENV_FILE}):
  BASE_IRI          (예: http://infiniq.co.kr/2026/industry_safety)
  FUSEKI_DATASET    (예: industry_safety)
  DB_URL
  FUSEKI_ENDPOINT   (기본값: http://localhost:3030)
  FUSEKI_ID         (기본값: admin)
  FUSEKI_PASSWORD   (기본값: admin)

산출물 경로:
  TBOX_FILE   = ${SCHEMA_DIR}/cq_${CQ_N}.ttl
  TBOX_GRAPH  = ${BASE_IRI}/cq_${CQ_N}
  SHACL_FILE  = ${SHAPES_DIR}/cq_${CQ_N}.shacl.ttl
  SHACL_GRAPH = ${BASE_IRI}/cq_${CQ_N}.shacl
  R2RML_FILE  = ${R2RML_DIR}/cq_${CQ_N}.abox.rr.ttl
  ABOX_FILE   = ${ABOX_DIR}/cq_${CQ_N}.abox.nq
  ABOX_GRAPH  = ${BASE_IRI}/cq_${CQ_N}.abox
  REPORT_FILE = ${REPORTS_DIR}/kg_cq_${CQ_N}.md
```

---

## 실행 절차

### 0단계 — 사전 조건 확인

```bash
docker ps --filter "name=rdb" --format "{{.Status}}"
curl -s -o /dev/null -w "%{http_code}" ${FUSEKI_ENDPOINT:-http://localhost:3030}
```

- PostgreSQL 미실행 → 즉시 중단.
- Fuseki 미실행 → 즉시 중단.
- `${CQ_FILE}`에 `CQ_${CQ_N}` 섹션이 없으면 → 즉시 중단.
- `${ENV_FILE}` 없으면 → 즉시 중단.

---

### 1단계 — TBox 설계 (서브에이전트)

**서브에이전트 프롬프트 (변수 치환 후 전달):**

```
`.claude/skills/tbox-design/SKILL.md`를 읽고 아래 인자로 모든 단계를 실행하라.

CQ_FILE: ${CQ_FILE}
CQ_N: ${CQ_N}
PROJECT: ${PROJECT}
TBOX_FILE: ${TBOX_FILE}
TBOX_GRAPH: ${TBOX_GRAPH}
ENV_FILE: ${ENV_FILE}

1단계(컨텍스트 읽기) → 2단계(설계 결정) → 3단계(파일 작성) → 4단계(ROBOT 검증) → 5단계(Fuseki 업로드)
를 순서대로 완료하라.

완료 후 아래 포맷으로만 요약을 반환하라. 다른 텍스트는 추가하지 않는다.

TBOX_FILE: ${TBOX_FILE}
TBOX_GRAPH: ${TBOX_GRAPH}
TBOX_TRIPLES: [숫자]
TBOX_ROBOT: [PASS | FAIL | FAIL:이유]
TBOX_FUSEKI: [UPLOADED | SKIPPED:이유]
TBOX_CLASSES: [클래스명 목록, 쉼표 구분]
TBOX_OBJECT_PROPS: [목록, 쉼표 구분 | 없음]
TBOX_DATA_PROPS: [목록, 쉼표 구분 | 없음]
TBOX_VERSION: [owl:versionInfo 값]
TBOX_DESIGN_DECISIONS: [2단계 설계 결정 요약, 세미콜론 구분]
```

**kg-builder가 직접 수행하는 리뷰 (결과를 리포트에 기록):**

| 항목 | 판단 기준 |
|---|---|
| 최소 클래스·프로퍼티 | CQ에 쓰이지 않는 항목이 없는가 |
| 도메인 용어 일치 | 법령 용어와 명칭이 일치하는가 |
| 기존 TBox 충돌 없음 | 타 CQ 파일과 클래스·프로퍼티 중복이 없는가 |
| ROBOT PASS | TBOX_ROBOT = PASS인가 |
| Fuseki 적재 | TBOX_FUSEKI = UPLOADED인가 |

- 모든 항목 PASS → 2단계로 진행.
- ROBOT FAIL → **중단**, 사용자에게 보고.
- Fuseki SKIPPED → 경고 기록 후 진행.

---

### 2단계 — SHACL 설계 (서브에이전트)

**서브에이전트 프롬프트:**

```
`.claude/skills/shacl-design/SKILL.md`를 읽고 아래 인자로 모든 단계를 실행하라.

CQ_FILE: ${CQ_FILE}
CQ_N: ${CQ_N}
PROJECT: ${PROJECT}
TBOX_FILE: ${TBOX_FILE}
SHACL_FILE: ${SHACL_FILE}
SHACL_GRAPH: ${SHACL_GRAPH}
ENV_FILE: ${ENV_FILE}

1단계(컨텍스트 읽기) → 2단계(설계 결정) → 3단계(파일 작성) → 4단계(pyshacl 검증) → 5단계(Fuseki 업로드)
를 완료하라.

완료 후 아래 포맷으로만 요약을 반환하라.

SHACL_FILE: ${SHACL_FILE}
SHACL_GRAPH: ${SHACL_GRAPH}
SHACL_TRIPLES: [숫자]
SHACL_PYSHACL: [PASS | FAIL:이유]
SHACL_FUSEKI: [UPLOADED | SKIPPED:이유]
SHACL_TARGET_CLASS: [sh:targetClass 값]
SHACL_SHAPE_TYPE: [sh:SPARQLConstraint | sh:property]
SHACL_MESSAGE: [sh:message 값]
SHACL_PASS_CASES: [PASS 케이스 설명]
SHACL_FAIL_CASES: [FAIL 케이스 설명]
SHACL_BOUNDARY: [경계 케이스 설명 및 결과]
SHACL_VERSION: [owl:versionInfo 값]
SHACL_DESIGN_DECISIONS: [2단계 설계 결정 요약]
```

**kg-builder 리뷰:**

| 항목 | 판단 기준 |
|---|---|
| SPARQL 조건이 CQ 준수 조건을 구현하는가 | 설계 결정과 sh:select가 일치하는가 |
| 경계 케이스 올바른 결과 | SHACL_BOUNDARY에 예상값이 충족되는가 |
| sh:message 한국어·근거 조항 포함 | SHACL_MESSAGE 확인 |
| pyshacl PASS | SHACL_PYSHACL = PASS인가 |
| Fuseki 적재 | SHACL_FUSEKI = UPLOADED인가 |

- 모든 항목 PASS → 3단계로 진행.
- pyshacl FAIL → **중단**, 사용자에게 보고.

---

### 3단계 — R2RML 매핑 설계 (서브에이전트)

**서브에이전트 프롬프트:**

```
`.claude/skills/mapping-design/SKILL.md`를 읽고 아래 인자로 모든 단계를 실행하라.

CQ_FILE: ${CQ_FILE}
CQ_N: ${CQ_N}
PROJECT: ${PROJECT}
TBOX_FILE: ${TBOX_FILE}
R2RML_FILE: ${R2RML_FILE}
ABOX_GRAPH: ${ABOX_GRAPH}
ENV_FILE: ${ENV_FILE}

1단계(컨텍스트 읽기) → 2단계(컬럼 분류 + TBox 대조 + 설계 결정) → 3단계(View 작성, 필요 시)
→ 4단계(R2RML 파일 작성) → 5단계(config.ini 재생성) → 6단계(morph-kgc 검증)
를 완료하라.

TBox 누락 항목이 발견되면 즉시 중단하고 아래 포맷으로 보고하라:
TBOX_PATCH_NEEDED: [프로퍼티명 | 유형(ObjectProperty/DatatypeProperty) | domain → range]

누락이 없으면 완료 후 아래 포맷으로 요약을 반환하라.

R2RML_FILE: ${R2RML_FILE}
ABOX_GRAPH: ${ABOX_GRAPH}
R2RML_MORPHKGC: [PASS:N트리플 | FAIL:이유]
R2RML_TRIPLESMAPS: [TriplesMap 이름 목록, 쉼표 구분]
R2RML_NEW_VIEWS: [신규 View SQL 파일 목록 | 없음]
R2RML_COLUMN_MAP: [테이블.컬럼→유형 목록, 세미콜론 구분]
R2RML_VERSION: [owl:versionInfo 값]
R2RML_DESIGN_DECISIONS: [설계 결정 요약]
```

**TBox 패치 폴백 (자동 처리):**

서브에이전트가 `TBOX_PATCH_NEEDED`를 반환하면:
1. 누락 내용을 리포트에 기록한다.
2. tbox-design 서브에이전트를 **패치 모드**로 재생성한다.
   - 프롬프트에 "기존 `${TBOX_FILE}`을 읽고 아래 프로퍼티만 추가하라. versionInfo를 마이너 버전 업한다." 를 포함.
3. TBox 패치 완료 후 mapping-design 서브에이전트를 재생성해 재개한다.
4. 리포트의 TBox 리뷰 섹션에 "패치 발생" 항목으로 기록한다.

**kg-builder 리뷰:**

| 항목 | 판단 기준 |
|---|---|
| 컬럼 분류 완전성 | 매핑 대상 테이블의 모든 컬럼이 분류되었는가 |
| 식별 레이블 매핑 | name류 컬럼이 rdfs:label로 매핑되었는가 |
| TBox 프로퍼티 커버 | 생성 트리플이 TBox 프로퍼티를 사용하는가 |
| Named Graph IRI | ABOX_GRAPH가 규칙에 맞는가 |
| morph-kgc PASS | R2RML_MORPHKGC가 PASS인가 |

- 모든 항목 PASS → 4단계로 진행.
- morph-kgc FAIL → **중단**, 사용자에게 보고.

---

### 4단계 — ABox 빌드 (서브에이전트)

**서브에이전트 프롬프트:**

```
`.claude/skills/abox-build/SKILL.md`를 읽고 아래 인자로 모든 단계를 실행하라.

CQ_FILE: ${CQ_FILE}
CQ_N: ${CQ_N}
PROJECT: ${PROJECT}
TBOX_FILE: ${TBOX_FILE}
SHACL_FILE: ${SHACL_FILE}
R2RML_FILE: ${R2RML_FILE}
ABOX_FILE: ${ABOX_FILE}
ABOX_GRAPH: ${ABOX_GRAPH}
ENV_FILE: ${ENV_FILE}
FUSEKI_ENDPOINT: ${FUSEKI_ENDPOINT}
FUSEKI_DATASET: ${FUSEKI_DATASET}
FUSEKI_ID: ${FUSEKI_ID}
FUSEKI_PASSWORD: ${FUSEKI_PASSWORD}

1단계(사전 조건) → 2단계(컨텍스트) → 3단계(morph-kgc 실행) → 4단계(Fuseki 업로드) → 5단계(SHACL 검증)
를 완료하라.

완료 후 아래 포맷으로만 요약을 반환하라.

ABOX_FILE: ${ABOX_FILE}
ABOX_GRAPH: ${ABOX_GRAPH}
ABOX_TRIPLES: [숫자]
ABOX_FUSEKI: [UPLOADED | FAIL:이유]
ABOX_SHACL_CONFORMS: [True | False]
ABOX_VIOLATIONS: [위반 노드 URI 목록 (줄바꿈 구분) | 없음]
ABOX_PASS_NODES: [PASS 예상 노드명 → Conformant ✓ / Violation ✗]
ABOX_FAIL_NODES: [FAIL 예상 노드명 → Violation ✓ / Conformant ✗]
```

**kg-builder 리뷰:**

| 항목 | 판단 기준 |
|---|---|
| 트리플 수 > 0 | ABOX_TRIPLES > 0 |
| Fuseki 적재 | ABOX_FUSEKI = UPLOADED |
| PASS 예상 노드 Conformant | ABOX_PASS_NODES의 결과가 모두 ✓ |
| FAIL 예상 노드 Violation | ABOX_FAIL_NODES의 결과가 모두 ✓ |

- 모든 항목 PASS → 5단계(리포트 작성)로 진행.
- ABOX_FUSEKI FAIL → **중단**, 사용자에게 보고.
- PASS/FAIL 예상 불일치 → 원인 분석 후 리포트에 기록. 2회 분석 후에도 원인 불명이면 **중단**, 사용자에게 보고.

---

### 5단계 — 최종 리포트 작성

`${REPORTS_DIR}` 디렉토리를 생성하고 `${REPORT_FILE}`을 작성한다.

1~4단계의 서브에이전트 요약과 kg-builder의 각 리뷰 결과를 아래 템플릿으로 통합한다.

---

## 최종 리포트 템플릿

````markdown
# KG Build Report — CQ_${CQ_N}

> 빌드 날짜: [YYYY-MM-DD]
> 프로젝트: ${PROJECT}
> CQ 파일: ${CQ_FILE}
> 리포트: ${REPORT_FILE}

---

## 1. 개요

**CQ_${CQ_N}**: [CQ 질문 전문]

**근거 조항**: [법령 조항]

**준수 조건**: [구체적 조건]

**경계 케이스**: [임계값·예외 조건]

---

## 2. 산출물 목록

| 단계 | 파일 | Named Graph | 트리플 수 | 버전 |
|---|---|---|---|---|
| TBox  | `${TBOX_FILE}`  | `${TBOX_GRAPH}`  | [N] | [v] |
| SHACL | `${SHACL_FILE}` | `${SHACL_GRAPH}` | [N] | [v] |
| R2RML | `${R2RML_FILE}` | —                | —   | [v] |
| ABox  | `${ABOX_FILE}`  | `${ABOX_GRAPH}`  | [N] | —   |

---

## 3. TBox 리뷰

### 설계 결정

[서브에이전트의 TBOX_DESIGN_DECISIONS 전문]

### 정의된 클래스

[클래스명 | rdfs:comment 요약 — TBOX_CLASSES 기반]

### 정의된 프로퍼티

[프로퍼티명 | 유형 | domain → range — TBOX_OBJECT_PROPS + TBOX_DATA_PROPS 기반]

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| 최소 클래스·프로퍼티 | PASS/FAIL | [이유: 어떤 항목이 있고 왜 적절한가/부적절한가] |
| 도메인 용어 일치 | PASS/FAIL | [이유] |
| 기존 TBox 충돌 없음 | PASS/FAIL | [이유] |
| ROBOT PASS | PASS/FAIL | [ROBOT 출력 요약] |
| Fuseki 적재 | PASS/FAIL | [응답 코드·트리플 수] |

**판단 및 조치**: [모두 PASS → 2단계 진행 | 항목 FAIL → 어떤 조치를 했는가]

[TBox 패치가 발생했다면:]
### TBox 패치 이력
| 패치 시점 | 추가된 프로퍼티 | 사유 | 버전 변경 |
|---|---|---|---|
| 3단계 mapping-design 중 | [프로퍼티명] | [mapping-design에서 발견된 누락] | [1.0.0 → 1.1.0] |

---

## 4. SHACL 리뷰

### 설계 결정

[서브에이전트의 SHACL_DESIGN_DECISIONS 전문]

### Shape 정보

- **검증 대상**: `${SHACL_TARGET_CLASS}`
- **Shape 방식**: [SHACL_SHAPE_TYPE]
- **위반 메시지**: [SHACL_MESSAGE]

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| SPARQL 조건이 CQ를 구현하는가 | PASS/FAIL | [sh:select의 핵심 조건이 CQ 준수 조건과 어떻게 대응되는가] |
| 경계 케이스 결과 | PASS/FAIL | [SHACL_BOUNDARY의 기대값 대비 실제 결과] |
| sh:message 적절성 | PASS/FAIL | [한국어 여부, 근거 조항 포함 여부] |
| pyshacl PASS | PASS/FAIL | [pyshacl 출력 요약] |
| Fuseki 적재 | PASS/FAIL | [응답 코드·트리플 수] |

**판단 및 조치**: [...]

**SHACL 실행:**
```bash
pyshacl \
  -s ${SHACL_FILE} \
  -d ${ABOX_FILE} \
  --ont-graph ${TBOX_FILE}
```

---

## 5. R2RML 매핑 리뷰

### 설계 결정

[서브에이전트의 R2RML_DESIGN_DECISIONS 전문]

### 컬럼 분류

| 테이블.컬럼 | 프로퍼티 유형 | 매핑 대상 |
|---|---|---|
[R2RML_COLUMN_MAP 파싱 결과]

### TriplesMap 목록

| TriplesMap | 소스 | 생성 트리플 패턴 |
|---|---|---|
[R2RML_TRIPLESMAPS 기반]

### 신규 View: [R2RML_NEW_VIEWS]

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| 컬럼 분류 완전성 | PASS/FAIL | [분류된 컬럼 수 vs. 실제 테이블 컬럼 수] |
| 식별 레이블 매핑 | PASS/FAIL | [name류 컬럼이 rdfs:label로 매핑되었는가] |
| TBox 프로퍼티 커버 | PASS/FAIL | [생성 트리플이 TBox에 정의된 프로퍼티를 사용하는가] |
| Named Graph IRI | PASS/FAIL | [${ABOX_GRAPH}와 일치하는가] |
| morph-kgc PASS | PASS/FAIL | [트리플 수, 오류 여부] |

**판단 및 조치**: [...]

**ABox 재생성:**
```bash
source ${ENV_FILE}

cat > /tmp/cq_${CQ_N}_config.ini << EOF
[CONFIGURATION]
output_file: ${ABOX_FILE}
output_format: N-QUADS

[DataSource1]
mappings: ${R2RML_FILE}
db_url: $DB_URL
EOF

conda run -n onto python3 -m morph_kgc /tmp/cq_${CQ_N}_config.ini
```

---

## 6. ABox 리뷰

### 생성 결과: [ABOX_TRIPLES] 트리플

### SHACL 검증 결과

**Conforms**: [ABOX_SHACL_CONFORMS]

| 노드 유형 | 노드 | 기대 결과 | 실제 결과 | 판단 |
|---|---|---|---|---|
| PASS 예상 | [ABOX_PASS_NODES] | Conformant | [실제] | ✓/✗ |
| FAIL 예상 | [ABOX_FAIL_NODES] | Violation  | [실제] | ✓/✗ |

**위반 노드**: [ABOX_VIOLATIONS]

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| 트리플 수 > 0 | PASS/FAIL | [ABOX_TRIPLES값. 0이면 morph-kgc 출력 확인 필요] |
| Fuseki 적재 | PASS/FAIL | [HTTP 응답 코드] |
| PASS 예상 노드 Conformant | PASS/FAIL | [각 노드별 결과 및 이유] |
| FAIL 예상 노드 Violation | PASS/FAIL | [각 노드별 결과 및 이유] |

**판단 및 조치**: [...]

---

## 7. 전체 파이프라인 재현

```bash
#!/bin/bash
# CQ_${CQ_N} KG 재현 스크립트
# 빌드: [날짜] | 근거: [조항]
set -e
source ${ENV_FILE}

echo "=== 1. TBox ROBOT 검증 ==="
bash ontology/scripts/reason.sh ${TBOX_FILE}

echo "=== 2. TBox Fuseki 업로드 ==="
bash ontology/scripts/upload.sh ${TBOX_FILE}

echo "=== 3. SHACL Fuseki 업로드 ==="
bash ontology/scripts/upload.sh ${SHACL_FILE}

echo "=== 4. ABox 생성 ==="
cat > /tmp/cq_${CQ_N}_config.ini << EOF
[CONFIGURATION]
output_file: ${ABOX_FILE}
output_format: N-QUADS

[DataSource1]
mappings: ${R2RML_FILE}
db_url: $DB_URL
EOF
conda run -n onto python3 -m morph_kgc /tmp/cq_${CQ_N}_config.ini

echo "=== 5. ABox Fuseki 업로드 ==="
curl -s -u "${FUSEKI_ID}:${FUSEKI_PASSWORD}" -X DELETE \
  "${FUSEKI_ENDPOINT}/${FUSEKI_DATASET}/data?graph=${ABOX_GRAPH}"
bash ontology/scripts/upload.sh ${ABOX_FILE}

echo "=== 6. SHACL 검증 ==="
pyshacl \
  -s ${SHACL_FILE} \
  -d ${ABOX_FILE} \
  --ont-graph ${TBOX_FILE}

echo "=== 완료 ==="
```

---

## 8. Fuseki SPARQL 활용 예제

```sparql
PREFIX is: <${BASE_IRI}#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

-- 그래프 목록 확인
SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }

-- ABox 트리플 수
SELECT (COUNT(*) AS ?n)
FROM <${ABOX_GRAPH}>
WHERE { ?s ?p ?o }

-- [CQ에 맞는 도메인 쿼리: 서브에이전트 설계 결정에서 도출]
SELECT ?개체 ?이름
FROM <${ABOX_GRAPH}>
WHERE {
  ?개체 a is:[주요클래스] ;
        rdfs:label ?이름 .
}
ORDER BY ?이름
```

---

## 9. 빌드 요약

| 항목 | 값 |
|---|---|
| 빌드 날짜 | [날짜] |
| 총 소요 단계 | 4단계 |
| TBox 패치 발생 | [없음 / N회] |
| 전체 트리플 수 | TBox [N] + SHACL [N] + ABox [N] = [합계] |
| SHACL 준수 | [Conforms: True/False] |
| 위반 사업장 수 | [N개 / 없음] |
````
