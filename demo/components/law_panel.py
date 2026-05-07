import streamlit as st
from services.loader import load_law_article


def render(rule: dict):
    st.subheader("법률 조항")
    text = load_law_article(rule["article"])
    if text:
        st.markdown(f"```\n{text}\n```")
    else:
        st.warning("법률 원문을 불러올 수 없습니다.")

    st.info(f"**준수 조건**: {rule['condition']}")

    if rule.get("condition_source"):
        st.caption(f"📎 근거: {rule['condition_source']}")
