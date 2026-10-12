# 🚶 Safe Step: AI Mobility Aid for the Visually Impaired


**Safe Step** is a web-based visual aid application designed for the visually impaired. It utilizes a smartphone's camera to continuously scan the environment, calculates the distance and direction of obstacles, and generates real-time natural AI voice alerts to provide spatial awareness on the go.

## 🎥 Demo Video
[![Safe Step Demo](https://img.youtube.com/vi/8KmzF3tsJvU/maxresdefault.jpg)](https://www.youtube.com/watch?v=8KmzF3tsJvU)
*(Click the image above to watch the full demonstration on YouTube!)*

## ✨ Key Features

*   **Real-Time Spatial Awareness:** Calculates bounding box coordinates to identify not just *what* an obstacle is, but *where* it is (Left/Center/Right) and *how close* it is to the user.
*   **Zero-Shot Object Detection:** Powered by YOLO-World, it can instantly detect custom environmental hazards (e.g., stairs, pillars, doors) via text prompts without requiring massive datasets.
*   **Absolute Zero-Data Privacy:** All visual data is processed purely in RAM as Base64 strings and permanently destroyed immediately after analysis. No images are saved to a database or disk.
*   **Smart Audio Feedback:** Uses ElevenLabs API for realistic voice generation. It features an anti-spam logic that remembers the previous state and only alerts the user when a *new* hazard appears.
*   **Cross-Platform Accessibility:** Built with Flutter Web, allowing users to access the tool instantly via a web browser on any smartphone without native app installation.

## 🛠 Tech Stack

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | Flutter Web, Dart | Cross-platform web app, Camera & Haptic control |
| **Backend** | Python , FastAPI | Async API handling, low-latency processing |
| **Computer Vision**| YOLO-World | Zero-Shot Object Detection, Spatial calculation |
| **Voice AI** | ElevenLabs API | High-quality, natural Text-to-Speech synthesis |

## ⚙️ How It Works (Architecture)

1.  **Auto-Capture:** The Flutter web app silently captures frames every 1 seconds and encodes them into Base64.
2.  **Transmission:** The data is securely sent to the Python backend via an HTTPS tunnel.
3.  **Vision Analysis:** YOLO-World analyzes the frame. The backend calculates the area ratio of the bounding box to estimate distance and direction.
4.  **TTS Generation:** If a hazard is detected, the warning text is sent to ElevenLabs to generate an MP3 audio file.
5.  **Alert:** Audio and haptic feedback are streamed back to the smartphone.

## 🚀 Getting Started (Local Development)

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install)
*   [Python 3.9+](https://www.python.org/downloads/)
*   ElevenLabs API Key

### 1. Backend Setup
```bash
# Navigate to the backend directory
cd backend

# Install required Python packages
pip install fastapi uvicorn ultralytics pillow pydantic

# Run the FastAPI server
python3 main.py
```

### 2. Frontend Setup
```bash
# Navigate to the frontend directory
cd frontend

# Run the Flutter web server
flutter run -d web-server
```

## 🔮 What's Next
1. Compile into native iOS and Android apps for deeper hardware integration (e.g., Blackout UI for battery saving).
2. Expand the YOLO-World custom classes to detect urban obstacles like crosswalks and traffic lights.

## 🤝 Contributors
**Yohan Yoon** [Full-Stack Devleopment]
**Zane Kaisir** [Backend Development]
**Summer Green** [Computer Vision]
