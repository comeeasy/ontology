# /mapping-design

**data_ingest 1단계**: CQ와 데이터 스키마를 분석하여 R2RML 매핑을 작성한다.

## 입력

`/mapping-design [cq_id]`  예: `/mapping-design cq_2`

데이터 스키마는 다음 중 하나로 제공한다:
- `rdb/scripts/init_db.sql` (DDL 자동 읽기)
- 대화에서 직접 붙여넣기

## 실행 절차

1. **컨텍스트 읽기**
   - `ontology/projects/industry_safety/resources/cq.md` — CQ의 검증 대상·예상 데이터
   - `ontology/projects/industry_safety/schema/[cq_id].ttl` — 생성할 트리플의 클래스·프로퍼티
   - `rdb/scripts/init_db.sql` — 테이블 구조·컬럼·타입 파악
   - `ontology/projects/industry_safety/abox/r2rml/cq_1.abox.rr.ttl` — 기존 매핑 파일 참고

2. **매핑 설계 원칙**
   - CQ를 답하는 데 필요한 트리플을 모두 생성할 것
   - IRI 템플릿: `{테이블명}/{pk컬럼}` 패턴으로 유일성 보장
   - Named Graph: `rr:graphMap [ rr:template "http://infiniq.co.kr/2026/industry_safety/{cq_id}.abox" ]`
   - NULL 가능 컬럼은 `rr:termType rr:Literal ; rr:language "ko"` 등 명시적 처리
   - 필요 시 DB VIEW를 `rdb/scripts/`에 추가하고 매핑에서 참조

3. **파일 작성**
   - `ontology/projects/industry_safety/abox/r2rml/[cq_id].abox.rr.ttl` — R2RML 매핑
   - `ontology/projects/industry_safety/abox/config.ini` 갱신 — 새 매핑 파일 경로 추가

4. **검토 요청** — 아래를 출력한다:

```
=== 매핑 설계 완료 — Human Review ===

파일: ontology/projects/industry_safety/abox/r2rml/[cq_id].abox.rr.ttl

TriplesMap 요약:
  [TriplesMap명] | [소스] | [생성 트리플 패턴]
  ...

검토 항목:
□ CQ에 필요한 트리플이 모두 커버되는가?
□ IRI 템플릿이 유일성을 보장하는가?
□ Named Graph IRI가 올바른가?
□ NULL/예외 케이스 처리가 명시되어 있는가?
□ 새로 추가한 DB VIEW가 있다면 의미가 올바른가?

승인 후 /abox-build [cq_id] 으로 다음 단계 진행.
```
