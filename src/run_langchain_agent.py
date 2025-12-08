"""
LangChain 에이전트 - LiteLLM 프록시를 통한 Gemini 모델 사용

이 스크립트는 다음 전제조건이 필요합니다:
1. LiteLLM 프록시가 http://localhost:4444 에서 실행 중
2. gemini-pro 모델이 litellm_settings.yml에 등록됨
3. GEMINI_API_KEY 환경 변수가 docker-compose.yml에 설정됨

실행 방법:
    python src/run_langchain_agent.py
"""

import sys
from typing import Optional

from langchain.agents import create_agent
from langchain_core.messages import AIMessage, HumanMessage, ToolMessage
from langchain_core.runnables import Runnable
from langchain_openai import ChatOpenAI
from langchain_community.tools import DuckDuckGoSearchRun


SYSTEM_PROMPT = (
    "You are a Korean research agent that follows the ReAct pattern. \n"
    "1) 생각 단계에서 사용 가능한 도구를 검토합니다.\n"
    "2) 최신 정보가 필요하면 DuckDuckGo 검색 도구를 사용합니다.\n"
    "3) 모든 도구 결과를 요약하고 출처를 명시한 뒤 한국어로 답변합니다."
)

def create_agent_with_gemini() -> Optional[Runnable]:
    """LangGraph 기반 OpenAI 호환 에이전트를 구성하고 그래프를 반환합니다."""

    try:
        print("[*] LiteLLM 프록시에서 모델 초기화 중 (OpenAI 호환 API)...")
        llm = ChatOpenAI(
            # model="tinyllama1",
            model="gemini-2.5-pro",
            api_key="sk-4444",
            base_url="http://localhost:4444/v1",
            temperature=0.7,
            max_tokens=2048,
            timeout=30,
        )

        print("[*] 검색 도구 초기화 중...")
        tools = [DuckDuckGoSearchRun(name="duckduckgo-search", description="최신 웹 정보를 찾습니다.")]

        print("[*] LangGraph 기반 에이전트 그래프 생성 중...")
        agent_graph = create_agent(
            model=llm,
            tools=tools,
            system_prompt=SYSTEM_PROMPT,
            debug=True,
        )

        print("[✓] 에이전트 생성 완료\n")
        return agent_graph

    except Exception as e:
        print(f"[✗] 에이전트 생성 실패: {type(e).__name__}: {e}", file=sys.stderr)
        print(
            "[!] 다음을 확인하세요:\n"
            "    1. LiteLLM 프록시가 http://localhost:4444 에서 실행 중인지 확인\n"
            "    2. docker compose ps 로 컨테이너 상태 확인\n"
            "    3. docker compose logs litellm 로 프록시 로그 확인\n"
            "    4. GEMINI_API_KEY가 docker-compose.yml에 설정되어 있는지 확인",
            file=sys.stderr,
        )
        return None


def run_agent(agent_graph: Runnable, question: str) -> bool:
    """질문을 LangGraph 에이전트에게 전달하고 결과를 출력합니다."""

    try:
        print(f"[?] 질문: {question}\n")
        print("=" * 70)

        state = agent_graph.invoke(
            {"messages": [HumanMessage(content=question)]},
            config={"recursion_limit": 15},
        )

        print("=" * 70)
        _pretty_print_messages(state.get("messages", []))
        answer = _extract_final_answer(state)
        print(f"\n[✓] 답변:\n{answer}\n")
        return True

    except Exception as e:
        print(f"\n[✗] 에이전트 실행 중 오류 발생: {type(e).__name__}: {e}", file=sys.stderr)
        print(
            "[!] 다음을 확인하세요:\n"
            "    1. 프록시 로그: docker compose logs -f litellm\n"
            "    2. Ollama 모델 상태: docker exec -it tinyllama1 ollama list\n"
            "    3. 네트워크 연결: curl http://localhost:4444/health/liveliness",
            file=sys.stderr,
        )
        return False


def _pretty_print_messages(messages: list) -> None:
    """LangGraph가 생성한 메시지를 역할별로 표시합니다."""

    for message in messages:
        if isinstance(message, HumanMessage):
            print(f"사용자: {message.content}")
        elif isinstance(message, AIMessage):
            content = message.content
            if isinstance(content, list):
                content = "\n".join(
                    part.get("text", "") if isinstance(part, dict) else str(part)
                    for part in content
                )
            print(f"에이전트: {content}")
            if message.tool_calls:
                for call in message.tool_calls:
                    print(
                        f"  ↳ 도구 호출 - name={call['name']} id={call['id']} args={call['args']}"
                    )
        elif isinstance(message, ToolMessage):
            print(f"도구 응답({message.name}): {message.content}")


def _extract_final_answer(state: dict) -> str:
    """LangGraph 상태에서 마지막 AI 메시지를 추출합니다."""

    messages = state.get("messages", [])
    for message in reversed(messages):
        if isinstance(message, AIMessage):
            content = message.content
            if isinstance(content, list):
                text = "\n".join(
                    part.get("text", "") if isinstance(part, dict) else str(part)
                    for part in content
                )
                return text.strip()
            return str(content)

    structured = state.get("structured_response")
    if structured is not None:
        return str(structured)
    return "(응답 없음)"


def main() -> int:
    """메인 함수"""
    print("\n" + "=" * 70)
    print("  LangChain 에이전트 (LiteLLM 프록시 기반)")
    print("=" * 70 + "\n")

    # 에이전트 생성
    agent_executor = create_agent_with_gemini()
    if agent_executor is None:
        return 1

    # 테스트 질문 1: 뉴스 조회
    question1 = "오늘 한국의 주요 뉴스는 무엇인가?"
    if not run_agent(agent_executor, question1):
        return 1

    # (선택사항) 테스트 질문 2: 날씨
    # question2 = "서울의 현재 날씨는?"
    # if not run_agent(agent_executor, question2):
    #     return 1

    print("[✓] 모든 테스트 완료!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
