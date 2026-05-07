# KG Build Report — CQ_1

> 빌드 날짜: 2026-05-07
> 프로젝트: industry_safety
> CQ 파일: ontology/projects/industry_safety/resources/cq.md
> 리포트: ontology/projects/industry_safety/resources/reports/kg_cq_1.md

---

## 1. 개요

**CQ_1**: 상시근로자가 50인 이상인 사업장에 안전관리자가 1명 이상 선임되어 있는가?

**근거 조항**: 산업안전보건법 제17조제1항, 시행령 [별표3]

**준수 조건**: 상시근로자 50인 이상 사업장은 안전관리자를 1명 이상 선임해야 한다 (일반 제조업 기준; 업종별 기준은 시행령 별표3).

**경계 케이스**:
- 상시근로자 정확히 50인 → 적용 대상 (≥ 50), 안전관리자 미선임 시 FAIL
- 상시근로자 49인 이하 → 적용 제외, 무조건 PASS
- 상시근로자 ≥ 50 + 안전관리자 0명 → FAIL

---

## 2. 산출물 목록

| 단계 | 파일 | Named Graph | 트리플 수 | 버전 |
|---|---|---|---|---|
| TBox  | `ontology/projects/industry_safety/schema/cq_1.ttl`         | `http://infiniq.co.kr/2026/industry_safety/cq_1`        | 30  | 1.0.0 |
| SHACL | `ontology/projects/industry_safety/shapes/cq_1.shacl.ttl`  | `http://infiniq.co.kr/2026/industry_safety/cq_1.shacl`  | 10  | 1.0.0 |
| R2RML | `ontology/projects/industry_safety/abox/r2rml/cq_1.abox.rr.ttl` | —                                               | —   | 1.0.0 |
| ABox  | `ontology/projects/industry_safety/abox/cq_1.abox.nq`      | `http://infiniq.co.kr/2026/industry_safety/cq_1.abox`   | 348 | —     |

---

## 3. TBox 리뷰

### 설계 결정

- Workplace·Worker·PermanentWorker·SafetyManager 4개 클래스만 정의 — CQ가 요구하는 최소 구조
- PermanentWorker와 SafetyManager를 Worker의 하위 클래스로 모델링 — 동일인이 두 역할 겸임 가능 (OWL DL 허용)
- employsWorker를 상위 프로퍼티로, appointsManager를 하위 프로퍼티로 설계 — 선임 관계가 고용 관계의 특수 사례임을 명시
- workerCount DataProperty 제외 — SPARQL COUNT로 충분히 집계 가능하며 최소화 원칙 적용
- 업종(Industry) 클래스 제외 — 업종별 기준은 SHACL 레벨에서 처리

### 정의된 클래스

| 클래스 | rdfs:label | 정의 |
|---|---|---|
| `is:Workplace` | 사업장 | 산업안전보건법상 의무 이행 주체. 사업주가 사업을 행하는 장소. 제17조 안전관리자 선임 의무 적용 단위. |
| `is:Worker` | 근로자 | 임금을 목적으로 사업장에서 근로를 제공하는 자. 근로기준법 제2조제1항제1호. |
| `is:PermanentWorker` | 상시근로자 | 상시적으로 사용하는 근로자. 50인 이상이면 안전관리자 선임 의무 발생. 산업안전보건법 제17조, 시행령 별표3. |
| `is:SafetyManager` | 안전관리자 | 사업장 안전에 관한 기술적 사항을 관리하는 자. 제17조제1항에 따라 선임 의무. |

### 정의된 프로퍼티

