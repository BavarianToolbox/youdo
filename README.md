# You-Do

You-Do is a Flutter mobile application for financially incentivized task
management. The Flutter client is in `lib/`; the local Supabase project,
PostgreSQL migrations, and database tests are in `supabase/`. The Firebase
Cloud Functions in `functions/` are legacy code being replaced.

## Prerequisites

- Flutter 3.38.5 (Dart 3.10.4), recorded in `.fvmrc`
- Node.js 20, recorded in `.nvmrc`
- A Docker-compatible engine for the local Supabase stack
- Android SDK and Java 17 only when building the Android application

FVM and nvm are optional. Any version manager may be used as long as it selects
the versions above.

## Clean setup

```sh
make setup
```

This installs the pinned Supabase CLI, Flutter packages from `pubspec.lock`,
and legacy Function packages from their lockfile.

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

Database checks require the local stack:

```sh
make local-start
make db-reset
make db-test
```

Supabase Studio is then available at `http://127.0.0.1:54323`. Stop the stack
with `make local-stop`.

## Run locally

Copy the safe example values before configuring integrations:

```sh
cp .env.example .env.local
cp functions/.env.example functions/.env.local
```

Fill `SUPABASE_PUBLISHABLE_KEY` with the local value printed by
`npx supabase status`, then run Flutter with the file:

```sh
flutter run --dart-define-from-file=.env.local
```

For an Android emulator, change `SUPABASE_URL` in `.env.local` to
`http://10.0.2.2:54321`. Email auth, profiles, tasks, and history use local
Supabase. Google OAuth and Stripe still require their external test-mode
configuration. [SETUP.md](SETUP.md) documents the legacy Firebase backend only
while its payment Functions are migrated.

## Git workflow

Use one branch per local or remote-agent task. Push or checkpoint work before
handing it to another environment, and merge through a pull request after CI
passes. No production deployment is performed by this repository's CI.
