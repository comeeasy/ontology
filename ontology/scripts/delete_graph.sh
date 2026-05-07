#! /bin/bash

USER=admin
PASSWD=admin
ENDPOINT=http://localhost:3030/industry_safety
GRAPH=http://infiniq.co.kr/2026/industry_safety/r1.abox

curl -v -X DELETE -u admin:admin "$ENDPOINT/data?graph=$GRAPH"