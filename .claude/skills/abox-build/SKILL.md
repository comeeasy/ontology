# /abox-build

**data_ingest 2단계**: morph-kgc로 ABox를 생성하고 Fuseki에 적재한 후 SHACL로 검증한다.

## 입력

`/abox-build [cq_file] [cq_n]`

- `cq_file`: CQ 목록 파일 경로 (예: `ontology/projects/industry_safety/resources/cq.md`)
- `cq_n`: 빌드할 CQ 번호 (예: `1` → `CQ_1`)

예: `/abox-build ontology/projects/industry_safety/resources/cq.md 1`

---

## 설계 원칙

### 1. 먼저 생각하라 (Think Before Building)

가정하지 말 것. 혼란을 숨기지 말 것. 트레이드오프를 드러낼 것.

실행 전에:
- CQ의 경계 케이스(PASS/FAIL 예상 노드)를 DB 데이터에서 확인한다. 예상과 다르면 R2RML이나 SHACL을 먼저 점검한다.
- PostgreSQL과 Fuseki가 실행 중인지 확인한다. 미실행 시 즉시 중단하고 사용자에게 알린다.
- 불확실한 것이 있으면 멈춘다. 무엇이 혼란스러운지 명시하고 묻는다.

### 2. 단순함 우선 (Simplicity First)

필요한 것만 실행한다. 불필요한 재생성 금지.

- 이 CQ의 R2RML 파일만으로 CQ-specific config를 만들어 실행한다. 다른 CQ 매핑을 함께 재실행하지 않는다.
- SHACL 검증은 생성된 로컬 .nq 파일로 실행한다. Fuseki SPARQL 엔드포인트를 쓰지 않는다.

### 3. 외과적 수정 (Surgical Changes)

이 CQ의 그래프만 건드린다.

- Fuseki 업로드 전 해당 named graph를 DELETE하고 새로 POST한다. 다른 그래프는 건드리지 않는다.
- SHACL 검증 실패 시: R2RML 수정이 필요하면 `/mapping-design`으로 돌아간다. SHACL 수정이 필요하면 `/shacl-design`으로 돌아간다. 이 스킬에서 직접 수정하지 않는다.

### 4. 목표 기반 실행 (Goal-Driven Execution)

성공 기준을 정의하고, 검증될 때까지 반복한다.

이 스킬의 성공 기준:
1. morph-kgc 실행 → 검증: `cq_[n].abox.nq` 생성, 트리플 수 > 0
2. Fuseki 업로드 → 검증: HTTP 200/204 응답
3. SHACL 검증 → 검증: 예상 PASS 노드 Conformant, 예상 FAIL 노드 Violation

SHACL 결과가 예상과 다를 시:
- 원인이 R2RML이면: 멈추고 `/mapping-design`으로 돌아가야 함을 보고한다.
- 원인이 SHACL이면: 멈추고 `/shacl-design`으로 돌아가야 함을 보고한다.
- 2회 분석 후에도 원인 불명이면: 멈추고 사용자에게 상세 내용을 보고한다.

---

## 실행 절차

### 1단계 — 사전 조건 확인

```bash
docker ps --filter "name=rdb" --format "{{.Status}}"
curl -s -o /dev/null -w "%{http_code}" http://localhost:3030
```

PostgreSQL 또는 Fuseki가 미실행이면 즉시 중단하고 사용자에게 알린다.

### 2단계 — 컨텍스트 읽기

- `[cq_file]`에서 `CQ_[cq_n]`의 경계 케이스·예상 PASS/FAIL 확인.
- `ontology/projects/industry_safety/.env` — `DB_URL` 확인.
- `ontology/projects/industry_safety/abox/r2rml/cq_[cq_n].abox.rr.ttl` — 매핑 파일 존재 확인.
- `ontology/projects/industry_safety/shapes/cq_[cq_n].shacl.ttl` — SHACL 파일 존재 확인.

### 3단계 — morph-kgc 실행

CQ-specific 임시 config를 생성하고 실행한다.

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

생성 확인:
```bash
wc -l ontology/projects/industry_safety/abox/cq_[n].abox.nq
```

### 4단계 — Fuseki 업로드

기존 그래프를 삭제하고 새로 적재한다.

```bash
# 기존 그래프 삭제
curl -s -u admin:admin -X DELETE \
    "http://localhost:3030/industry_safety/data?graph=http://infiniq.co.kr/2026/industry_safety/cq_[n].abox"

# N-Quads POST (named graph 보존)
bash ontology/scripts/upload.sh ontology/projects/industry_safety/abox/cq_[n].abox.nq
```

### 5단계 — SHACL 검증

```bash
pyshacl \
    -s ontology/projects/industry_safety/shapes/cq_[cq_n].shacl.ttl \
    -d ontology/projects/industry_safety/abox/cq_[n].abox.nq \
    --ont-graph ontology/projects/industry_safety/schema/cq_[cq_n].ttl
```

결과 해석:
- `Conforms: True` → 전체 PASS. CQ의 FAIL 예상 노드가 없는지 확인한다.
- `Conforms: False` → Focus Node 목록을 CQ 경계 케이스와 대조한다.

### 6단계 — 검토 요청

```
=== ABox 빌드 완료 — Human Review ===

파일: ontology/projects/industry_safety/abox/cq_[n].abox.nq
morph-kgc: PASS (N 트리플)
Fuseki: UPLOADED
Graph: http://infiniq.co.kr/2026/industry_safety/cq_[n].abox

SHACL 검증 결과:
  Conforms: [True / False]
  위반 노드: [URI 목록 | 없음]

예상 결과 대조:
  PASS 예상: [노드 설명] → [Conformant ✓ | Violation ✗]
  FAIL 예상: [노드 설명] → [Violation ✓ | Conformant ✗]

검토 항목:
□ 생성 트리플 수가 예상 범위인가?
□ SHACL 결과가 CQ 경계 케이스와 일치하는가?
□ 위반 노드 URI가 실제 위반 대상과 일치하는가?
□ Fuseki named graph IRI가 올바른가?

파이프라인 완료. 다음 CQ는 /tbox-design [cq_file] [cq_n+1] 로 진행.
```
