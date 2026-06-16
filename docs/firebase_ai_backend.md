# Firebase AI Backend

The Android app must not contain the DeepSeek API key. AI advice now goes through
a Firebase callable function:

```text
Flutter app -> Firebase Callable Function aiAdvice -> DeepSeek API
```

## One-time setup

Firebase Secret Manager requires the Firebase project to be on the Blaze
pay-as-you-go plan. The app can still stay free/low-cost in practice if usage is
small, but Firebase will not allow `functions:secrets:set DEEPSEEK_API_KEY` on the
Spark plan.

1. Sign in to Firebase from a normal terminal:

```powershell
tooling\firebase_cli.cmd login
```

The wrapper uses the bundled Node.js runtime, so global `npm` and
`firebase-tools` are not required.

2. Create or select a Firebase project, then register the Android app with
package name `uz.ecokomitet.eco_mobile`.

Download `google-services.json` from Firebase Console and place it at
`android/app/google-services.json`. This file contains Firebase project
identifiers, not the DeepSeek API secret.

3. Copy `.firebaserc.example` to `.firebaserc` and replace
`YOUR_FIREBASE_PROJECT_ID`.

Do not commit `.firebaserc` or `android/app/google-services.json`; both are
local project bindings. Another developer should create their own Firebase
project and add their own files.

4. Store the DeepSeek key in Secret Manager and deploy the function:

```powershell
tooling\deploy_ai_backend.cmd
```

This script installs the Cloud Functions dependencies, asks Firebase to store
`DEEPSEEK_API_KEY` as a Secret Manager secret, then deploys `aiAdvice`.

If Firebase says the project must be on the Blaze plan, upgrade that Firebase
project in Firebase Console first. After upgrading, run
`tooling\deploy_ai_backend.cmd` again.

To only check the Firebase CLI wrapper:

```powershell
tooling\firebase_cli.cmd --version
```

## App Check

In Firebase Console, open App Check for the Android app and enable Play
Integrity. Add the release SHA-256 fingerprint for the signing key used to ship
the APK/AAB.

Debug builds use the App Check debug provider. Run the app once, copy the debug
token printed in logs, and add it in Firebase Console under App Check debug
tokens.

The function also sets `enforceAppCheck: true`, so requests without a valid App
Check token are rejected before DeepSeek is called.

## Model

The default model is `deepseek-v4-flash`. To override it, create
`functions/.env` from `functions/.env.example` and set:

```bash
DEEPSEEK_MODEL=deepseek-v4-pro
```

Do not put `DEEPSEEK_API_KEY` in Flutter `--dart-define`, `.env`, `BuildConfig`,
Remote Config, or any file bundled into the APK.
