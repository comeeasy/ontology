import streamlit as st
from services.loader import load_ttl


def render(rule: dict):
    st.subheader("TBox (스키마)")

    st.markdown("**클래스·프로퍼티 관계**")
    rows = [{"주어 (Domain)": s, "프로퍼티": p, "목적어 (Range)": o} for s, p, o in rule["schema"]]
    st.table(rows)

    with st.expander("TTL 원문 보기"):
        ttl = load_ttl(rule["tbox"])
        if ttl:
            st.code(ttl, language="turtle")
        else:
            st.warning("TTL 파일을 불러올 수 없습니다.")
