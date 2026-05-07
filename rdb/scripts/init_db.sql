create table Factory (
    id  serial  primary key,
    name varchar(100)
) ;

create table Role (
    id  serial  primary key,
    name varchar(100)
) ;

create table Person (
    id  serial  primary key,
    name varchar(100),
    factory integer references Factory(id),
    role integer references Role(id)
) ;

insert into factory (name) values ('A공장') ;
insert into factory (name) values ('B공장') ;
insert into factory (name) values ('C공장') ;
insert into role (name) values ('상시근로자') ;
insert into role (name) values ('안전관리자') ;


-- A 공장 근로자 생성 (안전관리자 포함.)

insert into person (name, factory, role)
select
    'A근로자' || gs,
    (select id from factory where name = 'A공장'),
    (select id from role where name = '상시근로자')
from generate_series(1, 51) as gs;

insert into person (name, factory, role) values (
    '김준호',
    (select id from factory where name = 'A공장'),
    (select id from role where name = '안전관리자')
);

-- B 공장 근로자 생성 (안전관리자 미포함.)

insert into person (name, factory, role)
select
    'B근로자' || gs,
    (select id from factory where name = 'B공장'),
    (select id from role where name = '상시근로자')
from generate_series(1, 51) as gs;

-- C 공장 근로자 생성 (50명 미만.)

insert into person (name, factory, role)
select
    'C근로자' || gs,
    (select id from factory where name = 'C공장'),
    (select id from role where name = '상시근로자')
from generate_series(1, 11) as gs;