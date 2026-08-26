# You-Do

You-Do is a Flutter mobile application for financially incentivized task
management. The Flutter client is in `lib/`; the local Supabase project,
PostgreSQL migrations, Edge Functions, and database tests are in `supabase/`.

## Prerequisites

- Flutter 3.38.5 (Dart 3.10.4), recorded in `.fvmrc`
- Node.js 20, recorded in `.nvmrc`
- Deno 2 for Supabase Edge Function checks
- A Docker-compatible engine for the local Supabase stack
- Android SDK and Java 17 only when building the Android application

FVM and nvm are optional. Any version manager may be used as long as it selects
the versions above.

## Clean setup

```sh
make setup
```

This installs the pinned Supabase CLI and Flutter packages from `pubspec.lock`.

## Validate

```sh
make check
make build
```

`make check` runs formatting checks, Flutter analysis, Edge Function lint and
type checking, and credential-free unit tests. `make build` compiles a debug
Android APK and type-checks the Edge Functions. The Android build also requires
an installed Android toolchain.

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
cp supabase/.env.example supabase/.env.local
```

Fill `SUPABASE_PUBLISHABLE_KEY` with the local value printed by
`npx supabase status`, then run Flutter with the file:

```sh
flutter run --dart-define-from-file=.env.local
```

For an Android emulator, change `SUPABASE_URL` in `.env.local` to
`http://10.0.2.2:54321`. Email auth, profiles, tasks, and history use local
Supabase. Google OAuth and Stripe still require their external test-mode
configuration. To exercise payment functions, set a Stripe test secret in
`supabase/.env.local`, then run `npx supabase functions serve --env-file
supabase/.env.local`. The client invokes `create-setup-intent`,
`save-payment-method`, and `process-task-completion`. Stripe calls
`stripe-webhook`, while Supabase Cron calls `process-deadlines`.
[SETUP.md](SETUP.md) documents webhook forwarding, the guarded manual staging
deployment workflow, and the 15-minute Cron job.

## Git workflow

Use one branch per local or remote-agent task. Push or checkpoint work before
handing it to another environment, and merge through a pull request after CI
passes. CI never deploys the application. Staging deployment is a separate,
manually confirmed workflow protected by the GitHub `staging` environment.
