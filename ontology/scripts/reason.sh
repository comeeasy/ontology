#!/bin/bash
# Usage:
#   bash ontology/scripts/reason.sh                      # schema/ 전체
#   bash ontology/scripts/reason.sh path/to/file.ttl    # 특정 파일만

ODK_IMAGE=${ODK_IMAGE:-obolibrary/odkfull}

if [ -n "$1" ]; then
    TTL_FILES="$1"
else
    TTL_FILES=$(find ontology/projects -path "*/schema/*.ttl")
fi

for TTL_FILE in $TTL_FILES; do
    # 파일 경로에서 프로젝트명 추출 (ontology/projects/<project>/...)
    PROJECT=$(echo "$TTL_FILE" | sed 's|.*ontology/projects/\([^/]*\)/.*|\1|')
    ENV_FILE="ontology/projects/$PROJECT/.env"

    if [ -f "$ENV_FILE" ]; then
        # shellcheck source=/dev/null
        source "$ENV_FILE"
    else
        echo "WARNING: $ENV_FILE not found, skipping $TTL_FILE"
        continue
    fi

    REASONER=${REASONER:-hermit}

    echo "========================================"
    echo "▶ $TTL_FILE (reasoner: $REASONER)"
    echo "========================================"

    echo "[reason]"
    docker run --rm \
        -v "$(pwd):/work" \
        -w /work \
        "$ODK_IMAGE" \
        robot reason \
            --input "$TTL_FILE" \
            --reasoner "$REASONER"

    echo "[report]"
    docker run --rm \
        -v "$(pwd):/work" \
        -w /work \
        "$ODK_IMAGE" \
        robot report \
            --input "$TTL_FILE"

    echo ""
done
