import streamlit as st
from pathlib import Path
from services.etl import run_etl
from services.validator import run_validation
from services.abox_reader import read_stats, read_sample


def render(rule: dict):
    st.subheader("ETL 매핑 및 검증")

    if not rule["shacl"] or not rule["abox"]:
        st.warning("검증에 필요한 SHACL 또는 ABox 파일이 아직 준비되지 않았습니다.")
        return

    # 매핑 테이블
    st.markdown("#### RDB → TBox 매핑")
    if rule.get("mapping"):
        st.table([
            {
                "RDB 테이블": m["rdb_table"],
                "RDB 컬럼 / 조건": m["rdb_column"],
                "TBox 클래스/인스턴스": m["tbox_class"],
                "프로퍼티": m["tbox_property"],
            }
            for m in rule["mapping"]
        ])
    st.markdown("---")

    # ETL 실행
    st.markdown("#### ETL 실행")
    if st.button("ETL 실행 (DB → ABox)", key=f"etl_{rule['title']}"):
        with st.spinner("PostgreSQL → ABox 변환 중..."):
            result = run_etl(rule["etl_script"])
        if result["success"]:
            st.success("ABox 생성 완료")
        else:
            st.error(f"ETL 오류:\n{result['error']}")

    # ABox 통계 (파일이 있으면 항상 표시)
    if Path(rule["abox"]).exists():
        stats = read_stats(rule["abox"])
        if stats:
            st.markdown("**생성된 ABox 통계**")
            col1, col2 = st.columns(2)

            with col1:
                st.metric("전체 트리플 수", stats["total_triples"])
                if stats["type_counts"]:
                    st.markdown("**클래스별 인스턴스 수**")
                    st.table([{"클래스": k, "인스턴스 수": v} for k, v in stats["type_counts"].items()])

            with col2:
                if stats["prop_counts"]:
                    st.markdown("**프로퍼티별 트리플 수**")
                    st.table([{"프로퍼티": k, "트리플 수": v} for k, v in stats["prop_counts"].items()])

            with st.expander("샘플 트리플 보기 (5개)"):
                samples = read_sample(rule["abox"])
                if samples:
                    st.table(samples)

    st.markdown("---")

    # SHACL 검증
    st.markdown("#### SHACL 검증")
    if st.button("SHACL 검증 실행", key=f"validate_{rule['title']}"):
        with st.spinner("검증 중..."):
            result = run_validation(rule["abox"], rule["shacl"])

        if "error" in result:
            st.error(result["error"])
            return

        if result["conforms"]:
            st.success("✅ 모든 사업장이 조항을 준수하고 있습니다.")
        else:
            st.error(f"❌ {len(result['violations'])}건의 위반이 발견되었습니다.")
            for v in result["violations"]:
                node = v["focus_node"].split("#")[-1] if "#" in v["focus_node"] else v["focus_node"]
                st.markdown(f"- **{node}**: {v['message']}")
