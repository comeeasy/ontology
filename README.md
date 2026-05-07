# 산업안전보건법 온톨로지 프로젝트

산업안전보건법 조항을 OWL 2 DL 온톨로지로 모델링하고, SHACL로 준수 여부를 검증하는 프로젝트.

법률 조항 원문 → [`ontology/projects/industry_safety/resources/산업안전보건법.md`](ontology/projects/industry_safety/resources/산업안전보건법.md)  
Competency Questions → [`ontology/projects/industry_safety/resources/cq.md`](ontology/projects/industry_safety/resources/cq.md)

---

## 디렉토리 구조

```
ontology/
├── projects/
│   ├── industry_safety/              # 산업안전보건법 프로젝트
│   │   ├── .env                      # 프로젝트 설정 (DB_URL, Fuseki, Reasoner) — gitignore
│   │   ├── schema/                   # TBox — OWL 클래스·프로퍼티 정의
│   │   │   └── cq_[n].ttl            # CQ별 TBox (cq_1.ttl, cq_2.ttl, ...)
│   │   ├── shapes/                   # SHACL Shapes — 법률 제약 표현
│   │   │   └── cq_[n].shacl.ttl      # CQ별 SHACL Shape
│   │   ├── abox/                     # ABox — ETL로 생성된 인스턴스 데이터
│   │   │   ├── r2rml/
│   │   │   │   └── cq_[n].abox.rr.ttl  # CQ별 R2RML 매핑
│   │   │   ├── config.ini            # morph-kgc 설정 (gen_config.sh 자동 생성) — gitignore
│   │   │   └── cq_[n].abox.nq        # materialization 결과 (N-QUADS) — gitignore
│   │   └── resources/                # 참고 자료
│   │       ├── wiki/
│   │       │   └── 산업안전보건법.md  # 도메인 wiki (doc-wiki 생성)
│   │       ├── 산업안전보건법.md      # 원문
│   │       └── cq.md                 # Competency Questions
│   └── metttc/
│       ├── .env
│       └── schema/
└── scripts/                          # 실행 스크립트
    ├── reason.sh                     # ROBOT 추론 검증 (프로젝트별 .env 참조)
    ├── upload.sh                     # Fuseki 적재 (TTL: PUT+graph / NQ: POST)
    └── gen_config.sh                 # morph-kgc config.ini 자동 생성

rdb/
├── docker-compose.yml          # PostgreSQL 컨테이너 설정
└── scripts/
    ├── init_db.sql              # 테이블 생성 + 테스트 데이터 삽입
    ├── normal_worker_map.sql    # 상시근로자 뷰 정의
    ├── safety_manager_map.sql   # 안전관리자 뷰 정의
    └── schema_check.sql         # DB 스키마 조회 (information_schema)
```

---

## 멀티 에이전트 파이프라인

온톨로지 구축을 자동화하는 6개의 Claude Code 스킬. 각 단계는 Human Review 후 다음 단계로 진행한다.

### 전체 흐름

```
/doc-wiki [문서경로]            문서 → 도메인 wiki          resources/wiki/[문서명].md
      ↓ Human Review
/cq-extract [wiki경로]          wiki → CQ 도출              resources/cq.md
      ↓ Human Review
/tbox-design [cq_file] [cq_n]  CQ  → TBox + ROBOT 검증     schema/cq_[n].ttl
      ↓ Human Review
/shacl-design [cq_file] [cq_n] TBox → SHACL + pyshacl 검증 shapes/cq_[n].shacl.ttl
      ↓ Human Review
/mapping-design [cq_file] [cq_n] CQ + DB → R2RML 매핑       abox/r2rml/cq_[n].abox.rr.ttl
      ↓ Human Review
/abox-build [cq_file] [cq_n]   R2RML → ABox + SHACL 검증   abox/cq_[n].abox.nq
      ↓ Human Review
```

### 스킬별 Human Review 체크리스트

**`/doc-wiki`** — 도메인 wiki 생성
- [ ] 핵심 엔티티가 빠짐없이 추출되었는가?
- [ ] 의무 조항의 "누가/무엇을/조건" 분해가 정확한가?
- [ ] 수치 기준(임계값·기간·횟수)이 모두 포함되었는가?
- [ ] 검증 불가 조항 분류가 타당한가?

**`/cq-extract`** — CQ 도출
- [ ] 각 CQ가 "예/아니오"로 답 가능한 형태인가?
- [ ] "예상 데이터"가 실제 DB에 존재하는가?
- [ ] 제외 조항 분류가 타당한가?

**`/tbox-design`** — TBox 설계
- [ ] 해당 CQ에만 필요한 최소 클래스·프로퍼티만 있는가?
- [ ] 도메인 용어와 네이밍이 일치하는가?
- [ ] ROBOT 오류 없는가?

