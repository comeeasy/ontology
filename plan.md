# Ontology Project — Big Picture Plan

## 1. 전체 아키텍처

```
┌──────────────────────────────────────────────────────────┐
│                   Authoring Layer                        │
│   VSCode + Mentor Extension  →  .ttl / .owl / .shacl    │
└────────────────────────┬─────────────────────────────────┘
                         │ HTTP (SPARQL Update / Graph Store)
┌────────────────────────▼─────────────────────────────────┐
│              Apache Jena Fuseki (TDB2)                   │
│                                                          │
│  Named Graph: :schema   ← TBox (클래스, 프로퍼티)         │
│  Named Graph: :shapes   ← SHACL Shapes (규칙·제약)       │
│  Named Graph: :data     ← ABox (인스턴스)                │
│  Named Graph: :inferred ← Reasoner 출력 (선택적)         │
└──────────┬──────────────────────────┬────────────────────┘
           │ SPARQL 1.1               │ SPARQL 1.1
┌──────────▼──────────┐   ┌──────────▼──────────────────┐
│  Compliance         │   │  Simulator                  │
│  Validator          │   │                             │
│                     │   │  시나리오 정의 → 상태 전이   │
│  SHACL validation   │   │  SPARQL CONSTRUCT 반복 실행  │
│  SPARQL ASK/SELECT  │   │  (Forward Chaining 에뮬레이션)│
│  위반 리포트 출력    │   │  결과 그래프 분석            │
└─────────────────────┘   └─────────────────────────────┘
```

---

## 2. 온톨로지 스키마 구축

### 2.1 OWL 프로파일 선택

| 프로파일 | 추론 복잡도 | 표현력 | 권장 상황 |
|----------|------------|--------|-----------|
| OWL 2 EL | 다항 시간 | 중간 | 의료·생물 등 대규모 TBox |
| OWL 2 RL | 다항 시간 | 중간 | 규칙 기반 시스템, RDF 친화 |
| **OWL 2 DL** | **EXPTIME** | **높음** | **법률·규제 도메인 (권장)** |

법률/규칙 검증이 목표이므로 **OWL 2 DL** 을 기본으로 하되, 추론 부하가 크면 RL 서브셋으로 제한.

### 2.2 Named Graph 전략 (Fuseki)

```
:schema   — TBox만 적재. 클래스 계층, ObjectProperty, DataProperty, 공리(Axiom)
:shapes   — SHACL NodeShape / PropertyShape. 법률 조항별 제약 표현
:data     — 검증 대상 ABox (인스턴스). 배치·실시간 모두 지원
:inferred — OWL Reasoner(Jena OWL/HermiT) 결과 저장 (선택적 materialization)
```

> **핵심 설계 원칙**: TBox(:schema)와 ABox(:data)를 Named Graph로 분리하면,
> 인스턴스 데이터를 교체해도 스키마를 건드리지 않고 재검증 가능.

### 2.3 파일 구조 (권장)

```
ontology/
├── schema/
│   ├── core.ttl          # 핵심 클래스·프로퍼티 정의
│   ├── domain-*.ttl      # 도메인별 모듈 (법률 조항별 분리 권장)
│   └── imports.ttl       # owl:imports 집계 파일
├── shapes/
│   ├── rule-*.shacl.ttl  # 법률 조항 → SHACL Shape 1:1 매핑
│   └── common.shacl.ttl  # 공통 제약 (데이터 타입, 카디널리티)
├── rules/
│   └── inference.rules   # Jena Native Rule (SWRL 대안, 성능 우수)
├── data/
│   └── examples/         # 검증 예시 인스턴스
└── scripts/
    ├── load.sh           # Fuseki에 Named Graph별 적재
    └── validate.sh       # SHACL 검증 실행
```

### 2.4 Fuseki 적재 방법

