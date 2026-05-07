from pathlib import Path
from pyshacl import validate
from rdflib import RDF
from rdflib.namespace import SH


def run_validation(abox_path: str, shacl_path: str) -> dict:
    if not Path(abox_path).exists():
        return {"error": f"ABox 파일 없음: {abox_path}"}
    if not Path(shacl_path).exists():
        return {"error": f"SHACL 파일 없음: {shacl_path}"}

    conforms, results_graph, results_text = validate(
        data_graph=abox_path,
        shacl_graph=shacl_path,
        data_graph_format="turtle",
        shacl_graph_format="turtle",
    )

    return {
        "conforms": conforms,
        "violations": _parse_violations(results_graph),
        "raw": results_text,
    }


def _parse_violations(results_graph) -> list[dict]:
    violations = []
    for result in results_graph.subjects(RDF.type, SH.ValidationResult):
        focus_node = results_graph.value(result, SH.focusNode)
        message = results_graph.value(result, SH.resultMessage)
        violations.append({
            "focus_node": str(focus_node) if focus_node else "",
            "message": str(message) if message else "",
        })
    return violations
