# /mapping-design

**data_ingest 1단계**: CQ의 TBox를 기반으로 R2RML 매핑을 설계한다.

## 입력

`/mapping-design [cq_file] [cq_n]`

- `cq_file`: CQ 목록 파일 경로 (예: `ontology/projects/industry_safety/resources/cq.md`)
- `cq_n`: 설계할 CQ 번호 (예: `1` → `CQ_1`)

예: `/mapping-design ontology/projects/industry_safety/resources/cq.md 1`

---

## 설계 원칙

### 1. 먼저 생각하라 (Think Before Building)

가정하지 말 것. 혼란을 숨기지 말 것. 트레이드오프를 드러낼 것.

구현 전에:
- CQ에서 필요한 트리플 패턴을 먼저 나열한다. 어떤 RDB 테이블·컬럼이 어떤 클래스·프로퍼티에 매핑되는지 명시한다.
- DB 테이블 구조가 TBox 클래스 구조와 불일치할 때 (예: role 컬럼으로 분기), View가 필요한지 직접 JOIN으로 해결 가능한지 판단한다.
- NULL 가능 컬럼이 있으면 트리플 생략(rr:optional) vs 빈 리터럴 중 선택 근거를 명시한다.
- 불확실한 것이 있으면 멈춘다. 무엇이 혼란스러운지 명시하고 묻는다.

### 2. 단순함 우선 (Simplicity First)

문제를 푸는 최소한의 매핑. 추측성 TriplesMap 금지.

- CQ를 답하는 데 필요한 트리플을 생성하는 TriplesMap만 작성한다.
- 미래 CQ를 위해 미리 TriplesMap을 추가하지 않는다.
- 단순한 INNER JOIN으로 해결 가능하면 View를 만들지 않는다.
- rr:logicalTable에 SQL 쿼리를 직접 쓸 수 있으면 별도 View를 만들지 않는다.
- 자문한다: "이 TriplesMap이 없으면 SHACL 검증이 실패하는가?" — 아니라면 삭제한다.

### 3. 외과적 수정 (Surgical Changes)

건드려야 할 것만 건드린다. 자신이 만든 문제만 치운다.

기존 매핑 파일을 읽을 때:
- IRI 템플릿 패턴·네이밍 관례를 파악하되, 기존 파일을 수정하지 않는다.
- 기존 View(rdb/scripts/)가 재사용 가능하면 새 View를 만들지 않는다.

config.ini 수정 시:
- 새 매핑 파일 섹션만 추가한다. 기존 섹션을 변경하지 않는다.

### 4. 목표 기반 실행 (Goal-Driven Execution)

성공 기준을 정의하고, 검증될 때까지 반복한다.

이 스킬의 성공 기준:
1. R2RML 파일 작성 → 검증: Turtle 문법 오류 없음
2. config.ini 갱신 → 검증: 새 매핑 섹션 포함
3. morph-kgc 실행 → 검증: ABox 파일 생성, 예상 트리플 포함

morph-kgc 실패 시:
- 오류 메시지를 읽고 원인을 분석한다 (SQL 오류 vs R2RML 오류 구분).
- 수정 후 재실행한다.
- 2회 실패 시 멈추고 사용자에게 오류 내용을 보고한다.

---

## 실행 절차

### 1단계 — 컨텍스트 읽기

- `[cq_file]` 전체를 읽어 `CQ_[cq_n]`의 검증 대상·예상 데이터를 확인한다.
- `ontology/projects/industry_safety/schema/cq_[cq_n].ttl` — 생성할 트리플의 클래스·프로퍼티.
- `ontology/projects/industry_safety/.env` — `DB_URL` 확인.
- **RDB 스키마 파악** — DB에 접속해 `schema_check.sql`로 현재 스키마 조회:
  ```bash
  docker exec -i rdb-db-1 psql -U [user] -d [db] < rdb/scripts/schema_check.sql
  ```
  DB 미접속 시: 사용자에게 스키마 정보(DDL 또는 테이블·컬럼 목록)를 요청한다.
