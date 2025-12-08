import uuid
from openai import OpenAI
import os
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

os.environ["OPENAI_API_KEY"] = os.getenv("API_KEY")
api_base_url = os.getenv("API_BASE")
credential_key = os.getenv("X_DEP_TICKET")

client = OpenAI(
    base_url=api_base_url,
    default_headers={
        "x-dep-ticket": credential_key,
        "Send-System-Name": os.getenv("SEND_SYSTEM_NAME"),
        "User-Id": os.getenv("USER_ID"),
        "User-Type": os.getenv("USER_TYPE"),
        "Prompt-Msg-Id": str(uuid.uuid4()),
        "Completion-Msg-Id": str(uuid.uuid4()),
    },
)

completion = client.chat.completions.create(
    model="gpt-oss:20b",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "How are you?"},
    ],
)

print(completion.choices[0].message.content)