| 프로퍼티 | 유형 | domain → range | 정의 |
|---|---|---|---|
| `is:employsWorker` | owl:ObjectProperty | Workplace → Worker | 사업장이 근로자를 고용하는 관계. |
| `is:appointsManager` | owl:ObjectProperty (sub of employsWorker) | Workplace → SafetyManager | 사업장이 안전관리자를 선임하는 관계. 제17조제1항. |

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| 최소 클래스·프로퍼티 | PASS | 4클래스 + 2프로퍼티 전부 CQ_1 안전관리자 선임 검증에 직접 사용. workerCount·Industry 클래스 제외 근거 명확. |
| 도메인 용어 일치 | PASS | 사업장·근로자·상시근로자·안전관리자 — 법령 용어와 정확히 대응. |
| 기존 TBox 충돌 없음 | PASS | 타 CQ 파일 없음, 충돌 없음. |
| ROBOT PASS | PASS | HermiT 추론 통과, 논리 모순 없음. |
| Fuseki 적재 | PASS | HTTP 200, 30 트리플 확인. |

**판단**: 모든 항목 PASS → 2단계(SHACL) 진행.

---

## 4. SHACL 리뷰

### 설계 결정

- sh:SPARQLConstraint 선택: COUNT 집계로 PermanentWorker 수와 SafetyManager 수를 동시 비교해야 하므로 sh:property minCount 부적합
- 적용 제외 조건(49인 이하)은 서브쿼리 FILTER ?pwCount >= 50으로 처리 — 해당 사업장이 $this 결과에 포함되지 않아 자동 PASS
- is:employsWorker + is:PermanentWorker type 패턴으로 상시근로자 카운팅, is:appointsManager로 안전관리자 카운팅
- OPTIONAL 사용으로 안전관리자·상시근로자가 없는 사업장도 GROUP BY $this 결과에 포함되어 smCount=0 조건 정확히 작동

### Shape 정보

- **검증 대상**: `is:Workplace`
- **Shape 방식**: sh:SPARQLConstraint
- **위반 메시지**: 산업안전보건법 제17조제1항 위반: 상시근로자 50인 이상 사업장({$this})에 안전관리자가 선임되어 있지 않습니다. (시행령 별표3)

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| SPARQL 조건이 CQ를 구현하는가 | PASS | OPTIONAL+COUNT로 PermanentWorker·SafetyManager 집계 → ?pwCount>=50 AND ?smCount=0 조건이 제17조 준수 조건과 정확히 대응. |
| 경계 케이스 결과 | PASS | C공장(49인, 관리자 없음) → Conformant ✓ (FILTER ?pwCount>=50 불충족으로 적용 제외). |
| sh:message 적절성 | PASS | 한국어, 법령 근거(제17조제1항·시행령 별표3) 포함, {$this}로 위반 사업장 URI 명시. |
| pyshacl PASS | PASS | PASS (WorkplaceB에서 Violation 1건 정상 감지, A·C Conformant). |
| Fuseki 적재 | PASS | HTTP 200, 10 트리플 확인. |

**판단**: 모든 항목 PASS → 3단계(R2RML) 진행.

**SHACL 검증 명령어:**
```bash
pyshacl \
  -s ontology/projects/industry_safety/shapes/cq_1.shacl.ttl \
  -d ontology/projects/industry_safety/abox/cq_1.abox.nq \
  --ont-graph ontology/projects/industry_safety/schema/cq_1.ttl
```

---

## 5. R2RML 매핑 리뷰

### 설계 결정

- role 컬럼이 정수 FK(role.id) — 기존 View(v_normal_worker: role=1, v_safety_manager_map: role=2)를 재사용해 클래스 분기 처리, 신규 View 불필요
- 관계 트리플(employsWorker, appointsManager)은 클래스 TriplesMap과 별도 TriplesMap으로 분리
- factory.name, person.name → rdfs:label (식별 레이블 필수 매핑)
- person.role → rdf:type 소비 (WHERE 필터로 처리, 별도 트리플 미생성)
- factory/1(A공장)에 appointsManager 1건, factory/2(B공장)는 0건 → CQ_1 FAIL 대상 확인

### 컬럼 분류

| 테이블.컬럼 | 프로퍼티 유형 | 매핑 대상 |
|---|---|---|
| factory.id | PK | IRI 생성 기반 (`#factory/{id}`) |
| factory.name | rdfs:label | `"...이름..."@ko` |
| person.id | PK | IRI 생성 기반 (`#person/{id}`) |
| person.name | rdfs:label | `"...이름..."@ko` |
| person.factory | Object Property | employsWorker / appointsManager IRI 연결 |
| person.role | rdf:type 소비 | WHERE 필터 (role=1→PermanentWorker, role=2→SafetyManager) |
| role.id / role.name | rdf:type 소비 | WHERE 필터 기준, 별도 트리플 미생성 |