```bash
# Named Graph 단위 업로드 (Graph Store Protocol)
curl -X PUT \
  -H "Content-Type: text/turtle" \
  --data-binary @schema/core.ttl \
  "http://localhost:3030/dataset/data?graph=http://example.org/schema"

# 또는 s-put 유틸리티 (Jena 번들 포함)
s-put http://localhost:3030/dataset http://example.org/schema schema/core.ttl
```

---

## 3. Application 1 — Compliance Validator

### 3.1 검증 계층 구조

```
Layer 1 (Syntactic)   : OWL/RDF 문법 검사 → Jena RDFDataMgr
Layer 2 (Schema)      : OWL Consistency 검사 → Jena OntModel + Reasoner
Layer 3 (Constraint)  : SHACL 제약 검사 → Apache Jena SHACL (TopQuadrant API)
Layer 4 (Semantic)    : 도메인 규칙 SPARQL → ASK / SELECT
```

### 3.2 법률 조항 → SHACL 매핑 패턴

```turtle
# 예시: "A는 반드시 B를 가져야 한다" 류 조항
ex:ArticleXShape
    a sh:NodeShape ;
    sh:targetClass ex:SubjectClass ;
    sh:property [
        sh:path ex:requiredProperty ;
        sh:minCount 1 ;
        sh:message "조항 X 위반: requiredProperty가 없습니다."@ko ;
    ] .
```

복잡한 조건(IF-THEN, 수치 범위, 날짜 제약)은 `sh:sparql` + SPARQL SELECT로 표현.

### 3.3 출력 포맷

SHACL Validation Report(RDF)를 JSON-LD로 직렬화하여 애플리케이션 소비.
조항별 위반 여부, 위반 노드 URI, 메시지를 구조화된 리포트로 반환.

---

## 4. Application 2 — Simulator

### 4.1 시뮬레이션 모델

온톨로지 기반 시뮬레이터는 **상태(State) = RDF 그래프** 로 표현.

```
초기 상태 그래프 (G₀)
      │
      │  SPARQL CONSTRUCT (전이 규칙 r₁)
      ▼
  G₁ = G₀ ∪ r₁(G₀)
      │
      │  SPARQL CONSTRUCT (전이 규칙 r₂)
      ▼
  G₂ = G₁ ∪ r₂(G₁)
      │
      ▼  ... (수렴 또는 스텝 한계)
  최종 상태 Gₙ → Compliance Validator 적용
```

### 4.2 전이 규칙 표현

SPARQL CONSTRUCT를 규칙으로 사용:

```sparql
# 규칙 예시: 조건 만족 시 새로운 상태 트리플 생성
CONSTRUCT {
    ?entity ex:status ex:Approved .
    ?entity ex:approvedAt ?now .
}
WHERE {
    ?entity a ex:Application ;
            ex:meetsConditionA true ;
            ex:meetsConditionB true .
    BIND(NOW() AS ?now)
}
```

### 4.3 Jena Native Rules (대안)

SPARQL CONSTRUCT 반복보다 성능이 필요한 경우 Jena Rule Engine 직접 사용:

```
[rule1: (?x ex:meetsConditionA true) (?x ex:meetsConditionB true)
        -> (?x ex:status ex:Approved)]
```

### 4.4 시뮬레이터 실행 흐름

1. 시나리오 파일 (Turtle) → `:data` 그래프에 적재
2. 전이 규칙 순차 실행 (SPARQL UPDATE 또는 Jena Rule)
3. 각 스텝 후 `:inferred` 그래프 스냅샷 저장
4. 최종 상태에 Compliance Validator 실행 → 규칙 만족 여부 판정
5. 스텝별 상태 변화 로그 출력

---

## 5. 기술 스택 결정

