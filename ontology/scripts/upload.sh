FUSEKI_ID=admin
FUSEKI_PASSWORD=admin
FUSEKI_ENDPOINT=http://localhost:3030
FUSEKI_DATASET=industry_safety
BASE_IRI=http://infiniq.co.kr/2026/industry_safety

for TTL_FILE in $(find ontology -name "*.ttl"); do
    FILENAME=$(basename "$TTL_FILE" .ttl)
    GRAPH_IRI="$BASE_IRI/$FILENAME"
    echo "Uploading $TTL_FILE → $GRAPH_IRI"
    curl -s -X PUT \
        -u $FUSEKI_ID:$FUSEKI_PASSWORD \
        -H "Content-Type: text/turtle" \
        --data-binary @"$TTL_FILE" \
        "$FUSEKI_ENDPOINT/$FUSEKI_DATASET/data?graph=$GRAPH_IRI"
    echo ""
done