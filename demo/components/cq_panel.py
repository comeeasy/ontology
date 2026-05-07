import streamlit as st


def render(rule: dict):
    st.subheader("Competency Question")
    st.markdown(
        f"""
        > **CQ**: {rule['cq']}

        이 질문에 답하기 위해 아래 TBox와 SHACL Shape이 정의됩니다.
        """
    )