### TriplesMap 목록

| TriplesMap | 소스 | 생성 트리플 패턴 |
|---|---|---|
| WorkplaceMap | factory 테이블 | `<#factory/{id}> a is:Workplace ; rdfs:label "..."@ko` |
| PermanentWorkerMap | v_normal_worker View | `<#person/{id}> a is:PermanentWorker ; rdfs:label "..."@ko` |
| EmploysWorkerMap | v_normal_worker View | `<#factory/{fid}> is:employsWorker <#person/{pid}>` |
| SafetyManagerMap | v_safety_manager_map View | `<#person/{id}> a is:SafetyManager ; rdfs:label "..."@ko` |
| AppointsManagerMap | v_safety_manager_map View | `<#factory/{fid}> is:appointsManager <#person/{pid}>` |

### 신규 View: 없음 (기존 v_normal_worker, v_safety_manager_map 재사용)

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| 컬럼 분류 완전성 | PASS | factory·person·role 테이블의 모든 컬럼 분류 완료. |
| 식별 레이블 매핑 | PASS | factory.name → rdfs:label, person.name → rdfs:label 매핑 확인. |
| TBox 프로퍼티 커버 | PASS | employsWorker, appointsManager 사용; Workplace, PermanentWorker, SafetyManager rdf:type 생성. TBox 패치 없음. |
| Named Graph IRI | PASS | `http://infiniq.co.kr/2026/industry_safety/cq_1.abox` 일치. |
| morph-kgc PASS | PASS | 348 트리플 생성, 오류 없음. |

**판단**: 모든 항목 PASS. TBox 패치 발생 없음 → 4단계(ABox) 진행.

**ABox 재생성 명령어:**
```bash
source ontology/projects/industry_safety/.env

cat > /tmp/cq_1_config.ini << EOF
[CONFIGURATION]
output_file: ontology/projects/industry_safety/abox/cq_1.abox.nq
output_format: N-QUADS

[DataSource1]
mappings: ontology/projects/industry_safety/abox/r2rml/cq_1.abox.rr.ttl
db_url: $DB_URL
EOF

conda run -n onto python3 -m morph_kgc /tmp/cq_1_config.ini
```

---

## 6. ABox 리뷰

### 생성 결과: 348 트리플

### SHACL 검증 결과

**Conforms**: False (예상 위반 노드 정상 감지)

| 노드 유형 | 노드 | 기대 결과 | 실제 결과 | 판단 |
|---|---|---|---|---|
| PASS 예상 | A공장 `#factory/1` (상시근로자 51명·안전관리자 1명) | Conformant | Conformant | ✓ |
| PASS 예상 | C공장 `#factory/3` (상시근로자 11명·50인 미만) | Conformant | Conformant | ✓ |
| FAIL 예상 | B공장 `#factory/2` (상시근로자 51명·안전관리자 0명) | Violation | Violation | ✓ |

**위반 노드**: `http://infiniq.co.kr/2026/industry_safety#factory/2`

### kg-builder 리뷰 결과

| 항목 | 결과 | 판단 이유 |
|---|---|---|
| 트리플 수 > 0 | PASS | 348 트리플 생성. |
| Fuseki 적재 | PASS | HTTP 200, Named Graph `cq_1.abox` 확인. |
| PASS 예상 노드 Conformant | PASS | A공장(관리자 선임) ✓, C공장(50인 미만 적용 제외) ✓. |
| FAIL 예상 노드 Violation | PASS | B공장(관리자 미선임) Violation ✓. 위반 메시지 한국어·근거 조항 포함. |

**판단**: 모든 항목 PASS. SHACL이 CQ_1 준수 여부를 정확히 감지.

---

## 7. 전체 파이프라인 재현

