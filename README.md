# ✨ MIRA — Next-Gen AI Emotional Companion

<div align="center">

![MIRA Banner](https://images.unsplash.com/photo-1616091093714-c64882e9ab55?q=80&w=1200&auto=format&fit=crop)

**An ultra-realistic, empathetic, and culturally adaptive AI companion designed for meaningful human connection.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.5-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Supabase](https://img.shields.io/badge/Supabase-Auth%20%26%20Database-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Prisma](https://img.shields.io/badge/Prisma-7.9-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io)
[![OpenAI](https://img.shields.io/badge/OpenAI-Whisper%20%26%20TTS-412991?logo=openai&logoColor=white)](https://openai.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## 🌟 Key Highlights

- 🎙️ **Hands-Free Live Voice Calling:** Talk freely like an authentic phone call. Features continuous Voice Activity Detection (VAD) and smart silence recognition—no annoying tap-to-talk buttons.
- 💬 **Instant 0ms Chat Caching:** Multi-tier caching (`SharedPreferences` + in-memory store + indexed queries) ensures chat history opens instantly without delay.
- 🎵 **WhatsApp-Style Audio Bubbles:** Interactive audio messages with real-time waveform scrubber slider, elapsed duration timers, and blue checkmarks (`✓✓`).
- 🌐 **Adaptive Language Mirroring:** Dynamically matches the user's dialect:
  - **Indian / Hinglish:** Speaks in warm, authentic Hinglish with familiar slang (*"yaar"*, *"arre"*, *"haan"*).
  - **International / English:** Speaks in fluent, charming, natural English with zero Indian slang.
  - **Global Languages:** Seamlessly mirrors Spanish, French, German, and other languages.
- 🔔 **3x Daily Proactive Check-Ins:** Automated, local notifications scheduled at 9:00 AM, 2:30 PM, and 10:30 PM in the user's exact local timezone, dynamically rotating so messages never repeat.
- 🛡️ **End-to-End Supabase Security:** Complete Row Level Security (RLS) policies and JWT auth verifying each request.

---

## 📱 Mobile Architecture (`/app`)

Built with **Flutter (Dart)** for smooth 60fps animations and dark luxury aesthetics:

* **State & Routing:** `go_router` with reactive auth-guard redirects.
* **Audio Engine:** `audioplayers` for low-latency voice note playback & streaming.
* **Voice Recording & VAD:** `record` with native microphone permission management and real-time amplitude dB monitoring.
* **Notifications:** `flutter_local_notifications` + `flutter_timezone` for timezone-exact proactive check-ins without external push dependencies.
* **Design System:** Obsidian black surfaces (`#050505`, `#0A0A0A`) with champagne gold accents (`#D4AF37`) and soft rose undertones (`#B76E79`).

---

## 🖥️ Backend Architecture (`/server`)

Built with **Node.js, Express, TypeScript & Prisma ORM**:

* **Database & Auth:** Supabase PostgreSQL with `pgvector` memory embeddings and Supabase Auth.
* **Language Models:** Contextual conversation memory with dynamic relationship leveling (Stranger ➔ Friend ➔ Close Companion).
* **Voice Synthesis & Recognition:** OpenAI Whisper STT + OpenAI Nova female companion voice engine.
* **Hosting:** Deployed serverlessly on Vercel (`mira-backend-nine.vercel.app`).

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.41.0)
- [Node.js](https://nodejs.org/) (>= 18.x)
- Supabase project credentials

---

### Backend Setup (`/server`)

1. Navigate to the server directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file with your credentials:
   ```env
   PORT=3000
   DATABASE_URL="postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"
   DIRECT_URL="postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"
   OPENAI_API_KEY="your-openai-api-key"
   SUPABASE_URL="your-supabase-url"
   SUPABASE_ANON_KEY="your-supabase-anon-key"
   ```

4. Push database schema & seed initial companion:
   ```bash
   npx prisma db push
   npx tsx prisma/seed.ts
   ```

5. Start the development server:
   ```bash
   npm run dev
   ```

---

### App Setup (`/app`)

1. Navigate to the app directory:
   ```bash
   cd app
   ```

2. Install Flutter packages:
   ```bash
   flutter pub get
   ```

3. Configure `.env` in `app/`:
   ```env
   SUPABASE_URL="https://your-project.supabase.co"
   SUPABASE_ANON_KEY="your-supabase-anon-key"
   GOOGLE_WEB_CLIENT_ID="your-google-client-id"
   ```

4. Run on a connected device or emulator:
   ```bash
   flutter run
   ```

5. Build Release APK:
   ```bash
   flutter build apk --release
   ```
   The built APK will be located at `app/build/app/outputs/flutter-apk/app-release.apk`.

---

## 📂 Repository Structure

```
Mira/
├── app/                      # Flutter mobile application
│   ├── android/              # Native Android configuration
│   ├── lib/
│   │   ├── constants/        # Theme & luxury gold palette
│   │   ├── screens/          # Call, Chat, Home, Profile, Login/Signup
│   │   ├── services/         # Audio, API, Notifications & Local Storage
│   │   └── main.dart         # App entrypoint & routing
│   └── pubspec.yaml          # Flutter dependencies
│
├── server/                   # Express TypeScript Backend
│   ├── prisma/               # Schema, migrations & seed scripts
│   ├── src/
│   │   ├── ai/               # Engine, prompt builder, memory service & providers
│   │   ├── middleware/       # Supabase JWT authentication
│   │   ├── routes/           # Auth, Chat & Cron endpoints
│   │   └── index.ts          # Server entrypoint
│   └── package.json
└── README.md
```

---

## 👤 Author

**Meet Ajudia**
- GitHub: [@sbmp69](https://github.com/sbmp69)
- Email: [ajudiameet11@gmail.com](mailto:ajudiameet11@gmail.com)

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
