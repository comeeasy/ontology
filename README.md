# OntologyBuilder

도메인 문서(법령·규격·정책)를 읽고, 실제 RDB 데이터에 대한 OWL 2 DL 온톨로지와 SHACL 준수 검증 파이프라인을 자동으로 구축하는 멀티에이전트 시스템.

---

## 무엇을 하는가

도메인 전문가가 문서를 주면:

1. 문서에서 검증 가능한 의무 조항을 추출해 **Competency Question(CQ)**으로 정의한다.
2. 각 CQ에 대해 **OWL 2 DL TBox**(클래스·프로퍼티)를 설계하고 ROBOT으로 논리 일관성을 검증한다.
3. TBox를 기반으로 **SHACL Shape**을 작성하고 pyshacl로 테스트한다.
4. 기업의 실제 **RDB 스키마를 분석**하고 R2RML 매핑을 설계한다.
5. morph-kgc로 RDB → RDF **ABox를 생성**하고, SHACL로 준수 여부를 검증한다.
6. 모든 결과물을 **Apache Jena Fuseki** Named Graph에 적재한다.

각 단계는 Claude Code 스킬로 구현되어 있으며, Human Review를 거쳐 다음 단계로 진행한다.

---

## 현재 적용 도메인

| 프로젝트 | 문서 | CQ 수 | 상태 |
|---|---|---|---|
| `industry_safety` | 산업안전보건법 (한국 OSHA) | 7개 | CQ_1 완료 |
| `metttc` | — | — | 준비 중 |

---

## 파이프라인

```
[문서]
  │
  ▼
/doc-wiki      문서 전수 조사 → 도메인 wiki
  │ Human Review
  ▼
/cq-extract    wiki → Competency Questions (cq.md)
  │ Human Review
  ▼ (CQ별 독립 진행)
/tbox-design   CQ → OWL 2 DL TBox (.ttl)
               └─ ROBOT reason (HermiT) → Fuseki 업로드
  │ Human Review
  ▼
/shacl-design  TBox → SHACL Shape (.shacl.ttl)
               └─ pyshacl 검증 (PASS/FAIL/경계 케이스) → Fuseki 업로드
  │ Human Review
  ▼
/mapping-design  RDB 스키마 분석 → R2RML 매핑 (.rr.ttl)
               └─ DB 직접 조회 (schema_check.sql) → morph-kgc 문법 검증
  │ Human Review
  ▼
/abox-build    R2RML → ABox (.nq) → Fuseki 업로드 → SHACL 검증
  │ Human Review
  ▼
[Fuseki Named Graph: TBox + SHACL + ABox]
```

---

## 기술 스택

| 역할 | 도구 |
|---|---|
| 온톨로지 추론 검증 | ROBOT (HermiT, via ODK Docker) |
| SHACL 검증 | pyshacl |
| RDB → RDF 매핑 | R2RML + morph-kgc |
| Triple Store | Apache Jena Fuseki (TDB2) |
| RDB | PostgreSQL |
| 에이전트 | Claude Code (claude-sonnet-4-6) |

### TBox 어노테이션 규약

각 클래스·프로퍼티에 아래 어노테이션을 필수 부착한다.

| 어노테이션 | 대상 | 내용 |
|---|---|---|
| `rdfs:label` | 클래스·프로퍼티 | 한국어 도메인 용어 (도메인 용어와 정확히 일치) |
| `rdfs:comment` | 클래스·프로퍼티 | 법적·도메인 정의 + CQ 역할 + 근거 조항 |

파일 수준 메타데이터는 `owl:Ontology` 블록으로 관리한다.

| 프로퍼티 | 설명 |
|---|---|
| `owl:versionInfo` | `"1.0.0"` 시작, 구조 변경 시 마이너 버전 업 |
| `dcterms:created` | 파일 최초 생성일 (`xsd:date`), 이후 변경 금지 |
| `dcterms:source` | 근거 법령·규격의 URL |
| `rdfs:label` | 온톨로지 제목 (예: `"CQ_1 TBox — 안전관리자 선임"@ko`) |

---

## 디렉토리 구조

```
ontology/
├── projects/
│   └── [project]/
│       ├── .env                       # DB_URL, Fuseki 설정, Reasoner — gitignore
│       ├── schema/cq_[n].ttl          # TBox (CQ별)
│       ├── shapes/cq_[n].shacl.ttl    # SHACL Shape (CQ별)
│       ├── abox/
│       │   ├── r2rml/cq_[n].abox.rr.ttl  # R2RML 매핑 (CQ별)
│       │   ├── config.ini             # morph-kgc 설정 (자동 생성) — gitignore
│       │   └── cq_[n].abox.nq         # ABox N-Quads (자동 생성) — gitignore
│       └── resources/
│           ├── wiki/[문서명].md        # 도메인 wiki (doc-wiki 생성)
│           ├── [원문문서].md
│           └── cq.md                  # Competency Questions
└── scripts/
    ├── reason.sh       # ROBOT 검증 (프로젝트별 .env 참조)
    ├── upload.sh       # Fuseki 적재 (TTL→PUT+graph / NQ→POST)
    ├── gen_config.sh   # r2rml/*.rr.ttl 스캔 → config.ini 자동 생성
    └── create_kg.sh    # Fuseki Named Graph 합치기 → 단일 RDF 파일 저장

rdb/
├── docker-compose.yml
└── scripts/
    ├── init_db.sql           # 테스트 DB 초기화
    ├── schema_check.sql      # information_schema 조회 (스키마 파악용)
    ├── normal_worker_map.sql # 상시근로자 View
    └── safety_manager_map.sql
```

