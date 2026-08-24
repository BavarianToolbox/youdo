# You-Do — Setup Guide

> This guide configures the application's current hosted Firebase and Stripe
> integrations. It is optional for credential-free setup and validation; start
> with `make setup` and `make check` from the repository root. Firebase is
> scheduled to be replaced by a locally provisioned backend.

## Prerequisites

- Flutter SDK 3.38.5 / Dart 3.10.4 (`flutter --version`)
- Node.js 20 and npm
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`
- A Firebase project (free Blaze plan required for Cloud Functions)
- A Stripe account (free; use test mode)

---

## Step 1: Firebase Project

1. Go to https://console.firebase.google.com and create a project
2. Enable these services:
   - Authentication → Sign-in providers: **Email/Password** and **Google**
   - Firestore Database → Create in production mode, pick a region
   - Cloud Functions (requires Blaze billing plan)
   - Cloud Messaging (automatic)
3. In Authentication → Settings → Authorized domains, your app's domain is already there

---

## Step 2: Connect Flutter to Firebase

```bash
# From repo root
flutterfire configure
```

Follow the prompts to select your Firebase project. This generates `lib/firebase_options.dart` with real values (replacing the placeholder file).

### iOS additional step
In Xcode, set the deployment target to 14.0:
- Open `ios/Runner.xcworkspace`
- Select Runner target → General → Minimum Deployments → 14.0

### Android Google Sign-In setup
```bash
# Get SHA-1 fingerprint
cd android && ./gradlew signingReport | grep SHA1
```
Add the SHA-1 to Firebase Console → Project Settings → Your Android app → Add fingerprint.

---

## Step 3: Stripe

1. Create account at https://stripe.com (free)
2. Switch to **Test mode** (toggle in dashboard top-right)
3. Go to Developers → API Keys:
   - Copy **Publishable key** (`pk_test_...`)
   - Copy **Secret key** (`sk_test_...`) — keep this safe, never commit it

---

## Step 4: Cloud Functions Environment

```bash
cd functions
npm install

# Set Stripe secret key in Firebase config
firebase functions:config:set stripe.secret="sk_test_YOUR_SECRET_KEY"

# Build TypeScript
npm run build
```

---

## Step 5: Deploy Firestore Rules & Indexes

```bash
# From repo root
firebase login   # if not already logged in
firebase use --add   # select your project

firebase deploy --only firestore:rules,firestore:indexes
```

---

## Step 6: Deploy Cloud Functions

```bash
firebase deploy --only functions
```

After deployment, note the `stripeWebhook` function URL (shown in output or Firebase Console → Functions).

### Register Stripe Webhook
1. Go to Stripe Dashboard → Developers → Webhooks → Add endpoint
2. URL: `https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net/stripeWebhook`
3. Events to listen for: `payment_intent.succeeded`, `payment_intent.payment_failed`
4. Copy the **Signing secret** (`whsec_...`)
5. `firebase functions:config:set stripe.webhook_secret="whsec_YOUR_SECRET"`
6. Redeploy: `firebase deploy --only functions`

---

## Step 7: Run the App

```bash
# Run on iOS simulator
flutter run --dart-define=STRIPE_PK=pk_test_YOUR_PUBLISHABLE_KEY

# Run on Android emulator
flutter run -d android --dart-define=STRIPE_PK=pk_test_YOUR_PUBLISHABLE_KEY
```

---

## Testing Stripe Payments

Use these test card numbers (any future expiry, any CVC):

| Card number | Scenario |
|---|---|
| `4242 4242 4242 4242` | Success |
| `4000 0000 0000 9995` | Insufficient funds |
| `4000 0000 0000 3220` | 3D Secure required |

---

## Testing the Deadline Checker

The `checkDeadlines` Cloud Function runs every 15 minutes. To test immediately:

1. Create a task with a due date in the past
2. Invoke the function manually from Firebase Console → Functions → checkDeadlines → Test

Or use the Firebase Emulator Suite:
```bash
firebase emulators:start --only functions,firestore
```

---

## Phase 2 Roadmap

- [ ] Social media linking (X/Twitter, Instagram, TikTok) via OAuth
- [ ] Automated "accountability post" on task failure
- [ ] Political donation as penalty destination
- [ ] Stripe Connect for real user reward payouts
- [ ] Task streaks and gamification
- [ ] Shared/collaborative tasks
