from pathlib import Path
from rdflib import Graph, RDF


def read_stats(abox_path: str) -> dict:
    if not Path(abox_path).exists():
        return {}

    g = Graph()
    g.parse(abox_path, format="turtle")

    type_counts = {}
    for _, _, o in g.triples((None, RDF.type, None)):
        label = str(o).split("#")[-1]
        type_counts[label] = type_counts.get(label, 0) + 1

    prop_counts = {}
    for _, p, _ in g.triples((None, None, None)):
        if str(p) == str(RDF.type):
            continue
        label = str(p).split("#")[-1]
        prop_counts[label] = prop_counts.get(label, 0) + 1

    return {
        "total_triples": len(g),
        "type_counts": type_counts,
        "prop_counts": prop_counts,
    }


def read_sample(abox_path: str, limit: int = 5) -> list[dict]:
    if not Path(abox_path).exists():
        return []

    g = Graph()
    g.parse(abox_path, format="turtle")

    samples = []
    for s, p, o in g:
        subj = str(s).split("#")[-1]
        pred = str(p).split("#")[-1]
        obj = str(o).split("#")[-1]
        samples.append({"주어": subj, "술어": pred, "목적어": obj})
        if len(samples) >= limit:
            break

    return samples
