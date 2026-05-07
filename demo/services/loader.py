from pathlib import Path
from settings import LAW_FILE


def load_ttl(path: str) -> str:
    p = Path(path)
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8")


def load_law_article(article_title: str) -> str:
    if not LAW_FILE.exists():
        return ""
    text = LAW_FILE.read_text(encoding="utf-8")
    lines = text.splitlines()
    result = []
    capturing = False
    for line in lines:
        if article_title in line:
            capturing = True
        elif capturing and line.startswith("제") and article_title not in line:
            break
        if capturing:
            result.append(line)
    return "\n".join(result).strip()
