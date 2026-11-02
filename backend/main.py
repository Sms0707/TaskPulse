from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
import os
import json
from datetime import datetime, timedelta

app = FastAPI()

# Configure your Gemini API key in your WSL environment variables
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
model = genai.GenerativeModel('gemini-1.5-pro')

class VoiceInput(BaseModel):
    text: str
    current_time: str 

@app.post("/process_voice")
async def process_voice(data: VoiceInput):
    prompt = f"""
    You are an AI task assistant. The user said: "{data.text}". 
    The current date and time is {data.current_time}.
    
    Determine the user's intent: 'add_task' or 'mark_complete'.
    If 'add_task', extract the task name, determine a strict ISO 8601 deadline, and calculate a reminder time exactly 30 minutes BEFORE the deadline.
    Assign a priority (High, Medium, Low) based on urgency.
    If the task is complex (e.g., "plan a project"), generate 2-3 short subtasks.
    
    Output strictly in JSON format without markdown blocks:
    {{
        "intent": "add_task" | "mark_complete",
        "task_name": "string",
        "deadline": "ISO 8601 string or null",
        "reminder_time": "ISO 8601 string or null",
        "priority": "High" | "Medium" | "Low",
        "subtasks": ["string", "string"]
    }}
    """
    try:
        response = model.generate_content(prompt)
        # Clean up any potential markdown formatting from the response
        clean_json = response.text.replace('```json', '').replace('```', '').strip()
        result = json.loads(clean_json)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Run locally using: uvicorn main:app --host 0.0.0.0 --port 8000
