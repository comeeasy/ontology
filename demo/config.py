from settings import PROJECT_ROOT


def _p(relative: str) -> str:
    return str(PROJECT_ROOT / relative)


RULES = {
    "R1": {
        "title": "제17조 — 안전관리자 선임",
        "article": "제17조(안전관리자)",
        "condition": "상시근로자 50인 이상 사업장은 안전관리자를 1명 이상 선임해야 한다.",
        "condition_source": "산업안전보건법 시행령 [별표 3] — 사업 종류별 안전관리자 선임 기준 (일반 제조업 기준: 상시근로자 50인 이상)",
        "cq": "상시근로자가 50인 이상인 사업장에 안전관리자가 1명 이상 선임되어 있는가?",
        "tbox": _p("ontology/schema/r1.ttl"),
        "shacl": _p("ontology/shapes/r1.shacl.ttl"),
        "abox": _p("ontology/abox/r1.abox.ttl"),
        "etl_script": _p("rdb/scripts/etl.py"),
        "schema": [
            ("사업장", "고용하다", "상시근로자"),
            ("사업장", "선임하다", "안전관리자"),
        ],
        "mapping": [
            {"rdb_table": "factory", "rdb_column": "id, code",        "tbox_class": "is:사업장",       "tbox_property": "rdf:type"},
            {"rdb_table": "person",  "rdb_column": "role = '상시근로자'", "tbox_class": "is:상시근로자",    "tbox_property": "rdf:type"},
            {"rdb_table": "person",  "rdb_column": "role = '안전관리자'", "tbox_class": "is:안전관리자",    "tbox_property": "rdf:type"},
            {"rdb_table": "factory → person", "rdb_column": "role = '상시근로자'", "tbox_class": "is:사업장 → is:상시근로자", "tbox_property": "is:고용하다"},
            {"rdb_table": "factory → person", "rdb_column": "role = '안전관리자'", "tbox_class": "is:사업장 → is:안전관리자", "tbox_property": "is:선임하다"},
        ],
        "enabled": True,
    },
    "R2": {
        "title": "제29조 — 안전보건교육",
        "article": "제29조(근로자에 대한 안전보건교육)",
        "condition": "근로자는 분기별 정기 안전보건교육을 이수해야 한다. (비사무직 6시간 / 사무직 3시간)",
        "cq": "이 근로자는 이번 분기 내에 직종 기준을 충족하는 안전보건교육 이수 기록이 있는가?",
        "tbox": _p("ontology/schema/r2.ttl"),
        "shacl": None,
        "abox": None,
        "etl_script": None,
        "schema": [
            ("근로자", "안전보건교육을이수하다", "안전보건교육"),
            ("근로자", "안전보건교육이수기록을갖다", "안전보건교육이수기록"),
        ],
        "enabled": False,
    },
    "R3": {
        "title": "제36조 — 위험성평가",
        "article": "제36조(위험성평가의 실시)",
        "condition": "사업주는 위험성평가를 연 1회 이상 실시하고 결과를 기록·보존해야 한다.",
        "cq": "이 사업장에 최근 1년 이내에 작성된 위험성평가 기록이 존재하는가?",
        "tbox": _p("ontology/schema/r3.ttl"),
        "shacl": None,
        "abox": None,
        "etl_script": None,
        "schema": [
            ("사업장", "실시하다", "위험성평가"),
            ("위험성평가", "has위험성평가기록", "위험성평가기록"),
        ],
        "enabled": False,
    },
    "R4": {
        "title": "제93조 — 안전검사",
        "article": "제93조(안전검사)",
        "condition": "안전검사대상 기계는 정해진 검사 주기 내에 안전검사를 받고 합격해야 한다.",
        "cq": "이 기계의 최근 검사일로부터 검사 주기가 초과되지 않았으며, 검사 결과가 합격인가?",
        "tbox": _p("ontology/schema/r4.ttl"),
        "shacl": None,
        "abox": None,
        "etl_script": None,
        "schema": [
            ("안전검사대상기계", "필요하다", "안전검사"),
            ("안전검사", "has결과", "안전검사결과"),
        ],
        "enabled": False,
    },
    "R5": {
        "title": "제125조 — 작업환경측정",
        "article": "제125조(작업환경측정)",
        "condition": "유해인자가 존재하는 작업장은 6개월에 1회 이상 작업환경측정을 실시해야 한다.",
        "cq": "유해인자가 존재하는 이 작업장에 최근 6개월 이내에 실시된 작업환경측정 기록이 존재하는가?",
        "tbox": _p("ontology/schema/r5.ttl"),
        "shacl": None,
        "abox": None,
        "etl_script": None,
        "schema": [
            ("사업장", "has작업장", "작업장"),
            ("작업장", "has인자", "유해인자"),
            ("작업장", "작업환경측정검사를수행하다", "작업환경측정검사"),
        ],
        "enabled": False,
    },
}