| 컴포넌트 | 선택 | 이유 |
|----------|------|------|
| 온톨로지 편집 | VSCode + Mentor | 요구사항 |
| 직렬화 형식 | Turtle (.ttl) | 가독성 최우선, 버전관리 친화 |
| Triple Store | Apache Jena Fuseki + TDB2 | 요구사항, SHACL 내장 지원 |
| OWL Reasoner | Jena OWL (기본) / HermiT (고강도) | 전자는 빠름, 후자는 완전한 OWL 2 DL |
| 제약 검증 | SHACL (W3C 표준) | SWRL보다 도구 지원 우수, 리포트 표준화 |
| 추론 규칙 | Jena Native Rules | SWRL보다 성능 우수, Fuseki 연동 용이 |
| 앱 레이어 | Python + rdflib + SPARQLWrapper | 빠른 프로토타이핑 |
| API (선택) | FastAPI | SHACL 리포트 JSON 직렬화 서빙 |

---

## 6. 단계별 로드맵 (데모 중심 재조정)

> **제약**: 온톨로지 경험 없음 + 데모 일정 촉박 → Simulator는 데모 이후, Compliance Validator에 집중

```
Phase 1 — 환경 구축 + 개념 학습 (학습 우선)
  ├── Apache Jena Fuseki 로컬 설치 및 데이터셋 생성
  ├── VSCode + Mentor Extension 설정
  ├── RDF/OWL/Turtle 기초 학습 (트리플, 클래스, 프로퍼티)
  └── 간단한 .ttl 직접 작성 → Fuseki 적재 → SPARQL SELECT 실행

Phase 2 — 산업안전 TBox 설계 (스키마)
  ├── 산업안전보건법 조항 분석: 구현할 조항 3~5개 선정
  ├── 핵심 클래스 도출: 설비, 작업자, 공정, 위험요소, 점검 등
  ├── OWL 클래스·프로퍼티 계층 설계 (Turtle로 직접 작성)
  └── Fuseki :schema Named Graph에 적재

Phase 3 — Compliance Validator (데모 MVP)
  ├── 선정 조항 → SHACL Shape 1:1 변환 (직접 작성)
  ├── 더미 ABox 작성: 위반 케이스 / 정상 케이스
  ├── Jena SHACL CLI로 검증 실행 → Validation Report 확인
  └── 리포트 → 화면 출력 방식 결정

Phase 4 — PostgreSQL → RDF 변환 파이프라인 (데모 준비)
  ├── 접근법 선택 (아래 §8 참조)
  ├── PostgreSQL 스키마 분석 → TBox 클래스·프로퍼티와 매핑 설계
  ├── 매핑 실행 → :data Named Graph에 적재
  └── End-to-end 데모 시나리오 실행

Phase 5 — Simulator (데모 이후)
  ├── 상태 전이 규칙 설계 (SPARQL CONSTRUCT)
  └── Validator와 연동
```

---

## 7. 미확정 사항

1. **조항 범위**: 산업안전보건법에서 구현할 구체적 조항 선정 필요 (복잡도 직결) — 확인 중
2. **RDB→RDF 접근법**: §8 참조, 방향 결정 필요
3. **디스플레이 방식**: 터미널 리포트 / 웹 대시보드 / 기타

---

## 8. 현재 진행 상태 (2026-05-04 기준)

### 완료

| 항목 | 상태 | 비고 |
|------|------|------|
| Phase 1 환경 구축 | ✅ | Fuseki, VSCode + Mentor, ODK Docker |
| TBox 설계 (R1~R5) | ✅ | `ontology/core.ttl`, `r1~r5.ttl` |
| TBox 논리 일관성 검증 | ✅ | `robot reason` (HermiT) 전 파일 통과 |
| R1 SHACL Shape 초안 | ✅ | `ontology/shapes/r1.shacl.ttl` — `sh:sparql` 방식 |
| R2RML 매핑 (R1) | ✅ | `ontology/abox/r1.abox.rr.ttl`, morph-kgc materialization |
| SPARQL CONSTRUCT 병합 (R1) | ✅ | `sparqls/r1_shacl_query.sparql` — 위반 리포트 + ABox 서브그래프 |

### 진행 중

- R2~R5 SHACL Shape 작성
- Compliance Validator 데모 앱 (Streamlit)

### 대기

