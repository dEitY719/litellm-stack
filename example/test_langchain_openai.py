import uuid
from langchain_openai import ChatOpenAI
import os
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

os.environ["OPENAI_API_KEY"] = os.getenv("API_KEY")
api_base_url = os.getenv("API_BASE")
credential_key = os.getenv("X_DEP_TICKET")

llm = ChatOpenAI(
    base_url=api_base_url,
    model="gpt-oss-20b",
    default_headers={
        "x-dep-ticket": credential_key,
        "Send-System-Name": os.getenv("SEND_SYSTEM_NAME"),
        "User-Id": os.getenv("USER_ID"),
        "User-Type": os.getenv("USER_TYPE"),
        "Prompt-Msg-Id": str(uuid.uuid4()),
        "Completion-Msg-Id": str(uuid.uuid4()),
    },
)

for chunk in llm.stream("한국의 계절에 대해 설명해줘"):
    print(chunk.content, end="", flush=True)
print()
print(llm.invoke("안녕?"))
