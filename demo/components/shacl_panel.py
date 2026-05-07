import streamlit as st
from services.loader import load_ttl


def render(rule: dict):
    st.subheader("SHACL Shape (제약 조건)")

    if not rule["shacl"]:
        st.warning("이 규칙의 SHACL Shape은 아직 작성되지 않았습니다.")
        return

    with st.expander("SHACL 원문 보기"):
        shacl = load_ttl(rule["shacl"])
        if shacl:
            st.code(shacl, language="turtle")
        else:
            st.warning("SHACL 파일을 불러올 수 없습니다.")
