# /shacl-design

**schema_ingest 3단계**: TBox를 기반으로 SHACL Shape을 작성하고 검증한다.

## 입력

`/shacl-design [cq_id]`  예: `/shacl-design cq_2`

## 실행 절차

1. **컨텍스트 읽기**
   - `ontology/projects/industry_safety/resources/cq.md` — 대상 CQ의 준수 조건·경계 케이스
   - `ontology/projects/industry_safety/schema/[cq_id].ttl` — 사용할 클래스·프로퍼티
   - `ontology/projects/industry_safety/shapes/` — 기존 SHACL 파일 (패턴 참고)

2. **SHACL 작성 원칙**
   - `sh:SPARQLConstraint` 또는 `sh:property` 중 CQ 표현에 적합한 방식 선택
   - `sh:select` 내부에는 반드시 `PREFIX` 선언 포함 (TTL prefix 상속 안 됨)
   - `sh:message`: 도메인 전문가가 읽을 수 있는 한국어, 위반 내용과 근거 조항 명시
   - 경계 케이스(임계값 등)를 조건에 명시적으로 반영

3. **파일 작성** — `ontology/projects/industry_safety/shapes/[cq_id].shacl.ttl` 생성

4. **pyshacl 검증** — 기존 테스트 ABox(`abox/cq_1.abox.nq`)로 동작 확인:
   ```bash
   pyshacl \
     -s ontology/projects/industry_safety/shapes/[cq_id].shacl.ttl \
     -d ontology/projects/industry_safety/abox/cq_1.abox.nq
   ```
   적합한 테스트 ABox가 없으면 인라인 Turtle로 최소 테스트 데이터를 만들어 검증한다.

5. **검토 요청** — 아래를 출력한다:

```
=== SHACL 설계 완료 — Human Review ===

파일: ontology/projects/industry_safety/shapes/[cq_id].shacl.ttl

pyshacl 테스트 결과:
  PASS 케이스: [예상 PASS → 실제 결과]
  FAIL 케이스: [예상 FAIL → 실제 결과]

검토 항목:
□ sh:select/sh:property 조건이 CQ 의도를 정확히 구현하는가?
□ 경계 케이스(임계값 등)가 조건에 반영되어 있는가?
□ sh:message가 도메인 전문가가 이해할 수 있는 한국어인가?
□ PREFIX 선언이 sh:select 내부에 포함되어 있는가?
□ PASS/FAIL 예상 케이스가 모두 올바른가?

승인 후 /mapping-design [cq_id] 으로 다음 단계 진행.
```