- `rdb/scripts/` 아래 View SQL 파일들 — 재사용 가능한 View 파악.
- `ontology/projects/industry_safety/abox/r2rml/` — 기존 매핑 패턴 파악.

### 2단계 — 설계 결정 명시

파일 작성 전에 다음을 서술한다:

```
[설계 결정]
- 필요한 트리플 패턴:
    <factory/{id}> a is:사업장
    <factory/{id}> is:고용하다 <person/{id}>
    ...
- TriplesMap 목록: [이름 | 소스(테이블/View/SQL) | 생성 트리플]
- 신규 View 필요 여부: [필요 / 불필요 + 이유]
- Named Graph IRI: http://infiniq.co.kr/2026/industry_safety/cq_[n].abox
- NULL 컬럼 처리: [해당 컬럼 | 처리 방식]
- 불확실한 사항: [있으면 명시, 없으면 "없음"]
```

불확실한 사항이 있으면 이 시점에 사용자에게 묻는다. 임의로 선택하지 않는다.

### 3단계 — DB View 작성 (필요 시)

`rdb/scripts/cq_[n]_*.sql`에 필요한 View를 작성한다.

```sql
CREATE OR REPLACE VIEW v_... AS
SELECT ...
FROM ...
WHERE ...;
```

View가 불필요하면 이 단계를 건너뛴다.

### 4단계 — R2RML 파일 작성

`ontology/projects/industry_safety/abox/r2rml/cq_[cq_n].abox.rr.ttl` 생성.

```turtle
@prefix rr: <http://www.w3.org/ns/r2rml#> .
@prefix is: <http://infiniq.co.kr/2026/industry_safety#> .

<#[MapName]> a rr:TriplesMap ;
    rr:logicalTable [ rr:tableName "[table_or_view]" ] ;
    rr:subjectMap [
        rr:template "http://infiniq.co.kr/2026/industry_safety#[table]/{[pk]}" ;
        rr:class is:[클래스] ;
        rr:graphMap [ rr:constant <http://infiniq.co.kr/2026/industry_safety/cq_[n].abox> ]
    ] .
```

**관례**:
- IRI 템플릿: `http://infiniq.co.kr/2026/industry_safety#[table]/{[pk]}`
- Named Graph: `rr:constant <http://infiniq.co.kr/2026/industry_safety/cq_[n].abox>`
- 관계 트리플은 별도 TriplesMap으로 분리 (subjectMap + predicateObjectMap)

### 5단계 — config.ini 재생성

R2RML 파일 추가 후 `gen_config.sh`로 config.ini를 자동 재생성한다.

```bash
bash ontology/scripts/gen_config.sh industry_safety
```

`r2rml/*.rr.ttl`을 전부 스캔해서 config.ini를 덮어쓴다. 수동 편집 불필요.

### 6단계 — morph-kgc 실행 검증

```bash
conda run -n onto python3 -m morph_kgc ontology/projects/industry_safety/abox/config.ini
```

- 성공: 생성된 ABox 파일에서 예상 트리플 샘플 확인
- 실패: 오류 분석 → 수정 → 재실행 (최대 2회)
- DB 미연결 시: R2RML Turtle 문법만 검증하고 명시

### 7단계 — 검토 요청

```
=== 매핑 설계 완료 — Human Review ===

파일: ontology/projects/industry_safety/abox/r2rml/cq_[cq_n].abox.rr.ttl
morph-kgc: [PASS (N 트리플 생성) | DB 미연결 (TTL 문법만 확인)]
Named Graph: http://infiniq.co.kr/2026/industry_safety/cq_[n].abox

TriplesMap 요약:
  [이름] | [소스] | [생성 트리플 패턴]
  ...

신규 View: [파일명 | 없음]

검토 항목:
□ CQ에 필요한 트리플 패턴이 모두 커버되는가?
□ IRI 템플릿이 유일성을 보장하는가?
□ Named Graph IRI가 올바른가?
□ NULL/예외 케이스 처리가 명시되어 있는가?
□ config.ini가 gen_config.sh로 재생성되었는가?

승인 후 /abox-build [cq_file] [cq_n] 으로 다음 단계 진행.
```
