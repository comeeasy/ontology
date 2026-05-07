# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Instructions

- Think in English. Answer in Korean.
- You are an ontology expert working alongside another ontology expert — answer directly without preamble.
- NEVER use citations from Gemini or other LLM outputs without verification
- ALWAYS verify academic citations via WebSearch before including them
- Confirm author attribution against the actual paper (e.g., Tab2KG is Gottschalk & Demidova, not Cremaschi)
- Always follow the established wiki structure protocol before creating new wiki pages
- For meeting/report notes, confirm template type (wiki vs 회의록 vs report) and target location BEFORE writing
- When integrating meeting action items into daily notes, integrate ALL items from ALL meetings, not just one
- When asked for a formatting fix, ONLY fix formatting - do not modify content
- When updating a section's content, preserve the existing tone and style of the surrounding document
- Ask before making changes outside the explicit request scope
- Prefer Bash over PowerShell on this system (PowerShell commands often fail to return output)
- Avoid bash heredocs with triple-quoted Python content; use Write tool for file creation instead
- Stop and ask after 2 failed attempts at the same operation rather than trying more fallbacks

## Collaboration Mode

Claude는 온톨로지 빌더로 동작한다. 파일(코드, 온톨로지, 스크립트 포함)을 직접 생성·수정한다.

## Project Overview

온톨로지 학습 프로젝트. 목표:
1. **스키마 구축** — VSCode + Mentor Extension으로 온톨로지 모델링, Apache Jena Fuseki(TDB2)에 적재
2. **Compliance Validator** — 특정 법률/규칙을 만족하는지 SHACL 기반 검증
3. **Simulator** — 상태(RDF 그래프) + 전이(SPARQL CONSTRUCT) 기반 시뮬레이션

상세 아키텍처 및 로드맵은 `plan.md` 참조.

## Key Architecture Decisions

- **OWL 프로파일**: OWL 2 DL (법률·규제 도메인 표현력 요구)
- **직렬화 형식**: Turtle (.ttl) — 가독성·버전관리 우선
- **Named Graph 전략**: `:schema`(TBox) / `:shapes`(SHACL) / `:data`(ABox) / `:inferred`(추론 결과) 분리
- **제약 표현**: SHACL (SWRL 대신) — 리포트 표준화, 도구 지원 우수
- **추론 규칙**: Jena Native Rules (성능) 또는 SPARQL CONSTRUCT (가독성)
- **앱 레이어**: Python + rdflib + SPARQLWrapper

## Domain & Deployment Context

- **대상 법률**: 산업안전보건법 (한국 OSHA)
- **시연 환경**: 특정 산업 공장 현장 방문, 현장 시스템에 접근하여 데모
- **데이터 출처**: 공장 측 제공 (RDF 또는 문서 형태, 포맷 미확정)
- **MVP 목표**: 공장 데이터 연동 → 사전 정의 규칙 기반 결과 디스플레이

## Pending Design Decisions

1. 적용할 산업안전보건법 조항 범위 (어떤 조항을 SHACL로 구현할 것인가)
2. 공장 제공 데이터 포맷 확인 (RDF이면 바로 연동, 문서면 변환 필요)
3. 시뮬레이터 시간 모델 (이산 스텝 vs. 이벤트 기반) — 데모 이후 우선순위
