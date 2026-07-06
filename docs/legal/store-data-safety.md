# Store submission — Data Safety / App Privacy cheat-sheet

Practical answers for the **Google Play “Data safety”** form and **Apple App Store “App
Privacy”** questionnaire for **Eco health**. Derived from the actual code
(`lib/ai/ai_advice_service.dart`, `lib/notifications/`, `lib/steps/`, `AndroidManifest.xml`).

Fill the bracketed items and keep this in sync with the app if data flows change.

---

## 0. Publishing prerequisites (both stores)

- **Privacy policy URL is required** because the app processes personal data and sends some
  of it to third parties (Firebase + DeepSeek). Host `privacy-policy-*.md` at a public URL
  and paste it into Play Console and App Store Connect.
- In-app consent is shown once after onboarding (see `lib/screens/consent.dart`).
- Operator: **Ekologiya va iqlim oʻzgarishi milliy qoʻmitasi**. Developer: **AI laboratoriya**.
  Contact: **cproarxangel@gmail.com**.

---

## 1. Google Play — Data safety

**Does your app collect or share any of the required user data types?** → **Yes**
(only when the user requests AI advice).

| Data type | Collected | Shared | Processed ephemerally | Purpose | Notes |
|---|---|---|---|---|---|
| Health & fitness (nutrition, steps, body metrics) | Yes | **Yes** | Prefer “No” (shared to generate advice) | App functionality | Sent to Firebase + DeepSeek **only** on an AI-advice request |
| Personal info – name | Collected (optional) | **No** | — | App functionality | Stored on-device only; **not** sent for AI |
| Personal info – other (sex, age/DOB, height, weight, goal) | Yes | **Yes** | — | App functionality | De-identified; part of the AI snapshot |
| Photos (profile photo) | Collected (optional) | No | — | App functionality | On-device only |
| App activity / diagnostics / location / contacts | **No** | No | — | — | Not collected |

Key answers:
- **Is all user data encrypted in transit?** → **Yes** (HTTPS to Firebase/DeepSeek).
- **Do you provide a way to request data deletion?** → **Yes** — in-app **Profile → Reset
  data**, and uninstalling removes all local data. (No server-side account exists.)
- **Is data collection required or optional?** → AI feature (and its data sharing) is
  **optional** — the user chooses to request advice.
- **Third parties:** Google Firebase (Cloud Functions, App Check) and the DeepSeek AI service.

> Play also asks about the **`ACTIVITY_RECOGNITION`** and exact-alarm permissions and about
> `POST_NOTIFICATIONS` — declare them and their in-app rationale (steps counting; reminders).
> Exact alarm (`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`) may need a Play Console declaration;
> the app already falls back to inexact alarms when not granted.

---

## 2. Apple App Store — App Privacy

Even though there is currently **no `ios/` project in the repo**, if/when you ship to the App
Store, use these answers.

**Data used to track you:** **None** (no advertising, no cross-app tracking, no analytics).

**Data linked to you:** **None** — there is no account, so data is not tied to an identity.

**Data NOT linked to you** (collected but not tied to identity):
- **Health & Fitness** — nutrition, steps, body metrics. Purpose: App Functionality.
- **Other User Content / Other Data** — profile attributes (sex, age, height, weight, goal)
  included in the AI snapshot. Purpose: App Functionality.

Notes for the reviewer / App Review:
- Data leaves the device **only** when the user taps to get AI advice; it goes to Google
  Firebase and the DeepSeek AI service over HTTPS to produce a nutrition recommendation.
- No name/photo/contact/precise-location is sent for AI.
- Add the **`NSMotionUsageDescription`** key to `Info.plist` for step/motion access, e.g.
  “Eco health uses motion & fitness data to count your steps and estimate calories burned.”
- The app is informational and **not a medical device** (state this in the review notes to
  avoid health-claim rejections).

---

## 3. One-liners you can paste into store listings

**EN:** “Eco health stores your data on your device. When you request AI advice, a
de-identified summary of your nutrition and profile is sent over a secure connection to
Google Firebase and the DeepSeek AI service to generate the recommendation. No ads, no
tracking, no account. The app is informational and not a medical device.”

**RU:** «Eco health хранит данные на вашем устройстве. При запросе ИИ-совета обезличенная
сводка о питании и профиле передаётся по защищённому соединению в Google Firebase и сервис
DeepSeek для формирования рекомендации. Без рекламы, без трекинга, без аккаунта. Приложение
носит справочный характер и не является медицинским изделием.»
