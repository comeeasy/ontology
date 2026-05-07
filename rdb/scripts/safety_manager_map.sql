CREATE VIEW v_safety_manager_map AS
SELECT
    factory.id AS factory_id,
    factory.name as factory_name,
    person.id AS person_id,
    person.name as person_name
FROM person 
JOIN factory ON factory.id = person.factory
WHERE person.role = 2;