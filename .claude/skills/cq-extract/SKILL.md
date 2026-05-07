# /cq-extract

**schema_ingest 1단계**: domain wiki를 읽고 Competency Questions를 도출한다.
반드시 `/doc-wiki`로 wiki를 먼저 생성한 후 실행한다.

## 입력

`/cq-extract [wiki경로]`

- wiki경로 생략 시 `ontology/projects/industry_safety/resources/wiki/` 내 파일을 자동 탐색
- 기존 `cq.md`가 있으면 읽어 현재 CQ 목록 파악 (중복 방지)

## 실행 절차

1. **wiki 읽기** — 대상 wiki 파일 전체를 읽는다.

2. **CQ 도출 기준** — wiki의 "의무 조항" 섹션을 기반으로, 아래 조건을 모두 만족하는 항목만 CQ로 선정한다:
   - "예/아니오"로 답할 수 있는 형태로 변환 가능
   - 대응하는 데이터(DB 컬럼·RDB 테이블)가 존재하거나 존재할 가능성이 높음
   - wiki의 "검증 불가 조항"에 포함되지 않음

3. **CQ 작성** — `ontology/projects/industry_safety/resources/cq.md`에 아래 포맷으로 작성한다.
   n은 기존 CQ 이후 번호로 이어간다.

```markdown
## CQ_n: [질문 — "~인가?" 형태]

- **근거 조항**: 제X조 제Y항
- **wiki 엔티티**: [사용할 엔티티 목록]
- **준수 조건**: [구체적 조건 서술]
- **검증 대상**: [어떤 엔티티를 검사하는가]
- **예상 데이터**: [필요한 DB 테이블·컬럼]
- **경계 케이스**: [임계값, 예외 조건 등]
```

4. **검토 요청** — 작성 완료 후 아래를 출력한다:

```
=== CQ 도출 완료 — Human Review ===

신규 CQ: [목록]

제외 조항: [wiki "검증 불가" 항목 + 제외 사유]

검토 항목:
□ 각 CQ가 "예/아니오"로 답 가능한 형태인가?
□ "예상 데이터"가 실제 DB에 존재하는가?
□ 제외 조항 분류가 타당한가?
□ wiki 엔티티와 CQ 검증 대상이 일치하는가?

승인 후 /tbox-design cq_n 으로 다음 단계 진행.
```