**`/shacl-design`** — SHACL 설계
- [ ] `sh:select` 조건이 CQ 의도를 정확히 구현하는가?
- [ ] 경계 케이스(임계값 등)가 반영되어 있는가?
- [ ] `sh:message`가 도메인 전문가가 읽을 수 있는 한국어인가?
- [ ] PASS/FAIL 예상 케이스가 모두 올바른가?

**`/mapping-design`** — R2RML 매핑
- [ ] CQ에 필요한 트리플이 모두 커버되는가?
- [ ] IRI 템플릿이 유일성을 보장하는가?
- [ ] NULL/예외 케이스 처리가 명시되어 있는가?

**`/abox-build`** — ABox 생성
- [ ] 생성 트리플 수가 예상 범위인가?
- [ ] SHACL 결과가 예상 PASS/FAIL과 일치하는가?
- [ ] 데이터 변환 오류·손실이 없는가?

---

## 환경 설정

### 필수 소프트웨어

| 소프트웨어 | 용도 | 확인 명령 |
|------------|------|-----------|
| Docker Desktop | PostgreSQL, ROBOT 추론 | `docker --version` |
| Apache Jena Fuseki | Triple Store | `http://localhost:3030` 접속 확인 |
| Python 3.x | ETL, SHACL 검증, 데모 앱 | `python --version` |
| Conda `onto` 환경 | morph-kgc 실행 전용 | `conda activate onto` |

```bash
# 기본 환경
pip install pyshacl psycopg2-binary rdflib streamlit

# morph-kgc는 onto conda 환경에 별도 설치
conda create -n onto python=3.11 -y
conda run -n onto pip install morph-kgc sqlalchemy psycopg
```

morph-kgc 실행 시 반드시 `onto` 환경을 사용한다:

```bash
conda run -n onto python -m morph_kgc ontology/projects/industry_safety/abox/config.ini
```

### PostgreSQL (rdb)

```bash
cd rdb
docker compose up -d
```

`init_db.sql`이 자동 실행되어 테이블 생성 및 테스트 데이터가 삽입된다.  
초기화가 필요하면: `docker compose down -v && docker compose up -d`

**테스트 데이터 구성 (R1 검증용):**

| 공장 | 근로자 수 | 안전관리자 | R1 예상 결과 |
|------|-----------|------------|-------------|
| A공장 | 51명 | 1명 | PASS |
| B공장 | 51명 | 없음 | FAIL |
| C공장 | 11명 | 없음 | PASS (50인 미만) |

### Apache Jena Fuseki

```bash
docker run -d --name fuseki -p 3030:3030 \
  -e ADMIN_PASSWORD=admin \
  -e TDB=2 \
  -e FUSEKI_DATASET_1=industry_safety \
  -v fuseki-data:/fuseki \
  stain/jena-fuseki:5.1.0
```

