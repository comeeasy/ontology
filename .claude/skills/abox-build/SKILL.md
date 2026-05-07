# /abox-build

**data_ingest 2단계**: morph-kgc로 ABox를 생성하고 SHACL로 검증한다.

## 입력

`/abox-build [cq_id]`  예: `/abox-build cq_2`

## 사전 조건 확인

실행 전 자동으로 확인:
```bash
docker ps --filter "name=rdb" --format "{{.Status}}"   # PostgreSQL 실행 여부
curl -s -o /dev/null -w "%{http_code}" http://localhost:3030   # Fuseki 실행 여부
```
미실행 상태면 중단하고 사용자에게 알린다.

## 실행 절차

1. **morph-kgc 실행**
   ```bash
   python -m morph_kgc ontology/projects/industry_safety/abox/config.ini
   ```
   오류 발생 시 원인 분석 후 config.ini 또는 R2RML 파일 수정하고 재시도.

2. **생성 결과 확인**
   ```bash
   # 생성된 트리플 수 확인
   grep -c "^" ontology/projects/industry_safety/abox/[cq_id].abox.nq
   ```

3. **Fuseki 업로드**
   ```bash
   curl -u admin:admin -X PUT \
     -H "Content-Type: application/n-quads" \
     --data-binary @ontology/projects/industry_safety/abox/[cq_id].abox.nq \
     "http://localhost:3030/industry_safety/data?graph=http://infiniq.co.kr/2026/industry_safety/[cq_id].abox"
   ```

4. **SHACL 검증**
   ```bash
   pyshacl \
     -s ontology/projects/industry_safety/shapes/[cq_id].shacl.ttl \
     -d ontology/projects/industry_safety/abox/[cq_id].abox.nq
   ```

5. **검토 요청** — 아래를 출력한다:

```
=== ABox 생성 완료 — Human Review ===

파일: ontology/projects/industry_safety/abox/[cq_id].abox.nq
생성 트리플 수: [N]

SHACL 검증 결과:
  Conforms: [True/False]
  위반 노드: [URI 목록 또는 "없음"]

예상 결과 대조:
  PASS 예상 → [실제]: [일치/불일치]
  FAIL 예상 → [실제]: [일치/불일치]

검토 항목:
□ 생성 트리플 수가 예상 범위인가?
□ SHACL 결과가 예상 PASS/FAIL과 일치하는가?
□ 데이터 변환 오류·손실이 없는가?
□ Named Graph IRI가 Fuseki에 올바르게 적재되었는가?

파이프라인 완료.
```
