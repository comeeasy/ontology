#!/usr/bin/env bash
set -euo pipefail

# 단일 RDF 파일을 Fuseki Graph Store HTTP 로 업로드한다.
#
# - .ttl  → PUT  + ?graph=<GRAPH_ROOT>/<dataset>/<stem> , Content-Type: text/turtle
# - .nq   → POST + graph 파라미터 없음(쿼드 네 번째 칸 그래프 유지), Content-Type: application/n-quads
#
# 그래프 IRI (TTL 전용): http://infiniq.co.kr/2026/<dataset>/<파일 stem>
#
# 사용법:
#   bash ontology/scripts/upload_fuseki.sh <file.ttl|file.nq> <dataset>
#
# 환경변수(선택): FUSEKI_ENDPOINT, FUSEKI_ID, FUSEKI_PASSWORD

GRAPH_ROOT="http://infiniq.co.kr/2026"

FUSEKI_ID="${FUSEKI_ID:-admin}"
FUSEKI_PASSWORD="${FUSEKI_PASSWORD:-admin}"
FUSEKI_ENDPOINT="${FUSEKI_ENDPOINT:-http://localhost:3030}"

usage() {
  echo "Usage: $0 <file.ttl|file.nq> <dataset>" >&2
  echo "  TTL example: $0 ontology/abox/r1.abox.ttl industry_safety" >&2
  echo "               → graph ${GRAPH_ROOT}/<dataset>/r1.abox (PUT)" >&2
  echo "  NQ example:  $0 output/kg.nq industry_safety" >&2
  echo "               → quads keep embedded graph IRIs (POST, no graph=)" >&2
  exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
fi

if [ "$#" -ne 2 ]; then
  usage
fi

RDF_FILE="$1"
FUSEKI_DATASET="$2"

if [ ! -f "$RDF_FILE" ]; then
  echo "Error: file not found: $RDF_FILE" >&2
  exit 1
fi

EXT="${RDF_FILE##*.}"
EXT_LOWER=$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')
STEM=$(basename "$RDF_FILE")
STEM="${STEM%.*}"

BASE_URL="${FUSEKI_ENDPOINT}/${FUSEKI_DATASET}/data"

case "$EXT_LOWER" in
  ttl)
    GRAPH_IRI="${GRAPH_ROOT}/${FUSEKI_DATASET}/${STEM}"
    echo "Uploading ${RDF_FILE} → PUT graph <${GRAPH_IRI}> (dataset ${FUSEKI_DATASET})"
    curl -s -S -f -X PUT \
      -u "${FUSEKI_ID}:${FUSEKI_PASSWORD}" \
      -H "Content-Type: text/turtle; charset=utf-8" \
      --data-binary @"${RDF_FILE}" \
      "${BASE_URL}?graph=${GRAPH_IRI}"
    ;;
  nq)
    echo "Uploading ${RDF_FILE} → POST ${BASE_URL} (application/n-quads, graphs from file)"
    curl -s -S -f -X POST \
      -u "${FUSEKI_ID}:${FUSEKI_PASSWORD}" \
      -H "Content-Type: application/n-quads" \
      --data-binary @"${RDF_FILE}" \
      "${BASE_URL}"
    ;;
  *)
    echo "Error: unsupported extension '.${EXT}'. Use .ttl or .nq" >&2
    exit 1
    ;;
esac

echo ""
echo "Done."
