#!/usr/bin/env bash
set -eu
set -o pipefail

# Fuseki에서 지정한 Named Graph 들만 합쳐(CONSTRUCT) RDF 파일로 저장한다.
# (Windows에서 편집 시 CRLF 넣지 말 것 — WSL/Git Bash에서 `set: pipefail` 오류 남)

# 사용법:
#   bash ontology/industry_safety/scripts/create_kg.sh \
#     -e http://localhost:3030 \
#     -d industry_safety \
#     -o output/merged.ttl \
#     -g http://infiniq.co.kr/2026/industry_safety/r1 \
#     -g http://infiniq.co.kr/2026/industry_safety/r2
#
# 옵션:
#   -e   Fuseki 베이스 URL (데이터셋 경로 제외). 기본: http://localhost:3030 또는 환경변수 FUSEKI_ENDPOINT
#   -u   Basic 인증 사용자. 기본: admin 또는 FUSEKI_ID
#   -p   Basic 인증 비밀번호. 기본: admin 또는 FUSEKI_PASSWORD
#   -d   데이터셋 이름 (필수)
#   -o   결과 저장 경로 (필수)
#   -g   Named Graph IRI (한 번 이상 반복)
#   -f   Accept 헤더 (결과 직렬화). 기본: text/turtle
#   -h   도움말

usage() {
  cat >&2 <<'EOF'
Fuseki Named Graph 합치기 → RDF 파일 저장

Usage:
  bash ontology/industry_safety/scripts/create_kg.sh \
    -e http://localhost:3030 \
    -d <dataset> \
    -o <output_path> \
    -g <graph_IRI> [-g <graph_IRI> ...]

Options:
  -e  Fuseki base URL (no /dataset). Default: env FUSEKI_ENDPOINT or http://localhost:3030
  -u  Basic user. Default: env FUSEKI_ID or admin
  -p  Basic password. Default: env FUSEKI_PASSWORD or admin
  -d  Dataset name (required)
  -o  Output file path (required)
  -g  Named graph IRI (repeatable, required ≥1)
  -f  Accept header / RDF format. Default: text/turtle
  -h  Help

Example:
  bash ontology/industry_safety/scripts/create_kg.sh \
    -d industry_safety -o out/merged.ttl \
    -g http://infiniq.co.kr/2026/industry_safety/r1 \
    -g http://infiniq.co.kr/2026/industry_safety/r1.abox
EOF
  exit 1
}

ENDPOINT="${FUSEKI_ENDPOINT:-http://localhost:3030}"
USER="${FUSEKI_ID:-admin}"
PASS="${FUSEKI_PASSWORD:-admin}"
DATASET=""
OUTPUT=""
ACCEPT="text/turtle"
GRAPHS=()

while getopts "e:u:p:d:o:g:f:h" opt; do
  case "$opt" in
    e) ENDPOINT="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    d) DATASET="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    g) GRAPHS+=("$OPTARG") ;;
    f) ACCEPT="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "${DATASET}" || -z "${OUTPUT}" || ${#GRAPHS[@]} -eq 0 ]]; then
  echo "Error: -d, -o, and at least one -g are required." >&2
  usage
fi

ENDPOINT="${ENDPOINT%/}"
SPARQL_URL="${ENDPOINT}/${DATASET}/sparql"

TMP="$(mktemp "${TMPDIR:-/tmp}/create_kg.XXXXXX.sparql")"
cleanup() { rm -f "${TMP}"; }
trap cleanup EXIT

{
  echo "CONSTRUCT { ?s ?p ?o }"
  echo "WHERE {"
  for i in "${!GRAPHS[@]}"; do
    if [[ "${i}" -gt 0 ]]; then
      echo "  UNION"
    fi
    echo "  { GRAPH <${GRAPHS[$i]}> { ?s ?p ?o } }"
  done
  echo "}"
} >"${TMP}"

OUT_DIR="$(dirname "${OUTPUT}")"
mkdir -p "${OUT_DIR}"

echo "POST ${SPARQL_URL}"
echo "Graphs: $(printf '%s ' "${GRAPHS[@]}")"
echo "→ ${OUTPUT}"

curl -s -S -f \
  -u "${USER}:${PASS}" \
  -H "Accept: ${ACCEPT}" \
  -H "Content-Type: application/sparql-query; charset=utf-8" \
  --data-binary @"${TMP}" \
  -X POST \
  "${SPARQL_URL}" \
  -o "${OUTPUT}"

echo "Done."