이미지·태그는 [Docker Hub — stain/jena-fuseki](https://hub.docker.com/r/stain/jena-fuseki) 참고.  
`FUSEKI_DATASET_1` 없이 올린 경우 UI(`http://localhost:3030`) → **Manage Datasets** → **Add new dataset**에서 `industry_safety` (Persistent / TDB2)를 수동 생성해야 `upload.sh`가 동작한다.

---

## 온톨로지 구축 (TBox)

### Named Graph 구조

CQ 단위로 그래프를 분리한다. `upload.sh`가 파일명 기준으로 그래프 IRI를 자동 결정한다.

| 파일 | Named Graph IRI | 업로드 방식 |
|------|-----------------|------------|
| `schema/cq_[n].ttl` | `.../cq_[n]` | PUT (TTL) |
| `shapes/cq_[n].shacl.ttl` | `.../cq_[n].shacl` | PUT (TTL) |
| `abox/cq_[n].abox.nq` | `.../cq_[n].abox` (파일 내 포함) | POST (N-Quads) |

### Fuseki 적재

```bash
bash ontology/scripts/upload.sh
```

`ontology/` 아래 모든 `.ttl` 파일을 순회하며 각 파일을 해당 Named Graph에 PUT한다.

적재 확인:

```sparql
SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }
```

### ROBOT 추론 검증

ROBOT은 ODK Docker 이미지(`obolibrary/odkfull`)를 통해 실행된다.

```bash
bash ontology/scripts/reason.sh
```

각 `.ttl` 파일에 대해 순서대로:
1. `robot reason` — HermiT 추론기로 OWL 논리 일관성 검사
2. `robot report` — OBO Foundry 메타데이터 기준 리포트

`[reason]` 단계에서 오류가 나오면 논리 모순이다.  
`[report]` 단계의 경고(missing_label 등)는 OBO Foundry 메타데이터 표준 미준수로, 이 프로젝트에서는 무시한다.

---

## ABox 매핑 (ETL)

### ETL 흐름

```
PostgreSQL (factory, person, role 테이블)
    ↓ rr:sqlQuery (JOIN 직접 — VIEW 불필요)
    ↓ R2RML 매핑 (r2rml/cq_[n].abox.rr.ttl)
    ↓ morph-kgc materialization
abox/cq_[n].abox.nq   ← Named Graph 포함 (N-QUADS)
```

### config.ini 자동 생성

`gen_config.sh`가 `.env`와 `r2rml/*.rr.ttl`을 스캔해 `config.ini`를 생성한다. 수동 편집 불필요.

```bash
bash ontology/scripts/gen_config.sh industry_safety
```

### morph-kgc 실행 (CQ별)

`/abox-build` 스킬이 CQ-specific 임시 config를 생성해 실행한다.

```bash
source ontology/projects/industry_safety/.env
cat > /tmp/cq_[n]_config.ini << EOF
[CONFIGURATION]
output_file: ontology/projects/industry_safety/abox/cq_[n].abox.nq
output_format: N-QUADS

[DataSource1]
mappings: ontology/projects/industry_safety/abox/r2rml/cq_[n].abox.rr.ttl
db_url: $DB_URL
EOF
conda run -n onto python3 -m morph_kgc /tmp/cq_[n]_config.ini
```

### Fuseki 업로드

N-Quads는 named graph가 파일 내 포함 → POST `/data` (graph 지정 없음).

```bash
# 기존 그래프 삭제 후 재적재
curl -u admin:admin -X DELETE \
  "http://localhost:3030/industry_safety/data?graph=http://infiniq.co.kr/2026/industry_safety/cq_[n].abox"
bash ontology/scripts/upload.sh ontology/projects/industry_safety/abox/cq_[n].abox.nq
```

---

## SHACL 검증

```bash
pyshacl \
  -s ontology/projects/industry_safety/shapes/cq_[n].shacl.ttl \
  -d ontology/projects/industry_safety/abox/cq_[n].abox.nq \
  --ont-graph ontology/projects/industry_safety/schema/cq_[n].ttl
```

**결과 해석:**

- `Conforms: True` → 모든 사업장 PASS
- `Conforms: False` → `Focus Node`에 위반 사업장 URI 표시

**주의:** SHACL의 `sh:select` 쿼리 안에는 TTL prefix가 상속되지 않으므로 반드시 `PREFIX` 선언을 포함해야 한다.

```sparql
PREFIX is: <http://infiniq.co.kr/2026/industry_safety#>
SELECT $this WHERE { ... }
```

---

## 전체 파이프라인

온톨로지의 모든 설계 단위는 **CQ(Competency Question)**다.  
TBox(.ttl), SHACL(.shacl.ttl), ABox 매핑은 CQ 하나당 하나씩 작성된다.

```
[DATA]       산업안전보건법.md
                    |
[SKILL]  /doc-wiki → wiki/산업안전보건법.md
[SKILL]  /cq-extract → cq.md (7개 CQ)
                    |
        CQ1 ~ CQ7 (각 CQ 독립 진행)
                    |
[SKILL]  /tbox-design   → schema/cq_[n].ttl   (ROBOT 검증 + Fuseki 업로드)
[SKILL]  /shacl-design  → shapes/cq_[n].shacl.ttl (pyshacl 검증 + Fuseki 업로드)
[SKILL]  /mapping-design → abox/r2rml/cq_[n].abox.rr.ttl
[SKILL]  /abox-build    → abox/cq_[n].abox.nq (Fuseki 업로드 + SHACL 검증)
```

**현재 진행 상태:**

| 단계 | CQ1 | CQ2 | CQ3 | CQ4 | CQ5 | CQ6 | CQ7 |
|------|-----|-----|-----|-----|-----|-----|-----|
| TBox (/tbox-design)     | ✅ | - | - | - | - | - | - |
| SHACL (/shacl-design)   | ✅ | - | - | - | - | - | - |
| R2RML (/mapping-design) | ✅ | - | - | - | - | - | - |
| ABox (/abox-build)      | ✅ | - | - | - | - | - | - |

---

## 데모 앱 (Streamlit)

법률 조항 → CQ → TBox → SHACL → 검증 실행까지 전체 파이프라인을 탭 형태로 시각화하는 웹 앱.

새 규칙(R2~R5) 구현 완료 시 `demo/config.py`의 해당 항목에서 `"enabled": True`로 변경하면 자동 활성화된다.

```bash
cd /path/to/ontology   # 프로젝트 루트에서 실행 (settings.py가 __file__ 기준으로 경로 계산)
streamlit run demo/app.py
```

브라우저에서 `http://localhost:8501` 접속.

| 탭 | 내용 |
|----|------|
| ① 법률 조항 | 산업안전보건법 원문 + 준수 조건 요약 |
| ② CQ | 이 규칙이 답해야 하는 질문 |
| ③ TBox | 클래스·프로퍼티 관계표 + TTL 원문 |
| ④ SHACL | SHACL Shape 원문 |
| ⑤ 검증 | ETL 실행 버튼 + SHACL 검증 버튼 + 결과 |

**사전 조건:**

- [ ] `docker compose up -d` (rdb 디렉토리에서)
- [ ] Python 의존성 설치
- [ ] Fuseki 실행 중 (`http://localhost:3030`)