```bash
#!/bin/bash
# CQ_1 KG 재현 스크립트
# 빌드: 2026-05-07 | 근거: 산업안전보건법 제17조제1항
set -e
source ontology/projects/industry_safety/.env

echo "=== 1. TBox ROBOT 검증 ==="
bash ontology/scripts/reason.sh ontology/projects/industry_safety/schema/cq_1.ttl

echo "=== 2. TBox Fuseki 업로드 ==="
bash ontology/scripts/upload.sh ontology/projects/industry_safety/schema/cq_1.ttl

echo "=== 3. SHACL Fuseki 업로드 ==="
bash ontology/scripts/upload.sh ontology/projects/industry_safety/shapes/cq_1.shacl.ttl

echo "=== 4. ABox 생성 ==="
cat > /tmp/cq_1_config.ini << EOF
[CONFIGURATION]
output_file: ontology/projects/industry_safety/abox/cq_1.abox.nq
output_format: N-QUADS

[DataSource1]
mappings: ontology/projects/industry_safety/abox/r2rml/cq_1.abox.rr.ttl
db_url: $DB_URL
EOF
conda run -n onto python3 -m morph_kgc /tmp/cq_1_config.ini

echo "=== 5. ABox Fuseki 업로드 ==="
curl -s -u "admin:admin" -X DELETE \
  "http://localhost:3030/industry_safety/data?graph=http://infiniq.co.kr/2026/industry_safety/cq_1.abox"
bash ontology/scripts/upload.sh ontology/projects/industry_safety/abox/cq_1.abox.nq

echo "=== 6. SHACL 검증 ==="
pyshacl \
  -s ontology/projects/industry_safety/shapes/cq_1.shacl.ttl \
  -d ontology/projects/industry_safety/abox/cq_1.abox.nq \
  --ont-graph ontology/projects/industry_safety/schema/cq_1.ttl

echo "=== 완료 ==="
```

---

## 8. Fuseki SPARQL 활용 예제

```sparql
PREFIX is: <http://infiniq.co.kr/2026/industry_safety#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

-- 그래프 목록 확인
SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }

-- ABox 트리플 수
SELECT (COUNT(*) AS ?n)
FROM <http://infiniq.co.kr/2026/industry_safety/cq_1.abox>
WHERE { ?s ?p ?o }

-- 안전관리자 미선임 사업장 목록 (상시근로자 ≥ 50)
SELECT ?사업장 ?이름 (COUNT(DISTINCT ?pw) AS ?상시근로자수)
FROM <http://infiniq.co.kr/2026/industry_safety/cq_1.abox>
WHERE {
  ?사업장 a is:Workplace ;
          rdfs:label ?이름 ;
          is:employsWorker ?pw .
  ?pw a is:PermanentWorker .
  FILTER NOT EXISTS { ?사업장 is:appointsManager ?sm }
}
GROUP BY ?사업장 ?이름
HAVING (COUNT(DISTINCT ?pw) >= 50)
ORDER BY ?이름

-- 사업장별 상시근로자 수와 안전관리자 수
SELECT ?사업장 ?이름
  (COUNT(DISTINCT ?pw) AS ?상시근로자수)
  (COUNT(DISTINCT ?sm) AS ?안전관리자수)
FROM <http://infiniq.co.kr/2026/industry_safety/cq_1.abox>
WHERE {
  ?사업장 a is:Workplace ; rdfs:label ?이름 .
  OPTIONAL { ?사업장 is:employsWorker ?pw . ?pw a is:PermanentWorker }
  OPTIONAL { ?사업장 is:appointsManager ?sm }
}
GROUP BY ?사업장 ?이름
ORDER BY ?이름
```

---

## 9. 빌드 요약

| 항목 | 값 |
|---|---|
| 빌드 날짜 | 2026-05-07 |
| 총 소요 단계 | 4단계 |
| TBox 패치 발생 | 없음 |
| 전체 트리플 수 | TBox 30 + SHACL 10 + ABox 348 = 388 |
| SHACL 준수 | Conforms: False (위반 1개 사업장) |
| 위반 사업장 수 | 1개 (B공장 — 상시근로자 51명, 안전관리자 미선임) |
