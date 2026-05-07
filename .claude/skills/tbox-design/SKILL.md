# /tbox-design

**schema_ingest 2단계**: 단일 CQ에 대한 TBox(OWL 2 DL)를 설계한다.

## 입력

`/tbox-design [cq_id]`  예: `/tbox-design cq_2`

## 실행 절차

1. **컨텍스트 읽기**
   - `ontology/projects/industry_safety/resources/cq.md` — 대상 CQ 내용 확인
   - `ontology/projects/industry_safety/schema/` — 기존 TBox 파일 전체 (재사용 가능한 클래스·프로퍼티 파악)

2. **설계 원칙**
   - **최소성**: 해당 CQ를 답하는 데 필요한 클래스·프로퍼티만 정의한다. 과도 모델링 금지.
   - **재사용**: 기존 TBox에 이미 정의된 클래스·프로퍼티는 `owl:imports`로 가져와 재사용한다.
   - **OWL 2 DL**: `owl:Thing`의 직접 서브클래스, object/data property 구분, 도메인·레인지 명시.
   - **네이밍**: 도메인 용어 그대로 사용 (영문 transliteration 또는 한국어 URI 모두 허용, 기존 파일 관례 따름).

3. **파일 작성** — `ontology/projects/industry_safety/schema/[cq_id].ttl` 생성

4. **ROBOT 검증** — 작성 후 즉시 실행:
   ```bash
   bash ontology/scripts/reason.sh
   ```
   오류 발생 시 원인을 분석하고 파일을 수정한 뒤 재실행한다. 통과할 때까지 반복.

5. **검토 요청** — 통과 후 아래를 출력한다:

```
=== TBox 설계 완료 — Human Review ===

파일: ontology/projects/industry_safety/schema/[cq_id].ttl
ROBOT: PASS

정의된 클래스: [목록]
정의된 프로퍼티: [목록]
재사용한 클래스/프로퍼티: [목록 (출처 파일)]

검토 항목:
□ 이 CQ에만 필요한 최소 클래스·프로퍼티만 있는가?
□ 도메인 용어와 네이밍이 일치하는가?
□ 기존 TBox와 충돌·중복이 없는가?
□ ROBOT 경고 중 무시 불가한 항목이 있는가?

승인 후 /shacl-design [cq_id] 으로 다음 단계 진행.
```
