select
    person.id,
    person.name,
    factory.id as factory_id,
    factory.name as factory_name,
    role.name as role_name
from person
join factory on person.factory = factory.id
join role on person.role = role.id