- R2~R5 R2RML 매핑 및 ETL
- Simulator (데모 이후)
- Simulator (데모 이후)

### 온톨로지 모듈 구조

```
ontology/
├── core.ttl          # 공유 클래스 (사업장, 안전보건교육)
├── r1.ttl            # 제17조 — 안전관리자 선임
├── r2.ttl            # 제29조 — 안전보건교육
├── r3.ttl            # 제36조 — 위험성평가
├── r4.ttl            # 제93조 — 안전검사
├── r5.ttl            # 제125조 — 작업환경측정
└── r1.shacl.ttl      # R1 SHACL 제약 (sh:sparql 조건부)
```

---

## 9. PostgreSQL → RDF 변환 전략

공장 데이터 소스가 PostgreSQL RDB로 확정. 세 가지 접근법 중 하나를 선택해야 함.

### 옵션 A — Ontop (Virtual Knowledge Graph)
```
PostgreSQL ──SPARQL──▶ Ontop ──▶ 가상 RDF (물리적 변환 없음)
```
- PostgreSQL 스키마와 OWL TBox 간 매핑 파일(OBDA Mapping) 작성
- 데이터를 실제로 변환·적재하지 않음. SPARQL 쿼리를 SQL로 자동 번역
- 장점: 데모에서 "실시간 연동"처럼 보임, 데이터 이동 없음
- 단점: Fuseki 대신 Ontop 엔드포인트 사용, SHACL 검증 연동이 까다로움

### 옵션 B — R2RML (W3C 표준 매핑)
```
PostgreSQL ──R2RML 매핑──▶ RMLMapper ──▶ Turtle 파일 ──▶ Fuseki
```
- 매핑 규칙을 Turtle 형식으로 선언적으로 작성
- 장점: W3C 표준, Fuseki + SHACL 파이프라인과 자연스럽게 연동
- 단점: R2RML 문법 학습 필요, 데이터 변경 시 재실행 필요

### 옵션 C — Python 직접 ETL
```
PostgreSQL ──psycopg2──▶ Python(rdflib) ──▶ Turtle 파일 ──▶ Fuseki
```
- SQL 쿼리로 데이터 추출 → rdflib로 트리플 생성 → .ttl 직렬화
- 장점: 가장 직관적, 온톨로지 학습자에게 RDF 구조 이해에 도움
- 단점: 표준 방식 아님, 매핑 로직이 코드에 하드코딩됨

### 결정: 옵션 B (R2RML) — morph-kgc 사용 ✅ 완료

- 매핑 파일: `ontology/abox/r1.abox.rr.ttl` (TriplesMap 5개)
- DB VIEW (`v_normal_worker`, `v_safety_manager_map`) 로 역할 분기 처리
- morph-kgc로 materialization → `r1.abox.nq` (N-QUADS) 생성
- SPARQL CONSTRUCT (`r1_shacl_query.sparql`)로 ABox + 위반 리포트 병합 그래프 생성

Python ETL (`rdb/scripts/etl.py`)은 학습 비교용으로 보존 (`r1.abox_py.ttl`).

**Future Work — Delta 업데이트 도입**
- 현재 방식은 전체 TTL 재생성 + 재업로드 (full materialization)
- 데이터 규모가 커지면 변경분만 적용하는 delta 방식으로 전환 필요
- Stardog, Palantir 등 상용 시스템도 delta 기반 materialization 전략을 사용
- 구현 방향: 이전 스냅샷과 현재 스냅샷을 비교 → 추가/삭제 트리플만 SPARQL UPDATE로 반영

**Future Work — Compliance Validator Python 앱**
- pyshacl을 CLI가 아닌 Python API로 호출하여 결과를 구조화
- `conforms, results_graph, results_text = validate(data_graph, shacl_graph)` 형태로 사용
- `conforms` (bool) 기준으로 PASS/FAIL 판정, `results_text`에서 위반 사업장 URI 추출
- 규칙별 결과를 JSON으로 직렬화 → 웹 대시보드 또는 터미널 리포트 출력

