🎙️ TaskPulse AI

An AI-powered, voice-to-action task manager built with Flutter and FastAPI. TaskPulse uses Google's Gemini LLM to extract intents from natural language, auto-calculate deadlines, generate actionable sub-tasks, and intelligently prioritize your workflow.

✨ Standout Features

Voice-to-Action Engine: Speak naturally (e.g., "Remind me to submit the physics report before 5 PM") and let the app handle the data entry.

AI Auto-Prioritization: The backend LLM analyzes task context and automatically assigns High, Medium, or Low priority.

Smart Sub-Task Generation: Complex tasks (e.g., "Plan a marketing campaign") are automatically broken down into bite-sized, actionable sub-tasks by the AI.

Proactive Local Notifications: Automatically calculates and schedules on-device alerts exactly 30 minutes before any spoken deadline.

Intelligent Daily Reset: Completed tasks are cleared automatically the next day, while pending tasks carry over with a dynamic "overdue" indicator (e.g., (yesterday), (27th Sept)).

Cross-Platform Swipe UI: Clean, swipeable tab interface built in Flutter to separate active priorities from completed wins.

🛠️ Tech Stack

Frontend:

Framework: Flutter (Dart)

State Management: setState (easily upgradable to Provider/Riverpod)

Hardware Integration: speech_to_text, flutter_local_notifications

Backend:

Framework: Python FastAPI

AI Engine: Google Gemini (google-generativeai)

Server: Uvicorn (ASGI)

Environment: Designed for local development via WSL (Windows Subsystem for Linux)

🏗️ System Architecture

User Speaks: Flutter captures voice via the device microphone.

API Call: The raw text is sent over the local network to the FastAPI backend.

LLM Processing: Gemini processes the text, classifying intent (add_task or mark_complete), calculating time offsets, and generating sub-tasks.

Structured JSON: Backend returns strict JSON to the frontend.

UI & Hardware Update: Flutter adds the task to the UI and schedules a native OS notification based on the calculated reminder_time.

🚀 Installation & Setup

Prerequisites

Flutter SDK installed on your machine.

Python 3.8+ installed (WSL Ubuntu recommended for Windows users).

A Google Gemini API Key.

A physical Android/iOS device or emulator for testing microphone and notifications.

1. Backend Setup (FastAPI)

Open your terminal (or WSL environment):

# Clone the repository
git clone https://github.com/yourusername/taskpulse-ai.git
cd taskpulse-ai/backend

# Create a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Export your Gemini API Key
export GEMINI_API_KEY="your_api_key_here"

# Run the server
uvicorn main:app --host 0.0.0.0 --port 8000


Note: Keep note of your machine's local IPv4 address (e.g., 192.168.1.X), as you will need it for the Flutter app.

2. Frontend Setup (Flutter)

Open a new terminal window:

cd taskpulse-ai/frontend

# Install Flutter packages
flutter pub get


Configure Backend IP:
Open frontend/lib/main.dart and update the backendUrl variable to point to your computer's local IP address where the FastAPI server is running:

final String backendUrl = "http://192.168.1.X:8000/process_voice"; // Replace X with your IP


Run the App:
Connect your physical device via USB (ensure USB Debugging is enabled) and run:

flutter run


📱 Usage

Tap the Microphone FAB at the bottom of the screen.

Say something like: "I need to review the codebase documentation by 6:30 PM."

Watch as the app creates the task, tags it with a priority, generates sub-tasks, and silently schedules an alert for 6:00 PM.

Tap the Checkbox to mark a task as completed and move it to the "Completed" tab.

🔮 Future Roadmap

[ ] SQLite/Hive local storage for persistent task saving across reboots.

[ ] User authentication and cloud syncing.

[ ] Custom voice synthesized feedback for accessibility.

[ ] Calendar integration (Google Calendar API).
