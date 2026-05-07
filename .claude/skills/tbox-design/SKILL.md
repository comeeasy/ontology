# /tbox-design

**schema_ingest 2단계**: 단일 CQ에 대한 TBox(OWL 2 DL)를 설계한다.

## 입력

`/tbox-design [cq_file] [cq_n]`

- `cq_file`: CQ 목록 파일 경로 (예: `ontology/projects/industry_safety/resources/cq.md`)
- `cq_n`: 설계할 CQ 번호 (예: `1` → `CQ_1`)

예: `/tbox-design ontology/projects/industry_safety/resources/cq.md 1`

---

## 설계 원칙

### 1. 먼저 생각하라 (Think Before Building)

가정하지 말 것. 혼란을 숨기지 말 것. 트레이드오프를 드러낼 것.

구현 전에:
- 가정을 명시적으로 서술한다. 불확실하면 묻는다.
- 해석이 여러 가지이면 나열한다 — 조용히 하나를 선택하지 않는다.
- 더 단순한 모델링이 존재하면 말한다. 필요하면 반박한다.
- 불명확한 것이 있으면 멈춘다. 무엇이 혼란스러운지 명시하고 묻는다.

온톨로지 적용:
- CQ가 요구하는 정보가 단일 클래스로 표현 가능한지, 아니면 관계가 필요한지 먼저 판단한다.
- 동일 개념이 여러 이름으로 표현 가능할 때 (예: `사업장` vs `공장`) 선택 근거를 명시한다.
- 하위법령 위임 수치(ex. 50인, 6개월)를 TBox에 박을지 SHACL에서만 쓸지 결정하고 이유를 적는다.

### 2. 단순함 우선 (Simplicity First)

문제를 푸는 최소한의 온톨로지. 추측성 모델링 금지.

- 이 CQ를 답하는 데 필요한 클래스·프로퍼티만 정의한다.
- 미래에 쓸 것 같다는 이유로 클래스·프로퍼티를 추가하지 않는다.
- 유연성·확장성을 위한 중간 추상 클래스를 만들지 않는다.
- 도메인·레인지 선언에서 불필요한 상위 클래스(`owl:Thing`)를 쓰지 않는다.
- TTL이 30줄로 끝날 수 있으면 100줄로 쓰지 않는다.
- 자문한다: "온톨로지 전문가가 보면 과하다고 할까?" — 그렇다면 줄인다.

### 3. 외과적 수정 (Surgical Changes)

건드려야 할 것만 건드린다. 자신이 만든 문제만 치운다.

기존 TBox 파일을 읽을 때:
- 재사용 가능한 클래스·프로퍼티를 파악하되, 기존 파일을 수정하지 않는다.
- 기존 네이밍 관례와 IRI 패턴을 그대로 따른다.
- 관련 없는 클래스·프로퍼티를 "개선"하지 않는다.

새 파일에서:
- 새로 정의한 클래스·프로퍼티가 이 CQ에서 실제로 쓰이는지 확인한다.
- 쓰이지 않는 정의는 삭제한다.
- 기준: 파일의 모든 줄이 이 CQ와 직접 연결되어야 한다.

### 4. 목표 기반 실행 (Goal-Driven Execution)

성공 기준을 정의하고, 검증될 때까지 반복한다.

이 스킬의 성공 기준:
1. `[cq_id].ttl` 작성 → 검증: 파일 존재, Turtle 문법 오류 없음
2. ROBOT reason 실행 → 검증: `[reason] PASS`, 논리 모순 없음
3. CQ 매핑 확인 → 검증: CQ의 모든 엔티티가 클래스·프로퍼티로 표현됨

ROBOT 실패 시:
- 오류 메시지를 읽고 원인을 분석한다.
- 수정 후 재실행한다.
- 2회 실패 시 멈추고 사용자에게 오류 내용을 보고한다.

---

## 실행 절차

> **패치 재호출**: `/mapping-design`이 TBox 누락 프로퍼티를 발견해 되돌아온 경우,
> 기존 파일을 열어 해당 프로퍼티만 추가하고 `owl:versionInfo`를 마이너 버전 업(예: `1.0.0 → 1.1.0`)한다.
> 파일 전체를 재작성하지 않는다.

### 1단계 — 컨텍스트 읽기

