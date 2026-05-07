# 산업안전보건법 온톨로지 프로젝트

산업안전보건법 조항을 OWL 2 DL 온톨로지로 모델링하고, SHACL로 준수 여부를 검증하는 프로젝트.

상세 아키텍처 및 로드맵 → [`plan.md`](plan.md)  
법률 조항 원문 → [`ontology/projects/industry_safety/resources/산업안전보건법.md`](ontology/projects/industry_safety/resources/산업안전보건법.md)  
Competency Questions → [`ontology/projects/industry_safety/resources/cq.md`](ontology/projects/industry_safety/resources/cq.md)

---

## 디렉토리 구조

```
KG/
├── ex1.ttl           # KG 예제
└── kg.ttl            # KG 메인

demo/
├── app.py                  # Streamlit 진입점
├── config.py               # 규칙 메타데이터 (법조항, CQ, 파일경로 등)
├── settings.py             # 전역 경로 설정 (PROJECT_ROOT, LAW_FILE)
├── services/
│   ├── validator.py        # pyshacl 호출 + RDF 결과 파싱
│   ├── etl.py              # ETL 스크립트 실행
│   ├── loader.py           # TTL, 법률 텍스트 파일 읽기
│   └── abox_reader.py      # ABox 파일 읽기
└── components/
    ├── law_panel.py        # ① 법률 조항 탭
    ├── cq_panel.py         # ② CQ 탭
    ├── tbox_panel.py       # ③ TBox 탭
    ├── shacl_panel.py      # ④ SHACL 탭
    └── result_panel.py     # ⑤ 검증 탭

ontology/
├── projects/
│   ├── industry_safety/            # 산업안전보건법 프로젝트
│   │   ├── schema/                 # TBox — OWL 클래스·프로퍼티 정의
│   │   │   ├── r1.ttl              # 제17조 — 안전관리자 선임
│   │   │   ├── r2.ttl              # 제29조 — 안전보건교육
│   │   │   ├── r3.ttl              # 제36조 — 위험성평가
│   │   │   ├── r4.ttl              # 제93조 — 안전검사
│   │   │   └── r5.ttl              # 제125조 — 작업환경측정
│   │   ├── shapes/                 # SHACL Shapes — 법률 제약 표현
│   │   │   └── r1.shacl.ttl
│   │   ├── abox/                   # ABox — ETL로 생성된 인스턴스 데이터
│   │   │   ├── r2rml/
│   │   │   │   └── r1.abox.rr.ttl  # R2RML 매핑 파일 (PostgreSQL → RDF)
│   │   │   ├── config.ini           # morph-kgc 설정 (DB 연결 + 매핑 파일 경로)
│   │   │   ├── r1.abox.nq           # materialization 결과 (N-QUADS)
│   │   │   └── r1.abox_py.ttl       # Python ETL 결과 (레거시)
│   │   └── resources/              # 참고 자료
│   │       ├── 산업안전보건법.md
│   │       └── cq.md
│   └── metttc/
│       └── schema/
│           └── stp_mett_tc_extension_schema_v0_1.ttl
└── scripts/                        # 실행 스크립트
    ├── create_kg.sh                 # KG 생성
    ├── delete_graph.sh              # Named Graph 삭제
    ├── nt_to_ttl.sh                 # N-Triples → Turtle 변환
    ├── reason.sh                    # ROBOT 추론 및 검증
    └── upload.sh                    # Fuseki 적재

rdb/
├── docker-compose.yml        # PostgreSQL 컨테이너 설정
└── scripts/
    ├── init_db.sql            # 테이블 생성 + 테스트 데이터 삽입
    ├── etl.sql                # ABox 생성용 JOIN 쿼리
    ├── etl.py                 # PostgreSQL → Turtle ETL 스크립트
    ├── normal_worker_map.sql  # 상시근로자 뷰 정의
    ├── safety_manager_map.sql # 안전관리자 뷰 정의
    └── schema_check.sql       # DB 스키마 검증 쿼리
```

---

## 멀티 에이전트 파이프라인

온톨로지 구축을 자동화하는 6개의 Claude Code 스킬. 각 단계는 Human Review 후 다음 단계로 진행한다.

### 전체 흐름

