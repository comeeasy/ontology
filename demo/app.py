import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import streamlit as st
from config import RULES
import components.law_panel as law_panel
import components.cq_panel as cq_panel
import components.tbox_panel as tbox_panel
import components.shacl_panel as shacl_panel
import components.result_panel as result_panel

TABS = [
    ("① 법률 조항", law_panel),
    ("② Competency Question", cq_panel),
    ("③ TBox", tbox_panel),
    ("④ SHACL", shacl_panel),
    ("⑤ 검증", result_panel),
]

st.set_page_config(
    page_title="산업안전보건법 온톨로지 데모",
    layout="wide",
)

st.title("산업안전보건법 Compliance Validator")
st.caption("OWL 2 DL 온톨로지 + SHACL 기반 준수 여부 검증 시스템")

st.sidebar.title("규칙 선택")
st.sidebar.markdown("---")

rule_labels = {
    key: f"{'✅' if val['enabled'] else '🔒'} {val['title']}"
    for key, val in RULES.items()
}

selected_key = st.sidebar.radio(
    "조항",
    options=list(RULES.keys()),
    format_func=lambda k: rule_labels[k],
)

selected_rule = RULES[selected_key]

st.sidebar.markdown("---")
st.sidebar.markdown("**파이프라인**")
st.sidebar.markdown("""
```
법률 조항
  ↓
CQ 도출
  ↓
TBox 모델링
  ↓
SHACL 작성
  ↓
ETL (DB → ABox)
  ↓
SHACL 검증
```
""")

if not selected_rule["enabled"]:
    st.warning(f"**{selected_rule['title']}** 은 아직 구현되지 않았습니다.")
    st.stop()

st.header(f"{selected_key} — {selected_rule['title']}")
st.markdown("---")

tabs = st.tabs([label for label, _ in TABS])
for tab, (_, panel) in zip(tabs, TABS):
    with tab:
        panel.render(selected_rule)
