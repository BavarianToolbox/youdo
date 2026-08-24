# You-Do

You-Do is a Flutter mobile application for financially incentivized task
management. The client is in `lib/`; the current Firebase Cloud Functions
backend is in `functions/`.

## Prerequisites

- Flutter 3.38.5 (Dart 3.10.4), recorded in `.fvmrc`
- Node.js 20, recorded in `.nvmrc`
- Android SDK and Java 17 only when building the Android application

FVM and nvm are optional. Any version manager may be used as long as it selects
the versions above.

## Clean setup

```sh
make setup
```

This installs Flutter packages from `pubspec.lock` and Function packages with
`npm ci` from `functions/package-lock.json`. It requires registry access but no
Firebase project or credentials.

## Validate

```sh
make check
make build
```

`make check` runs formatting checks, Flutter analysis, Function lint and type
checking, and credential-free unit tests. `make build` compiles a debug Android
APK and the Function TypeScript. The Android build also requires an installed
Android toolchain.

Individual commands are available through `make format-check`, `make lint`,
`make typecheck`, and `make test`. Run `make format` to format Dart sources.

## Run locally

Copy the safe example values before configuring integrations:

```sh
cp .env.example .env.local
cp functions/.env.example functions/.env.local
```

The Flutter command does not automatically read `.env.local`; pass its public
Stripe value explicitly:

```sh
flutter run --dart-define=STRIPE_PK=pk_test_placeholder_replace_me
```

The current application initializes Firebase at startup. Live authentication,
data, messaging, payments, and Function testing therefore need Firebase and
Stripe configuration described in [SETUP.md](SETUP.md). These services are not
required for `make check` or compilation. Replacing Firebase with a locally
provisioned backend is the planned next development task.

## Git workflow

Use one branch per local or remote-agent task. Push or checkpoint work before
handing it to another environment, and merge through a pull request after CI
passes. No production deployment is performed by this repository's CI.
