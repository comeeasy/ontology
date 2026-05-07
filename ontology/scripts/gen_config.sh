#!/bin/bash
# config.ini 자동 생성 — .env + r2rml/*.rr.ttl → abox/config.ini
# Usage:
#   bash ontology/scripts/gen_config.sh                    # 모든 프로젝트
#   bash ontology/scripts/gen_config.sh industry_safety    # 특정 프로젝트

if [ -n "$1" ]; then
    PROJECTS="$1"
else
    PROJECTS=$(ls ontology/projects/)
fi

for PROJECT in $PROJECTS; do
    ENV_FILE="ontology/projects/$PROJECT/.env"
    if [ ! -f "$ENV_FILE" ]; then
        continue
    fi

    # shellcheck source=/dev/null
    source "$ENV_FILE"

    RRMLL_DIR="ontology/projects/$PROJECT/abox/r2rml"
    CONFIG_FILE="ontology/projects/$PROJECT/abox/config.ini"
    OUTPUT_FILE="ontology/projects/$PROJECT/abox/output.nq"

    if [ ! -d "$RRMLL_DIR" ]; then
        echo "WARNING: $RRMLL_DIR not found, skipping $PROJECT"
        continue
    fi

    MAPPINGS=$(find "$RRMLL_DIR" -name "*.rr.ttl" | sort | tr '\n' ',' | sed 's/,$//')

    if [ -z "$MAPPINGS" ]; then
        echo "WARNING: No *.rr.ttl files in $RRMLL_DIR, skipping $PROJECT"
        continue
    fi

    cat > "$CONFIG_FILE" <<EOF
[CONFIGURATION]
output_file: $OUTPUT_FILE
output_format: N-QUADS

[DataSource1]
mappings: $MAPPINGS
db_url: $DB_URL
EOF

    COUNT=$(find "$RRMLL_DIR" -name "*.rr.ttl" | wc -l | tr -d ' ')
    echo "Generated $CONFIG_FILE ($COUNT mappings)"
done
