-- 스키마 점검용 (public). 진짜 테이블(BASE TABLE)과 VIEW 등을 구분한다.
--
-- 실행 예:
--   docker exec -i rdb-db-1 psql -U joono -d industry_safety < rdb/scripts/schema_check.sql

-- === public 객체 목록 (종류 구분) ===
-- table_type: BASE TABLE | VIEW | FOREIGN TABLE 등
SELECT table_schema,
       table_name,
       table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;

-- === 컬럼 (소속 객체가 테이블인지 뷰인지 표시) ===
SELECT t.table_type,
       c.table_name,
       c.column_name,
       c.data_type,
       c.is_nullable,
       c.column_default
FROM information_schema.columns AS c
JOIN information_schema.tables AS t
  ON c.table_schema = t.table_schema
 AND c.table_name = t.table_name
WHERE c.table_schema = 'public'
ORDER BY t.table_type, c.table_name, c.ordinal_position;

-- === 외래키 (보통 BASE TABLE 에만 정의; VIEW 는 제외) ===
SELECT t.table_type,
       tc.table_name,
       kcu.column_name,
       ccu.table_name AS foreign_table_name,
       ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.tables AS t
  ON tc.table_schema = t.table_schema
 AND tc.table_name = t.table_name
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
ORDER BY tc.table_name, kcu.ordinal_position;