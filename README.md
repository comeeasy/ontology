# OntologyBuilder

도메인 문서(법령·규격·정책)를 읽고, 실제 RDB 데이터에 대한 **OWL 2 DL 온톨로지**와 **SHACL 준수 검증 파이프라인**을 자동으로 구축하는 멀티에이전트 시스템.

Claude Code 스킬을 통해 단계별로 진행하며, 각 단계는 Human Review를 거쳐 다음으로 이어진다.

---

## 목차

1. [무엇을 하는가](#1-무엇을-하는가)
2. [필수 소프트웨어](#2-필수-소프트웨어)
3. [처음 시작하기 — 5분 퀵스타트](#3-처음-시작하기--5분-퀵스타트)
4. [전체 파이프라인](#4-전체-파이프라인)
5. [스킬 레퍼런스](#5-스킬-레퍼런스)
6. [스크립트 레퍼런스](#6-스크립트-레퍼런스)
7. [새 프로젝트 설정](#7-새-프로젝트-설정)
8. [디렉토리 구조](#8-디렉토리-구조)
9. [Named Graph 구조](#9-named-graph-구조)
10. [TBox 어노테이션 규약](#10-tbox-어노테이션-규약)
11. [Fuseki SPARQL 활용](#11-fuseki-sparql-활용)
12. [트러블슈팅](#12-트러블슈팅)

---

## 1. 무엇을 하는가

### 한 줄 설명

"법령 문서를 주면, RDB에 실제 위반 사업장이 어딘지를 자동으로 찾아준다."

### 예시: 산업안전보건법 CQ_1

**입력** — 법령 조항:
> 제17조제1항: 상시근로자 50인 이상을 사용하는 사업주는 안전관리자를 선임해야 한다.

**출력** — SHACL 검증 결과:
```
Conforms: False
Focus Nodes:
  http://infiniq.co.kr/2026/industry_safety#factory/2
  → "산업안전보건법 제17조제1항 위반: 상시근로자 50인 이상 사업장(B공장)에 안전관리자가 선임되어 있지 않습니다."
```

### 시스템이 하는 일

도메인 전문가가 문서를 주면:

1. 문서에서 검증 가능한 의무 조항을 추출해 **Competency Question(CQ)** 으로 정의한다.
2. 각 CQ에 대해 **OWL 2 DL TBox**(클래스·프로퍼티)를 설계하고 ROBOT(HermiT)으로 논리 일관성을 검증한다.
3. TBox를 기반으로 **SHACL Shape**을 작성하고 pyshacl로 테스트한다.
4. 기업의 실제 **RDB 스키마를 분석**하고 R2RML 매핑을 설계한다.
5. morph-kgc로 RDB → RDF **ABox를 생성**하고, SHACL로 준수 여부를 검증한다.
6. 모든 결과물을 **Apache Jena Fuseki** Named Graph에 적재한다.

각 단계는 Claude Code 스킬(`/tbox-design`, `/shacl-design` 등)로 구현되어 있으며,  
전체 파이프라인은 `/kg-builder` 한 번으로 자동 실행된다.

---

## 2. 필수 소프트웨어

| 소프트웨어 | 버전 | 용도 | 확인 명령어 |
|---|---|---|---|
| Docker Desktop | 최신 | PostgreSQL, ROBOT(ODK) 추론 | `docker --version` |
| Apache Jena Fuseki | 5.1.0 (stain/jena-fuseki) | Triple Store | `curl http://localhost:3030` |
| Python 3.10+ | — | pyshacl, rdflib | `python3 --version` |
| Conda | — | morph-kgc 전용 환경 | `conda --version` |
| Claude Code | 최신 | 스킬 실행 | `claude --version` |

### Python 패키지 설치

```bash
# 기본 환경 (pyshacl, rdflib)
pip install pyshacl rdflib

# morph-kgc는 onto conda 환경에 별도 설치
conda create -n onto python=3.11 -y
conda run -n onto pip install morph-kgc sqlalchemy psycopg
```

---

## 3. 처음 시작하기 — 5분 퀵스타트

CQ_1(안전관리자 선임)을 처음 실행해보는 과정이다.

### 3.1 저장소 클론 및 이동

```bash
git clone <repo-url>
cd ontology
```

### 3.2 PostgreSQL 실행

```bash
cd rdb && docker compose up -d && cd ..
```

테스트 데이터가 자동으로 삽입된다:
- **A공장**: 상시근로자 51명 + 안전관리자 1명 → 준수 (PASS)
- **B공장**: 상시근로자 51명 + 안전관리자 0명 → **위반 (FAIL)**
- **C공장**: 상시근로자 11명 → 적용 제외 (PASS)

### 3.3 Fuseki 실행

```bash
docker run -d --name fuseki -p 3030:3030 \
  -e ADMIN_PASSWORD=admin \
  -e TDB=2 \
  -e FUSEKI_DATASET_1=industry_safety \
  -v fuseki-data:/fuseki \
  stain/jena-fuseki:5.1.0
```

> **확인**: 브라우저에서 `http://localhost:3030` 열고 `industry_safety` 데이터셋이 보이면 정상.

### 3.4 .env 파일 생성

```bash
cat > ontology/projects/industry_safety/.env << 'EOF'
FUSEKI_DATASET=industry_safety
BASE_IRI=http://infiniq.co.kr/2026/industry_safety
REASONER=hermit
DB_URL=postgresql+psycopg://joono:joono@localhost:5432/industry_safety
EOF
```

> DB 접속 정보는 `rdb/docker-compose.yml`의 `POSTGRES_USER`·`POSTGRES_PASSWORD`와 일치해야 한다.

### 3.5 kg-builder 실행

Claude Code에서:

```
/kg-builder ontology/projects/industry_safety/resources/cq.md 1
```

자동으로 4단계를 실행하고 최종 리포트를 생성한다:
- `ontology/projects/industry_safety/schema/cq_1.ttl` — TBox
- `ontology/projects/industry_safety/shapes/cq_1.shacl.ttl` — SHACL
- `ontology/projects/industry_safety/abox/r2rml/cq_1.abox.rr.ttl` — R2RML
- `ontology/projects/industry_safety/abox/cq_1.abox.nq` — ABox
- `ontology/projects/industry_safety/resources/reports/kg_cq_1.md` — 빌드 리포트

### 3.6 결과 확인

```bash
# SHACL 검증 재실행
pyshacl \
  -s ontology/projects/industry_safety/shapes/cq_1.shacl.ttl \
  -d ontology/projects/industry_safety/abox/cq_1.abox.nq \
  --ont-graph ontology/projects/industry_safety/schema/cq_1.ttl
```

출력:
```
Conforms: False
  Constraint Violation in SPARQLConstraintComponent (...)
  Focus Node: <.../industry_safety#factory/2>
  Message: 산업안전보건법 제17조제1항 위반: 상시근로자 50인 이상 사업장(...)에 안전관리자가 선임되어 있지 않습니다.
```

---

## 4. 전체 파이프라인

```
[도메인 문서 (법령·규격·정책)]
         │
         ▼
   /doc-wiki          문서 전수 조사 → 도메인 wiki 생성
         │ Human Review
         ▼
   /cq-extract        wiki → Competency Questions (cq.md)
         │ Human Review
         ▼
    (CQ별 독립 진행 — /kg-builder로 한 번에 실행)
         │
         ▼
   /tbox-design       CQ → OWL 2 DL TBox (.ttl)
                      └─ ROBOT reason (HermiT) → Fuseki 업로드
         │ [kg-builder 자율 리뷰]
         ▼
   /shacl-design      TBox → SHACL Shape (.shacl.ttl)
                      └─ pyshacl 검증 (PASS/FAIL/경계 케이스) → Fuseki 업로드
         │ [kg-builder 자율 리뷰]
         ▼
   /mapping-design    RDB 스키마 분석 → R2RML 매핑 (.rr.ttl)
                      └─ morph-kgc 문법 검증
         │ [kg-builder 자율 리뷰]
         ▼
   /abox-build        R2RML → ABox (.nq) → Fuseki 업로드 → SHACL 검증
         │ [kg-builder 자율 리뷰]
         ▼
[Fuseki Named Graph: TBox + SHACL + ABox]
[빌드 리포트: resources/reports/kg_cq_N.md]
```

### 각 단계 진행 방법

#### 옵션 A — 전체 자동 (권장)

```
/kg-builder ontology/projects/industry_safety/resources/cq.md 1
```

4단계를 서브에이전트로 순차 실행하고, 각 단계를 자율 리뷰해 최종 리포트를 작성한다.

#### 옵션 B — 단계별 수동

```
/tbox-design ontology/projects/industry_safety/resources/cq.md 1
# → 검토 후 진행

/shacl-design ontology/projects/industry_safety/resources/cq.md 1
# → 검토 후 진행

/mapping-design ontology/projects/industry_safety/resources/cq.md 1
# → 검토 후 진행

/abox-build ontology/projects/industry_safety/resources/cq.md 1
```

---

## 5. 스킬 레퍼런스

모든 스킬은 Claude Code에서 `/스킬명 인자` 형태로 실행한다.

### /doc-wiki

**목적**: 도메인 문서를 읽고 구조화된 wiki를 생성한다.

```
/doc-wiki [문서경로]
```

**입력**: 법령·규격·정책 마크다운 파일  
**출력**: `ontology/projects/[project]/resources/wiki/[문서명].md`

생성되는 wiki 섹션:
- 핵심 엔티티
- 사업주 의무 조항 (SHACL 검증 가능성 분류)
- 수치 기준 (본문 명시 / 하위법령 위임)
- 관계 (주체 → 동사 → 객체)
- 검증 불가 조항

**실행 예:**
```
/doc-wiki ontology/projects/industry_safety/resources/산업안전보건법.md
```

---

### /cq-extract

**목적**: domain wiki를 읽고 Competency Question 목록을 도출한다.

```
/cq-extract [wiki경로]
```

**입력**: `/doc-wiki`로 생성한 wiki 파일  
**출력**: `ontology/projects/[project]/resources/cq.md`

각 CQ에 포함되는 정보:
- 근거 조항, wiki 엔티티, 준수 조건, 검증 대상, 예상 데이터, 경계 케이스

**실행 예:**
```
/cq-extract ontology/projects/industry_safety/resources/wiki/산업안전보건법.md
```

---

### /kg-builder

**목적**: 단일 CQ에 대한 전체 KG 구축 파이프라인을 서브에이전트로 오케스트레이션한다.  
`/tbox-design` → `/shacl-design` → `/mapping-design` → `/abox-build` 를 자동 실행하고 최종 리포트를 작성한다.

```
/kg-builder [cq_file] [cq_n]
```

| 인자 | 설명 | 예 |
|---|---|---|
| `cq_file` | CQ 목록 파일 경로 | `ontology/projects/industry_safety/resources/cq.md` |
| `cq_n` | 빌드할 CQ 번호 | `1` |

**사전 조건 (자동 확인)**:
- PostgreSQL 컨테이너 실행 중
- Fuseki 실행 중 (HTTP 200)
- `[cq_file]`에 `CQ_[cq_n]` 섹션 존재
- `ontology/projects/[project]/.env` 존재

**산출물**:
```
ontology/projects/[project]/schema/cq_[n].ttl           ← TBox
ontology/projects/[project]/shapes/cq_[n].shacl.ttl     ← SHACL
ontology/projects/[project]/abox/r2rml/cq_[n].abox.rr.ttl  ← R2RML
ontology/projects/[project]/abox/cq_[n].abox.nq         ← ABox
ontology/projects/[project]/resources/reports/kg_cq_[n].md  ← 리포트
```

**리포트 내용**: TBox·SHACL·R2RML·ABox 리뷰 결과, 파이프라인 재현 스크립트, SPARQL 활용 예제, 빌드 요약

**실행 예:**
```
/kg-builder ontology/projects/industry_safety/resources/cq.md 1
/kg-builder ontology/projects/industry_safety/resources/cq.md 2
```

---

### /tbox-design

**목적**: 단일 CQ에 대한 OWL 2 DL TBox를 설계하고 ROBOT으로 검증한다.

```
/tbox-design [cq_file] [cq_n]
```

**출력**: `ontology/projects/[project]/schema/cq_[n].ttl`

TBox 파일에 포함되는 내용:
- `owl:Ontology` 메타데이터 블록 (`owl:versionInfo`, `dcterms:created`, `dcterms:source`)
- `owl:Class` 정의 (각 클래스에 `rdfs:label`, `rdfs:comment`)
- `owl:ObjectProperty` 및 `owl:DatatypeProperty` 정의

**TBox 패치 모드**: `/mapping-design`이 TBox에 누락된 프로퍼티를 발견하면 자동으로 재호출된다. 기존 클래스·프로퍼티는 건드리지 않고 누락 항목만 추가하며 `owl:versionInfo`를 마이너 버전 업(예: `1.0.0 → 1.1.0`)한다.

---

### /shacl-design

**목적**: TBox를 기반으로 SHACL Shape을 작성하고 pyshacl로 검증한다.

```
/shacl-design [cq_file] [cq_n]
```

**출력**: `ontology/projects/[project]/shapes/cq_[n].shacl.ttl`

SHACL 검증 방식:
- 복잡한 집계 조건(COUNT, GROUP BY) → `sh:SPARQLConstraint`
- 단순 존재·카디널리티 조건 → `sh:property`

테스트 데이터를 생성해 PASS 케이스, FAIL 케이스, 경계 케이스를 모두 검증한다.

---

### /mapping-design

**목적**: TBox를 기반으로 R2RML 매핑을 설계하고 morph-kgc로 검증한다.

```
/mapping-design [cq_file] [cq_n]
```

**출력**: `ontology/projects/[project]/abox/r2rml/cq_[n].abox.rr.ttl`

컬럼 → 프로퍼티 유형 판단 기준:

```
FK인가?
├── Yes → 참조 행이 개체(individual)로 매핑되는가?
│          ├── Yes → Object Property (rr:template으로 IRI 연결)
│          └── No  → 코드/열거형인가?
│                     ├── rdf:type 결정에 쓰이는가? → WHERE 필터로 소비
│                     └── 그 외 → Data Property (xsd:string)
└── No  → 숫자·날짜·불린 → Data Property (xsd:integer / xsd:date / xsd:boolean)
           사람·사물 이름   → rdfs:label ("..."@ko)
           그 외 문자열    → Data Property (xsd:string)
```

> **name류 컬럼은 반드시 `rdfs:label`로 매핑**한다. URI만 보여서는 어느 개체인지 파악할 수 없다.

TBox에 누락된 프로퍼티를 발견하면 즉시 중단하고 `TBOX_PATCH_NEEDED`를 보고한다 — `/tbox-design`으로 먼저 패치해야 한다.

---

### /abox-build

**목적**: morph-kgc로 ABox를 생성하고 Fuseki에 적재한 후 SHACL로 검증한다.

```
/abox-build [cq_file] [cq_n]
```

**출력**: `ontology/projects/[project]/abox/cq_[n].abox.nq`

단계:
1. morph-kgc로 N-Quads 생성
2. 기존 Fuseki 그래프 DELETE 후 새로 POST
3. pyshacl로 검증 (PASS/FAIL 예상 노드와 실제 결과 대조)

---

## 6. 스크립트 레퍼런스

모든 스크립트는 저장소 루트에서 실행한다.

### reason.sh — TBox ROBOT 검증

```bash
# 특정 파일
bash ontology/scripts/reason.sh ontology/projects/industry_safety/schema/cq_1.ttl

# schema/ 전체 (인자 없으면 모든 프로젝트의 schema/*.ttl을 검증)
bash ontology/scripts/reason.sh

# 프로젝트 외부 파일 (KG/ 등) — 기본 reasoner hermit 사용
bash ontology/scripts/reason.sh KG/cq_1_merged.ttl
```

내부적으로 `obolibrary/odkfull` Docker 이미지를 사용한다.  
`robot reason`(HermiT 추론, 논리 모순 검사) + `robot report`(QC 체크, 비블로킹)를 순서대로 실행한다.

**환경변수**: `.env`의 `REASONER`로 추론기 변경 가능 (`hermit`, `elk`, `whelk`, `jfact`).

---

### upload.sh — Fuseki 적재

```bash
# TTL 파일 → Named Graph (PUT, 파일명 기반 Graph IRI)
bash ontology/scripts/upload.sh ontology/projects/industry_safety/schema/cq_1.ttl
# → Graph: http://infiniq.co.kr/2026/industry_safety/cq_1

bash ontology/scripts/upload.sh ontology/projects/industry_safety/shapes/cq_1.shacl.ttl
# → Graph: http://infiniq.co.kr/2026/industry_safety/cq_1.shacl

# N-Quads → Named Graph 보존 (POST, 파일 내 그래프 IRI 그대로 적재)
bash ontology/scripts/upload.sh ontology/projects/industry_safety/abox/cq_1.abox.nq
```

Graph IRI 규칙:
- TTL: `{BASE_IRI}/{파일명_without_.ttl}` — 파일명에서 자동 결정
- NQ: 파일 내 named graph IRI를 그대로 사용 (변경 없음)

---

### gen_config.sh — morph-kgc config.ini 자동 생성

```bash
# 특정 프로젝트
bash ontology/scripts/gen_config.sh industry_safety

# 모든 프로젝트
bash ontology/scripts/gen_config.sh
```

`r2rml/*.rr.ttl` 파일을 전부 스캔해 `abox/config.ini`를 덮어쓴다.  
R2RML 파일을 추가하거나 삭제한 뒤 반드시 실행해야 한다.

---

### create_kg.sh — Named Graph 합치기

Fuseki의 여러 Named Graph를 하나의 RDF 파일로 저장한다.

```bash
bash ontology/scripts/create_kg.sh \
  -d industry_safety \
  -o output/cq_1_merged.ttl \
  -g http://infiniq.co.kr/2026/industry_safety/cq_1 \
  -g http://infiniq.co.kr/2026/industry_safety/cq_1.shacl \
  -g http://infiniq.co.kr/2026/industry_safety/cq_1.abox
```

옵션:

| 옵션 | 설명 | 기본값 |
|---|---|---|
| `-d` | 데이터셋 이름 (필수) | — |
| `-o` | 결과 저장 경로 (필수) | — |
| `-g` | Named Graph IRI (1개 이상 필수, 반복 가능) | — |
| `-e` | Fuseki 베이스 URL | `http://localhost:3030` |
| `-u` | Basic 인증 사용자 | `admin` |
| `-p` | Basic 인증 비밀번호 | `admin` |
| `-f` | Accept 헤더 (직렬화 포맷) | `text/turtle` |

---

## 7. 새 프로젝트 설정

### 7.1 디렉토리 생성

```bash
PROJECT=my_project   # 프로젝트명 (영문 소문자, 언더스코어)

mkdir -p ontology/projects/$PROJECT/schema
mkdir -p ontology/projects/$PROJECT/shapes
mkdir -p ontology/projects/$PROJECT/abox/r2rml
mkdir -p ontology/projects/$PROJECT/resources/wiki
mkdir -p ontology/projects/$PROJECT/resources/reports
```

### 7.2 .env 작성

```bash
cat > ontology/projects/$PROJECT/.env << EOF
FUSEKI_DATASET=$PROJECT
BASE_IRI=http://example.org/2026/$PROJECT
REASONER=hermit
DB_URL=postgresql+psycopg://user:password@localhost:5432/dbname
EOF
```

> `.env`는 `.gitignore`에 등록되어 있어 저장소에 커밋되지 않는다.

### 7.3 Fuseki 데이터셋 생성

```bash
# 방법 1: 환경변수로 자동 생성 (docker run 시)
-e FUSEKI_DATASET_1=$PROJECT

# 방법 2: UI에서 수동 생성
# http://localhost:3030 → Manage Datasets → Add New Dataset
# Name: $PROJECT, Type: Persistent (TDB2)
```

### 7.4 도메인 문서 준비

```bash
cp my_document.md ontology/projects/$PROJECT/resources/
```

### 7.5 파이프라인 시작

```
/doc-wiki ontology/projects/$PROJECT/resources/my_document.md
# → 검토 후

/cq-extract ontology/projects/$PROJECT/resources/wiki/my_document.md
# → 검토 후

/kg-builder ontology/projects/$PROJECT/resources/cq.md 1
```

---

## 8. 디렉토리 구조

```
ontology/
├── projects/
│   └── [project]/
│       ├── .env                              # DB_URL, Fuseki 설정 — gitignore
│       ├── schema/
│       │   └── cq_[n].ttl                   # TBox (CQ별)
│       ├── shapes/
│       │   └── cq_[n].shacl.ttl             # SHACL Shape (CQ별)
│       ├── abox/
│       │   ├── r2rml/
│       │   │   └── cq_[n].abox.rr.ttl       # R2RML 매핑 (CQ별)
│       │   ├── config.ini                   # morph-kgc 설정 (자동 생성) — gitignore
│       │   └── cq_[n].abox.nq              # ABox N-Quads (자동 생성) — gitignore
│       └── resources/
│           ├── wiki/[문서명].md             # 도메인 wiki (doc-wiki 생성)
│           ├── [원문문서].md               # 입력 법령·규격 문서
│           ├── cq.md                       # Competency Questions 목록
│           └── reports/
│               └── kg_cq_[n].md            # KG 빌드 리포트
└── scripts/
    ├── reason.sh       # ROBOT 검증 (HermiT)
    ├── upload.sh       # Fuseki 적재 (TTL PUT / NQ POST)
    ├── gen_config.sh   # r2rml/*.rr.ttl 스캔 → config.ini 자동 생성
    └── create_kg.sh    # Fuseki Named Graph 합치기 → 단일 RDF 파일 저장

rdb/
├── docker-compose.yml                       # PostgreSQL 17 컨테이너
└── scripts/
    ├── init_db.sql                          # 테스트 DB 초기화 (컨테이너 시작 시 자동 실행)
    ├── schema_check.sql                     # information_schema 조회 (스키마 파악용)
    ├── normal_worker_map.sql                # v_normal_worker View
    └── safety_manager_map.sql               # v_safety_manager_map View

.claude/
└── skills/                                  # Claude Code 스킬 정의
    ├── kg-builder/SKILL.md
    ├── tbox-design/SKILL.md
    ├── shacl-design/SKILL.md
    ├── mapping-design/SKILL.md
    ├── abox-build/SKILL.md
    ├── cq-extract/SKILL.md
    └── doc-wiki/SKILL.md
```

---

## 9. Named Graph 구조

CQ 단위로 그래프를 분리한다. `upload.sh`가 파일명 기준으로 IRI를 자동 결정한다.

| 파일 | Named Graph IRI | 업로드 방식 |
|---|---|---|
| `schema/cq_[n].ttl` | `{BASE_IRI}/cq_[n]` | PUT (TTL, 덮어쓰기) |
| `shapes/cq_[n].shacl.ttl` | `{BASE_IRI}/cq_[n].shacl` | PUT (TTL, 덮어쓰기) |
| `abox/cq_[n].abox.nq` | `{BASE_IRI}/cq_[n].abox` (파일 내 포함) | POST (N-Quads, graph 보존) |

`industry_safety` 프로젝트 예:
```
http://infiniq.co.kr/2026/industry_safety/cq_1        ← TBox
http://infiniq.co.kr/2026/industry_safety/cq_1.shacl  ← SHACL
http://infiniq.co.kr/2026/industry_safety/cq_1.abox   ← ABox
```

---

## 10. TBox 어노테이션 규약

### 클래스·프로퍼티 어노테이션

모든 클래스와 프로퍼티에 아래 어노테이션을 필수 부착한다.

| 어노테이션 | 내용 |
|---|---|
| `rdfs:label` | 한국어 도메인 용어 — 법령 원문 표현과 정확히 일치 (`"안전관리자"@ko`) |
| `rdfs:comment` | `"[법적·도메인 정의]. [이 CQ에서의 역할]. 근거: 제N조."@ko` |

### 파일 수준 메타데이터 (owl:Ontology 블록)

```turtle
<http://infiniq.co.kr/2026/industry_safety/cq_1> a owl:Ontology ;
    owl:versionInfo "1.0.0" ;
    dcterms:created "2026-05-07"^^xsd:date ;
    dcterms:source <https://www.law.go.kr/법령/산업안전보건법> ;
    rdfs:label "CQ_1 TBox — 안전관리자 선임"@ko .
```

| 프로퍼티 | 내용 |
|---|---|
| `owl:versionInfo` | `"1.0.0"` 시작. 클래스·프로퍼티 구조 변경 시 마이너 버전 업 (`1.0.0 → 1.1.0`) |
| `dcterms:created` | 파일 최초 생성일. 이후 변경하지 않는다 |
| `dcterms:source` | 근거 법령·규격의 URL |
| `rdfs:label` | 온톨로지 제목 |

### 예시

```turtle
@prefix is: <http://infiniq.co.kr/2026/industry_safety#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<http://infiniq.co.kr/2026/industry_safety/cq_1> a owl:Ontology ;
    owl:versionInfo "1.0.0" ;
    dcterms:created "2026-05-07"^^xsd:date ;
    dcterms:source <https://www.law.go.kr/법령/산업안전보건법> ;
    rdfs:label "CQ_1 TBox — 안전관리자 선임"@ko .

is:SafetyManager a owl:Class ;
    rdfs:label "안전관리자"@ko ;
    rdfs:comment "사업장 안전에 관한 기술적 사항을 관리하는 자. 제17조제1항에 따라 상시근로자 50인 이상 사업장에 선임 의무. 근거: 산업안전보건법 제17조제1항."@ko .

is:appointsManager a owl:ObjectProperty ;
    rdfs:domain is:Workplace ;
    rdfs:range is:SafetyManager ;
    rdfs:label "안전관리자 선임"@ko ;
    rdfs:comment "사업장이 안전관리자를 선임하는 관계. CQ_1 준수 여부 판단에 직접 사용. 근거: 제17조제1항."@ko .
```

---

## 11. Fuseki SPARQL 활용

Fuseki UI: `http://localhost:3030`  
SPARQL 엔드포인트: `http://localhost:3030/industry_safety/sparql`

### 적재된 그래프 목록 확인

```sparql
SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }
```

### 그래프별 트리플 수

```sparql
SELECT ?g (COUNT(*) AS ?n)
WHERE { GRAPH ?g { ?s ?p ?o } }
GROUP BY ?g
ORDER BY DESC(?n)
```

### 안전관리자 미선임 사업장 조회 (CQ_1)

```sparql
PREFIX is: <http://infiniq.co.kr/2026/industry_safety#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

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
```

### 사업장별 현황 요약

```sparql
PREFIX is: <http://infiniq.co.kr/2026/industry_safety#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

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

### 그래프 전체 삭제 (재빌드 전)

```bash
# ABox만 삭제
curl -u admin:admin -X DELETE \
  "http://localhost:3030/industry_safety/data?graph=http://infiniq.co.kr/2026/industry_safety/cq_1.abox"

# 모든 그래프 삭제 (주의: 전체 데이터셋 초기화)
curl -u admin:admin -X DELETE \
  "http://localhost:3030/industry_safety/data"
```

---

## 12. 트러블슈팅

### PostgreSQL 접속 실패

```
Error: could not connect to server
```

```bash
docker ps | grep rdb    # 컨테이너 상태 확인
cd rdb && docker compose up -d && cd ..
# 초기화가 필요하면
cd rdb && docker compose down -v && docker compose up -d && cd ..
```

### Fuseki 접속 실패

```
Connection refused
```

```bash
docker ps | grep fuseki   # 컨테이너 상태 확인
# fuseki 컨테이너 재시작
docker start fuseki
# 데이터셋이 없으면 → http://localhost:3030 → Manage Datasets → Add
```

### ROBOT 검증 실패

```
ERROR: Reasoner threw an exception
```

- 원인: OWL 논리 모순 (보통 도메인·레인지 충돌)
- 해결: `robot reason` 출력의 `Explanation` 섹션을 읽고 해당 클래스·프로퍼티 수정

```bash
# 상세 로그 확인
bash ontology/scripts/reason.sh ontology/projects/industry_safety/schema/cq_1.ttl 2>&1 | less
```

### morph-kgc 실패

```
sqlalchemy.exc.OperationalError: ...
```

- 원인 1: DB 접속 불가 → PostgreSQL 컨테이너 확인
- 원인 2: `.env`의 `DB_URL` 오류 → `DB_URL=postgresql+psycopg://user:password@localhost:5432/dbname` 형식 확인
- 원인 3: View가 없음 → `rdb/scripts/` 아래 View SQL 파일 실행 여부 확인

```bash
# DB 직접 접속 테스트
docker exec -it rdb-db-1 psql -U joono -d industry_safety -c "\dt"
```

### pyshacl SHACL 검증 예상 외 결과

```
SHACL 결과가 CQ 경계 케이스와 불일치
```

1. ABox 트리플을 먼저 확인한다:
   ```bash
   grep "factory/2" ontology/projects/industry_safety/abox/cq_1.abox.nq
   ```
2. SHACL의 SPARQL 서브쿼리가 OPTIONAL을 빠뜨리지 않았는지 확인한다.
3. 원인이 ABox이면 `/mapping-design`으로, SHACL이면 `/shacl-design`으로 돌아간다.

### reason.sh가 경로를 인식 못함

```
WARNING: ontology/projects//path/to/file/.env not found
```

- 원인: `ontology/projects/<project>/...` 패턴 외 경로 (예: `KG/`)
- 수정된 `reason.sh`는 이 경우 기본 `REASONER=hermit`로 계속 실행한다.
- 절대 경로 대신 저장소 루트 기준 상대 경로를 사용하면 안정적이다:
  ```bash
  bash ontology/scripts/reason.sh KG/cq_1_merged.ttl   # OK
  ```

---

## 진행 상태 — industry_safety (산업안전보건법)

| CQ | 조항 | 내용 | TBox | SHACL | R2RML | ABox |
|---|---|---|---|---|---|---|
| CQ_1 | 제17조 | 안전관리자 선임 (≥50인) | ✅ | ✅ | ✅ | ✅ |
| CQ_2 | 제18조 | 보건관리자 선임 (≥300인) | — | — | — | — |
| CQ_3 | 제29조 | 안전보건교육 이수 | — | — | — | — |
| CQ_4 | 제36조 | 위험성평가 (연 1회) | — | — | — | — |
| CQ_5 | 제93조 | 안전검사 주기 | — | — | — | — |
| CQ_6 | 제125조 | 작업환경측정 (6개월) | — | — | — | — |
| CQ_7 | 제129조 | 일반건강진단 | — | — | — | — |

---

## 기술 스택

| 역할 | 도구 |
|---|---|
| 온톨로지 추론 검증 | ROBOT (HermiT, via ODK Docker) |
| SHACL 검증 | pyshacl |
| RDB → RDF 매핑 | R2RML + morph-kgc |
| Triple Store | Apache Jena Fuseki (TDB2) |
| RDB | PostgreSQL 17 (Docker) |
| 에이전트 | Claude Code (claude-sonnet-4-6) |
