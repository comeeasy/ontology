#!/bin/bash
# Usage:
#   bash ontology/scripts/upload.sh                        # schema/ 전체 (TTL)
#   bash ontology/scripts/upload.sh path/to/file.ttl      # 특정 TTL 파일
#   bash ontology/scripts/upload.sh path/to/file.nq       # N-Quads (named graph 보존, POST)

FUSEKI_ID=${FUSEKI_ID:-admin}
FUSEKI_PASSWORD=${FUSEKI_PASSWORD:-admin}
FUSEKI_ENDPOINT=${FUSEKI_ENDPOINT:-http://localhost:3030}

if [ -n "$1" ]; then
    FILES="$1"
else
    FILES=$(find ontology/projects -path "*/schema/*.ttl")
fi

for FILE in $FILES; do
    PROJECT=$(echo "$FILE" | sed 's|.*ontology/projects/\([^/]*\)/.*|\1|')
    ENV_FILE="ontology/projects/$PROJECT/.env"

    if [ -f "$ENV_FILE" ]; then
        # shellcheck source=/dev/null
        source "$ENV_FILE"
    else
        echo "WARNING: $ENV_FILE not found, skipping $FILE"
        continue
    fi

    EXT="${FILE##*.}"

    if [ "$EXT" = "nq" ]; then
        # N-Quads: named graph이 파일 내 포함 → POST /data (graph 지정 없음)
        echo "Uploading $FILE (N-Quads, named graphs preserved)"
        curl -s -X POST \
            -u "$FUSEKI_ID:$FUSEKI_PASSWORD" \
            -H "Content-Type: application/n-quads" \
            --data-binary @"$FILE" \
            "$FUSEKI_ENDPOINT/$FUSEKI_DATASET/data"
    else
        # TTL: 파일명 기반 named graph → PUT ?graph=
        FILENAME=$(basename "$FILE" .ttl)
        GRAPH_IRI="$BASE_IRI/$FILENAME"
        echo "Uploading $FILE → $GRAPH_IRI"
        curl -s -X PUT \
            -u "$FUSEKI_ID:$FUSEKI_PASSWORD" \
            -H "Content-Type: text/turtle" \
            --data-binary @"$FILE" \
            "$FUSEKI_ENDPOINT/$FUSEKI_DATASET/data?graph=$GRAPH_IRI"
    fi
    echo ""
done
