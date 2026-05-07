#!/bin/bash

ONTOLOGY_DIR="ontology"
REASONER="hermit"
ODK_IMAGE="obolibrary/odkfull"

find "$ONTOLOGY_DIR" -name "*.ttl" | while read TTL_FILE; do
    echo "========================================"
    echo "▶ $TTL_FILE"
    echo "========================================"

    echo "[reason]"
    docker run --rm \
        -v "$(pwd):/work" \
        -w /work \
        "$ODK_IMAGE" \
        robot reason \
            --catalog "$ONTOLOGY_DIR/catalog-v001.xml" \
            --input "$TTL_FILE" \
            --reasoner $REASONER

    echo "[report]"
    docker run --rm \
        -v "$(pwd):/work" \
        -w /work \
        "$ODK_IMAGE" \
        robot report \
            --catalog "$ONTOLOGY_DIR/catalog-v001.xml" \
            --input "$TTL_FILE"

    echo ""
done
