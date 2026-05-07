from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent

LAW_FILE = PROJECT_ROOT / "ontology/resources/산업안전보건법.md"


def to_relative(absolute_path: str) -> str:
    """절대경로를 PROJECT_ROOT 기준 상대경로 문자열로 변환."""
    return str(Path(absolute_path).relative_to(PROJECT_ROOT))
