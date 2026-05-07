#!/usr/bin/env bash
set -euo pipefail

# Morph-KGC 등에서 나온 N-Triples(.nt) / N-Quads(.nq) 등을 Apache Jena riot 으로 Turtle 등으로 변환한다.
# Docker 이미지 기본: stain/jena (riot 포함). Fuseki 이미지(stain/jena-fuseki)에는 riot 가 없음.
#
# 사용법:
#   bash ontology/scripts/nt_to_ttl.sh 입력.nt [출력.ttl]
#
# 환경변수:
#   JENA_RIOT_IMAGE   기본 stain/jena:5.1.0
#   RDF_OUTPUT_FORMAT riot --output 값 (기본 TURTLE). N-QUADS 원본에 그래프가 있으면 TRIG 가 적합할 수 있음.

IMAGE="${JENA_RIOT_IMAGE:-stain/jena:5.1.0}"
FMT="${RDF_OUTPUT_FORMAT:-TURTLE}"

usage() {
  echo "Usage: $0 input.nt|nq [output.ttl]" >&2
  exit 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
fi

INPUT=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
if [ ! -f "$INPUT" ]; then
  echo "Error: file not found: $INPUT" >&2
  exit 1
fi

if [ -n "${2:-}" ]; then
  OUT_DIR=$(dirname "$2")
  mkdir -p "$OUT_DIR"
  OUTPUT="$(cd "$OUT_DIR" && pwd)/$(basename "$2")"
else
  base="${INPUT%.*}"
  OUTPUT="${base}.ttl"
fi

INDIR=$(dirname "$INPUT")
INNAME=$(basename "$INPUT")

docker run --rm \
  --entrypoint=/jena/bin/riot \
  -v "${INDIR}:/data:ro" \
  "${IMAGE}" \
  --output="${FMT}" \
  "/data/${INNAME}" \
  > "${OUTPUT}"

echo "Wrote ${OUTPUT}"
