# AGENTS.md

## Repository overview

You-Do is a Flutter mobile app. Application code is under `lib/`, tests under
`test/`, and the current Firebase Functions TypeScript backend under
`functions/src/`. Treat `functions/lib/` as generated output.

## Setup

Use Flutter 3.38.5 (Dart 3.10.4) and Node.js 20, then run:

```sh
make setup
```

No secrets are needed for setup or the standard checks.

## Development

Run the mobile app on an available simulator/device with:

```sh
flutter run --dart-define=STRIPE_PK=pk_test_placeholder_replace_me
```

The current live application requires Firebase. See `SETUP.md` for optional
hosted integration setup. Never commit `.env`, `.env.local`, Firebase project
selection, signing material, or real Stripe/Firebase credentials.

## Validation

```sh
make check          # format check, analysis/lint, typecheck, unit tests
make build          # debug Android APK and Function JavaScript
make format         # apply Dart formatting
```

Run `make check` after code changes. Run `make build` when application,
dependency, platform, or Function changes can affect compilation.

## Working rules

- Preserve the feature/data/domain/presentation structure already in `lib/`.
- Add or update self-contained tests for behavior changes.
- Edit `functions/src/`, not generated `functions/lib/`; rebuild afterward.
- Keep lockfiles committed and use `npm ci` for deterministic Function installs.
- Do not introduce secrets, generated build output, or machine-specific paths.
- Keep the client/backend boundary explicit during the planned Firebase
  replacement so local and CI tests remain credential-free.

## Environment limitations

Remote agents can run `make check` without external services. `make build`
needs an Android SDK and Java 17. Device/simulator runs, push notifications,
Google sign-in, Stripe webhooks, and the hosted Firebase integration are not
part of the credential-free CI path.
