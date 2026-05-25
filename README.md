# ScamShield

A Flutter app that helps you detect scams before they hurt you. Built because I was tired of people around me falling for fake job offers, phishing emails, and shady APKs. It uses Gemini AI + Google Safe Browsing + on-device ML to give you a proper risk verdict in seconds.

Supports Android. Dark and light theme both work.

---

## What it does

**URL Checker** — paste any link and it checks it against Google Safe Browsing, then runs its own rule-based analysis on top (suspicious TLDs, typosquatting, IP addresses used as domains, URL shorteners, etc.). Gives a risk score out of 100.

**Email Analyzer** — paste email content and Gemini reads it to decide if it's phishing, spam, or legitimate. If the AI call fails for any reason, it falls back to a keyword-based engine that still catches most common scam patterns.

**APK Analyzer** — upload an APK file and it extracts the AndroidManifest, lists dangerous permissions (SMS read, accessibility service, device admin, overlay attacks, etc.), counts DEX files, checks for native libs, and gives you a breakdown of exactly what risks the app carries.

**Job Analyzer** — paste a job posting. Catches fake job patterns like registration fees, unrealistic salaries, no-company-name listings, MLM schemes, and "no experience needed but earn 1 lakh/month" type stuff. Also uses Gemini for smarter analysis.

**AI Screenshot Scanner** — the floating AI button on the home screen. Upload any screenshot — a WhatsApp message, SMS, email screenshot, anything — and Gemini Vision reads the image and tells you if it's a scam.

All scan history syncs to Supabase if you're logged in. Works offline too with local stats saved on device.

---

## Tech stack

- Flutter (Dart)
- Gemini 1.5 Flash — for AI-powered text and image analysis
- Google Safe Browsing API v4 — URL threat matching
- Supabase — auth + cloud scan history
- TFLite — on-device ML model (fake news / text classification)
- SharedPreferences — local stats when not logged in

---

## Setup

Clone the repo and create a `.env` file in the root (same level as `pubspec.yaml`). There's a `.env.example` file that shows you exactly what's needed:

```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_SAFE_BROWSING_KEY=your_google_api_key
GEMINI_API_KEY_1=your_gemini_key
GEMINI_API_KEY_2=your_gemini_key
```

Get your keys from:
- Supabase → [supabase.com](https://supabase.com) → create a project → Settings → API
- Google Safe Browsing → [Google Cloud Console](https://console.cloud.google.com) → Enable Safe Browsing API → Credentials
- Gemini → [Google AI Studio](https://aistudio.google.com/app/apikey) → Create API key (free tier available)

Then run:

```bash
flutter pub get
flutter run
```

To build release APK:

```bash
flutter build apk --release
```

Output will be at `build/app/outputs/flutter-apk/app-release.apk`

---

## Supabase table

You need one table called `scan_history` in your Supabase project with these columns:

| Column | Type |
|---|---|
| id | uuid (primary key, default gen_random_uuid()) |
| user_id | uuid |
| scan_type | text |
| input_content | text |
| result | text |
| level | text |
| score | int4 |
| reason | text |
| created_at | timestamptz (default now()) |

Enable Row Level Security and add a policy so users can only read/write their own rows (`user_id = auth.uid()`).

---

## Project structure

```
lib/
├── main.dart                   # App entry, Supabase + dotenv init
├── analyzers/
│   ├── ai_analyzer.dart        # Gemini API wrapper
│   ├── email_analyzer.dart     # Email phishing detection
│   ├── job_analyzer.dart       # Fake job detection
│   ├── apk_analyzer.dart       # APK permission scanner
│   ├── url_checker.dart        # URL risk scoring
│   ├── screenshot_analyzer.dart # Gemini Vision for images
│   └── ml_engine.dart          # TFLite + Gemini text classifier
├── services/
│   ├── supabase_service.dart   # Auth + cloud history
│   ├── safe_browsing_service.dart # Google Safe Browsing
│   └── stats_service.dart      # Local scan stats
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── analyze_screen.dart
│   └── history_screen.dart
└── widgets/
    └── stats_chart.dart
```

---

## Requirements

- Android 8.0 (API 26) or higher
- Internet connection for AI features (URL checker, email analyzer, etc.)
- Camera/gallery permission for screenshot scanning

The APK analyzer and basic URL rule-checking work without internet.

---

## Notes

- The `.env` file is gitignored. Never commit it.
- The Gemini free tier has rate limits — if you're scanning a lot, you might hit them. Just wait a minute and retry.
- APK analysis parses the binary AndroidManifest using readable string extraction, so it might miss some permissions in heavily obfuscated APKs. It's a heuristic, not a definitive scanner.
- This project is for personal/educational use. Don't use it as the sole basis for security decisions in a production environment.
