# FCM (Push Notifications) Setup

The waitlist flow relies on push notifications so users get the "spot opened —
pay to confirm" message within the 30-minute window even when the app is
closed. The code is already wired; what follows is the one-time Firebase
project setup.

Without this setup the app still runs — pushes just silently no-op and users
rely on WebSocket (when app is open) + email. After you drop in the three
config files below, pushes start working with no code changes.

## 1. Firebase project

1. https://console.firebase.google.com → **Add project** → name it anything
   (e.g. `luma-push`).
2. Inside the project → **Project settings** → **General**.
3. Add an **Android app**:
   - Package name: `com.example.mobile` (must match
     `mobile/android/app/build.gradle.kts` → `applicationId`; rename both if
     you want a real package).
   - Download `google-services.json`.
4. Add an **iOS app** if you need iOS pushes:
   - Bundle ID: match `mobile/ios/Runner.xcodeproj` project settings.
   - Download `GoogleService-Info.plist`.
5. **Project settings** → **Service accounts** → **Generate new private key**.
   Download the JSON — this is the backend credential.

## 2. Backend

1. Drop the service-account JSON somewhere the backend can read it, e.g.
   `backend/firebase/service-account.json`. Make sure it's gitignored.
2. In `backend/.env` (or system env):
   ```
   FCM_ENABLED=true
   FCM_CREDENTIALS_PATH=D:/ProjectHK4/backend/firebase/service-account.json
   ```
3. Restart the backend. Look for `Firebase Admin SDK initialised from ...`
   in the logs. If missing, FCM stays off and `FcmPushService.isEnabled()`
   returns false (no-op).

## 3. Mobile — Android

1. Drop `google-services.json` into `mobile/android/app/google-services.json`.
   The gradle plugin is applied conditionally (see
   `mobile/android/app/build.gradle.kts`) — just having the file present
   activates it.
2. `flutter clean && flutter pub get`.
3. `flutter run`. On first launch the app requests notification permission
   (Android 13+) and calls `/api/user/device-tokens` with the FCM token.

## 4. Mobile — iOS

1. Drop `GoogleService-Info.plist` into `mobile/ios/Runner/`.
2. Open `mobile/ios/Runner.xcworkspace` in Xcode → add the plist to the
   `Runner` target (drag-drop into the project navigator, tick "Add to
   target").
3. Enable **Push Notifications** capability on the target.
4. Upload an APNs auth key (p8) in Firebase → **Project Settings** → **Cloud
   Messaging** → **Apple app configuration**.

## 5. Verify end-to-end

1. Register the mobile app with a user, then **kill the app**.
2. Open admin/organiser, cancel a registration on a full event where the
   mobile user is #1 on the waitlist.
3. Expect: push notification on the device within ~1 second with title
   "Spot opened — pay to confirm" (paid) or "You're In!" (free).

## How it's wired

### Backend
- `backend/pom.xml` — `firebase-admin:9.2.0` dep.
- `config/FirebaseConfig.java` — loads `FirebaseApp` only when
  `fcm.enabled=true`. Bean is conditional so missing config ≠ startup failure.
- `service/FcmPushService.java` — multicast push per user; auto-prunes
  `UNREGISTERED`/`INVALID_ARGUMENT` tokens.
- `service/NotificationService.sendNotification()` — every existing
  in-app/WS notification now also fires an FCM push (wrapped in try/catch so
  a push failure doesn't break the DB write).
- `controller/user/UserDeviceTokenController.java` — `POST/DELETE
  /api/user/device-tokens`.
- `entity/DeviceToken.java` + `repository/DeviceTokenRepository.java` —
  per-user tokens, unique on `token` so re-installs reassign cleanly.

### Mobile
- `pubspec.yaml` — `firebase_core`, `firebase_messaging`,
  `permission_handler`.
- `lib/services/push_notification_service.dart` — init, permission, token
  registration, foreground/background handlers.
- `lib/main.dart` — `Firebase.initializeApp()` before `runApp` so the
  background isolate can resolve it.
- `lib/services/notification_service.dart` — on `Authenticated` pushes the
  FCM token to the backend; on `Unauthenticated` it deletes the token both
  locally and on the backend.
- `android/app/build.gradle.kts` — `google-services` plugin applied when
  the JSON is present.

### Security / privacy
- Tokens are scoped to the authenticated user at upload time.
- Globally-unique constraint prevents two accounts silently receiving the
  same device's messages after a sign-out/sign-in.
- `unregisterOnLogout` clears the backend row and calls
  `deleteToken()` on the device so the next user starts fresh.
