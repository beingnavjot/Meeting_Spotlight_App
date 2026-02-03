# Meeting Spotlight 🎙️✨

Meeting Spotlight is a high-performance Flutter application designed to enhance professional meetings through AI-driven speaker highlighting, real-time transcription, and automated summary generation.

# 🚀 Key Features

AI-Powered Spotlighting: Automatically identifies and highlights the current speaker using voice-activity detection.

Smart Summaries: Integration with Generative AI to provide concise summaries and action items immediately after the meeting ends.

Real-time Synchronization: Low-latency updates across all participants using Firebase Cloud Firestore and WebSockets.

Offline Persistence: Robust offline-first capability using Hive for local caching, ensuring no data loss during connectivity drops.

Cross-Platform Excellence: Pixel-perfect UI tailored for both iOS and Android using a single codebase.

# 🏗️ Architecture & Tech Stack

This project follows Clean Architecture principles to ensure scalability, maintainability, and ease of testing.

State Management: BLoC (Business Logic Component) for a strict separation of concerns.

Dependency Injection: Get_it & Injectable for modular and testable code.

Networking: Dio with custom interceptors for token refreshing and logging.

Local Storage: Hive for high-performance NoSQL local caching.

AI Engine: Integrated via Google Gemini API for meeting intelligence.

Secure Configuration: Utilizing String.fromEnvironment for compile-time variable injection, keeping sensitive keys out of the source code.

# 🛠️ Engineering Highlights

Optimized Rendering: Achieved 60 FPS UI performance by utilizing RepaintBoundary and minimizing widget rebuilds through Equatable state comparisons.

Security: Implemented secure storage for API keys and certificate pinning to prevent Man-in-the-Middle (MITM) attacks.

Native Bridges: Developed custom MethodChannels in Kotlin and Swift for low-level audio processing and foreground service management.

Testing: 80%+ code coverage using Unit, Widget, and Integration tests to ensure production stability.

# 📦 Getting Started

Prerequisites

Flutter SDK ^3.19.0

Firebase Account & Project

Google AI (Gemini) API Key

Installation

Clone the repository:

git clone [https://github.com/navjot-singh/meeting-spotlight.git](https://github.com/navjot-singh/meeting-spotlight.git)


Install dependencies:

flutter pub get


Configure Environment:
The app expects the API key to be provided at build time. Create a config.json file in the root directory (do not commit this file):

{
  "API_KEY": "your_gemini_api_key_here"
}


Run the app:
Launch the application by passing the configuration file:

flutter run --dart-define-from-file=config.json



# 👨‍💻 Author

Navjot Singh Senior Mobile Application Developer

Developed with ❤️ using Flutter & AI