---

## Named Graph 구조

CQ 단위로 그래프를 분리한다. `upload.sh`가 파일명 기준으로 IRI를 자동 결정한다.

| 파일 | Named Graph | 업로드 |
|---|---|---|
| `schema/cq_[n].ttl` | `…/cq_[n]` | PUT (TTL) |
| `shapes/cq_[n].shacl.ttl` | `…/cq_[n].shacl` | PUT (TTL) |
| `abox/cq_[n].abox.nq` | `…/cq_[n].abox` (파일 내 포함) | POST (N-Quads) |

---

## 환경 설정

### 필수 소프트웨어

| 소프트웨어 | 용도 | 확인 |
|---|---|---|
| Docker Desktop | PostgreSQL, ROBOT 추론 | `docker --version` |
| Apache Jena Fuseki | Triple Store | `http://localhost:3030` |
| Python 3.x | SHACL 검증 | `python --version` |
| Conda `onto` 환경 | morph-kgc 전용 | `conda activate onto` |

```bash
# 기본 의존성
pip install pyshacl rdflib

# morph-kgc는 onto conda 환경에 별도 설치
conda create -n onto python=3.11 -y
conda run -n onto pip install morph-kgc sqlalchemy psycopg
```

### PostgreSQL

```bash
cd rdb && docker compose up -d
```

초기화: `docker compose down -v && docker compose up -d`

### Apache Jena Fuseki

```bash
docker run -d --name fuseki -p 3030:3030 \
  -e ADMIN_PASSWORD=admin \
  -e TDB=2 \
  -e FUSEKI_DATASET_1=industry_safety \
  -v fuseki-data:/fuseki \
  stain/jena-fuseki:5.1.0
```

`FUSEKI_DATASET_1` 없이 올린 경우: UI(`http://localhost:3030`) → **Manage Datasets** → `industry_safety` (Persistent / TDB2) 수동 생성.

### 프로젝트 .env

각 프로젝트 디렉토리에 `.env`를 작성한다. `reason.sh`, `upload.sh`, `gen_config.sh`가 공통으로 참조한다.

```ini
FUSEKI_DATASET=industry_safety
BASE_IRI=http://infiniq.co.kr/2026/industry_safety
REASONER=hermit
DB_URL=postgresql+psycopg://user:pass@localhost:5432/dbname
```

---

## 스크립트 레퍼런스

```bash
# TBox ROBOT 검증
bash ontology/scripts/reason.sh ontology/projects/industry_safety/schema/cq_1.ttl

# Fuseki 적재 (TTL)
bash ontology/scripts/upload.sh ontology/projects/industry_safety/schema/cq_1.ttl

# Fuseki 적재 (N-Quads, named graph 보존)
bash ontology/scripts/upload.sh ontology/projects/industry_safety/abox/cq_1.abox.nq

# morph-kgc config.ini 재생성
bash ontology/scripts/gen_config.sh industry_safety

# Fuseki Named Graph 합치기 → 단일 RDF 파일 저장
bash ontology/scripts/create_kg.sh \
  -d industry_safety \
  -o output/cq_1_merged.ttl \
  -g http://infiniq.co.kr/2026/industry_safety/cq_1 \
  -g http://infiniq.co.kr/2026/industry_safety/cq_1.shacl \
  -g http://infiniq.co.kr/2026/industry_safety/cq_1.abox

# 적재된 그래프 목록 확인 (SPARQL)
# SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }
```

---

## 진행 상태 — industry_safety (산업안전보건법)

| CQ | 조항 | 내용 | TBox | SHACL | R2RML | ABox |
|---|---|---|---|---|---|---|
| CQ_1 | 제17조 | 안전관리자 선임 (≥50인) | ✅ | ✅ | ✅ | ✅ |
| CQ_2 | 제18조 | 보건관리자 선임 (≥300인) | - | - | - | - |
| CQ_3 | 제29조 | 안전보건교육 이수 | - | - | - | - |
| CQ_4 | 제36조 | 위험성평가 (연 1회) | - | - | - | - |
| CQ_5 | 제93조 | 안전검사 주기 | - | - | - | - |
| CQ_6 | 제125조 | 작업환경측정 (6개월) | - | - | - | - |
| CQ_7 | 제129조 | 일반건강진단 | - | - | - | - |
