from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from groq import Groq
import json

client = Groq(api_key="groq_api_key")

app = FastAPI()

class VoiceInput(BaseModel):
    text: str
    current_time: str

@app.post("/process_voice")
async def process_voice(data: VoiceInput):
    try:
        prompt = f"""
        You are an AI task assistant. The user said: "{data.text}".
        The current date and time is {data.current_time}.

        Determine the user's intent: 'add_task', 'mark_complete', 'delete_task', or 'delete_all_tasks'.
        
        - If 'add_task': Extract task_name, deadline (ISO-8601 or null), reminder_time (30 mins before deadline or null), priority ('High', 'Medium', 'Low'). 
          CRITICAL: ONLY generate 'subtasks' (list of strings) IF the task is complex and actually requires breakdown steps. If it's a simple task, return an empty array [].
        - If 'mark_complete': Extract 'task_name'.
        - If 'delete_task': Extract 'task_name'.
        - If 'delete_all_tasks': The user wants to clear or remove everything. Return null for other fields.

        You MUST respond ONLY with a valid JSON object matching this exact structure:
        {{
            "intent": "add_task",
            "task_name": "Example Task",
            "deadline": null,
            "reminder_time": null,
            "priority": "Low",
            "subtasks": []
        }}
        """

        chat_completion = client.chat.completions.create(
            messages=[
                {"role": "system", "content": "You are a precise task management assistant that outputs only valid JSON."},
                {"role": "user", "content": prompt}
            ],
            model="openai/gpt-oss-20b",
        )

        response_text = chat_completion.choices[0].message.content.strip()
        if response_text.startswith("```json"): response_text = response_text[7:]
        if response_text.startswith("```"): response_text = response_text[3:]
        if response_text.endswith("```"): response_text = response_text[:-3]

        return json.loads(response_text.strip())
        
    except Exception as e:
        print(f"CRITICAL BACKEND ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
