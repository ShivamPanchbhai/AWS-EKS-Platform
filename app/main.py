from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class AIRequest(BaseModel):
    text: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/ai")
def ai(request: AIRequest):
    return {
        "response": "placeholder",
        "model": "bedrock"
    }