- `[cq_file]` 전체를 읽어 `CQ_[cq_n]` 섹션을 찾는다.
- `ontology/projects/industry_safety/schema/` 아래 모든 `.ttl` 파일을 읽어 재사용 가능한 클래스·프로퍼티 목록을 파악한다.

### 2단계 — 설계 결정 명시

파일 작성 전에 다음을 서술한다:

```
[설계 결정]
- 새로 정의할 클래스: [목록 + 이유]
- 새로 정의할 프로퍼티: [목록 + 이유]
- 기존 TBox에서 재사용할 항목: [목록 + 출처 파일]
- 제외한 후보: [목록 + 제외 이유]
- 온톨로지 메타데이터: versionInfo=1.0.0, dcterms:created=[오늘 날짜], dcterms:source=[근거 법령 URL]
- 불확실한 사항: [있으면 명시, 없으면 "없음"]
```

불확실한 사항이 있으면 이 시점에 사용자에게 묻는다. 임의로 선택하지 않는다.

### 3단계 — 파일 작성

`ontology/projects/industry_safety/schema/cq_[cq_n].ttl` 생성.

**어노테이션 규칙:**
- `rdfs:label`: 한국어 단어 하나 (도메인 용어와 정확히 일치)
- `rdfs:comment`: "[법적·도메인 정의]. [이 CQ에서의 역할]. 근거: [조항]." 형식
- 온톨로지 블록의 `dcterms:created`는 파일 최초 생성일이며 이후 변경하지 않는다.
- `owl:versionInfo`는 `"1.0.0"` 으로 시작하며, 클래스/프로퍼티 구조 변경 시 마이너 버전을 올린다.

```turtle
@prefix is: <http://infiniq.co.kr/2026/industry_safety#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# Ontology metadata
<http://infiniq.co.kr/2026/industry_safety/cq_[n]> a owl:Ontology ;
    owl:versionInfo "1.0.0" ;
    dcterms:created "[YYYY-MM-DD]"^^xsd:date ;
    dcterms:source <[근거 법령 URL]> ;
    rdfs:label "[CQ 제목]"@ko .

# Classes
is:[클래스] a owl:Class ;
    rdfs:label "[한국어 레이블]"@ko ;
    rdfs:comment "[정의. 이 CQ에서의 역할. 근거: 제N조.]"@ko .

# Object Properties
is:[프로퍼티] a owl:ObjectProperty ;
    rdfs:domain is:[도메인] ;
    rdfs:range is:[레인지] ;
    rdfs:label "[한국어 레이블]"@ko ;
    rdfs:comment "[관계의 의미. 이 CQ에서의 역할. 근거: 제N조.]"@ko .

# Data Properties
...
```

### 4단계 — ROBOT 검증

```bash
bash ontology/scripts/reason.sh ontology/projects/industry_safety/schema/cq_[cq_n].ttl
```

- PASS: 다음 단계 진행
- FAIL: 오류 분석 → 수정 → 재실행 (최대 2회)
- 2회 실패 시: 멈추고 오류 내용 보고

### 5단계 — Fuseki 업로드

```bash
bash ontology/scripts/upload.sh ontology/projects/industry_safety/schema/cq_[cq_n].ttl
```

- **Dataset**: `industry_safety`
- **Graph IRI**: `http://infiniq.co.kr/2026/industry_safety/cq_[cq_n]`
- Fuseki가 실행 중이 아니면 (`Connection refused`) 경고만 출력하고 진행한다 — 업로드 실패는 블로커가 아니다.
- 업로드 성공 시: curl 응답에 오류 없음 확인

### 6단계 — 검토 요청

```
=== TBox 설계 완료 — Human Review ===

파일: ontology/projects/industry_safety/schema/cq_[cq_n].ttl
ROBOT: PASS
Fuseki: [UPLOADED | SKIPPED (서버 미실행)]
Graph: http://infiniq.co.kr/2026/industry_safety/cq_[cq_n]

새로 정의한 클래스: [목록]
새로 정의한 프로퍼티: [목록]
재사용한 항목: [목록 (출처 파일)]

검토 항목:
□ 이 CQ에만 필요한 최소 클래스·프로퍼티만 있는가?
□ 도메인 용어와 네이밍이 일치하는가?
□ 기존 TBox와 충돌·중복이 없는가?
□ ROBOT 경고 중 무시 불가한 항목이 있는가?

승인 후 /shacl-design [cq_file] [cq_n] 으로 다음 단계 진행.
```