```
/doc-wiki [문서]     문서 → 도메인 wiki          resources/wiki/[문서명].md
      ↓ Human Review
/cq-extract          wiki → CQ 도출              resources/cq.md
      ↓ Human Review
/tbox-design cq_n    CQ  → TBox + ROBOT 검증     schema/cq_n.ttl
      ↓ Human Review
/shacl-design cq_n   TBox → SHACL + pyshacl 검증 shapes/cq_n.shacl.ttl
      ↓ Human Review
/mapping-design cq_n CQ + DB 스키마 → R2RML 매핑 abox/r2rml/cq_n.abox.rr.ttl
      ↓ Human Review
/abox-build cq_n     R2RML → ABox + SHACL 검증   abox/cq_n.abox.nq
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

```bash
pip install pyshacl psycopg2-binary rdflib streamlit morph-kgc[postgresql]
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

이 프로젝트는 그래프를 목적별로 분리한다.

| Named Graph IRI | 용도 |
|-----------------|------|
| `.../schema` | TBox (클래스·프로퍼티) |
| `.../shapes` | SHACL Shapes |
| `.../data` | ABox (인스턴스) |
| `.../inferred` | 추론 결과 (선택적) |

`upload.sh`가 파일명 기준으로 그래프 IRI를 자동 결정한다.  
예: `schema/r1.ttl` → `http://infiniq.co.kr/2026/industry_safety/r1`

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
    ↓ DB VIEW (v_normal_worker, v_safety_manager_map)
    ↓ R2RML 매핑 (r2rml/r1.abox.rr.ttl)
    ↓ morph-kgc materialization
ontology/projects/industry_safety/abox/r1.abox.nq   ← Named Graph 포함 (N-QUADS)
```

**TriplesMap 구성:**

| TriplesMap | 소스 | 생성 트리플 |
|---|---|---|
| FactoryMap | `factory` 테이블 | `factory/{id} rdf:type is:사업장` |
| NormalWorkerMap | VIEW `v_normal_worker` | `person/{id} rdf:type is:상시근로자` |
| NormalWorkerFactoryMap | VIEW `v_normal_worker` | `factory/{id} is:고용하다 person/{id}` |
| SafetyManagerMap | VIEW `v_safety_manager_map` | `person/{id} rdf:type is:안전관리자` |
| SafetyManagerFactoryMap | VIEW `v_safety_manager_map` | `factory/{id} is:선임하다 person/{id}` |

### morph-kgc 실행

매핑: `ontology/projects/industry_safety/abox/r2rml/r1.abox.rr.ttl`  
설정: `ontology/projects/industry_safety/abox/config.ini`

```bash
python -m morph_kgc ontology/projects/industry_safety/abox/config.ini
```

`r1.abox.nq` (N-QUADS) 파일이 생성된다.

### Fuseki 업로드

```bash
curl -u admin:admin -X PUT \
  -H "Content-Type: application/n-quads" \
  --data-binary @ontology/projects/industry_safety/abox/r1.abox.nq \
  "http://localhost:3030/industry_safety/data?graph=http://infiniq.co.kr/2026/industry_safety/r1.abox"
```

---

## SHACL 검증

```bash
pyshacl \
  -s ontology/projects/industry_safety/shapes/r1.shacl.ttl \
  -d ontology/projects/industry_safety/abox/r1.abox.nq
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
[PROCESS]    법률 분석 + CQ 도출
             OUT: cq.md (5개 CQ 정의)
                    |
        ┌───────────┼───────────┬───────────┬───────────┐
       CQ1         CQ2         CQ3         CQ4         CQ5
        |
        ▼
[PROCESS]  TBox 모델링  <─────────────────────┐
           OUT: schema/rN.ttl                 | 오류시 수정
                    |                         |
[PROCESS]  ROBOT reason/report ───────────────┘
                    |
               통과 |
                    |
[PROCESS]  SHACL Shape 작성
           OUT: shapes/rN.shacl.ttl
                    |
- - - - - - - - - - ↓ - - - - - - - - - - - - - - - - -
                    |
[DATA]       PostgreSQL DB  ← 공장 측 제공 데이터
                    |
[PROCESS]  ETL (R2RML + morph-kgc)
           OUT: abox/rN.abox.nq
                    |
[PROCESS]  SHACL 검증 (pyshacl)
           OUT: Validation Report (Conforms: True/False)
```

**현재 진행 상태:**

| 단계 | CQ1 | CQ2 | CQ3 | CQ4 | CQ5 |
|------|-----|-----|-----|-----|-----|
| TBox 모델링 | ✅ | ✅ | ✅ | ✅ | ✅ |
| ROBOT 검증 | ✅ | ✅ | ✅ | ✅ | ✅ |
| SHACL 작성 | ✅ | - | - | - | - |
| ETL 매핑   | ✅ | - | - | - | - |
| SHACL 검증 | ✅ | - | - | - | - |

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
