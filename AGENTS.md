# AGENTS.md

## Repository overview

You-Do is a Flutter mobile app. Application code is under `lib/`, tests under
`test/`, and the Supabase schema, Edge Functions, and database tests under
`supabase/`.

## Setup

Use Flutter 3.38.5 (Dart 3.10.4) and Node.js 20, then run:

```sh
make setup
```

No secrets are needed for setup or the standard checks.

## Development

Start the local backend, copy `.env.example` to `.env.local`, fill the
publishable key from `npx supabase status`, then run the app:

```sh
make local-start
flutter run --dart-define-from-file=.env.local
```

Use `http://10.0.2.2:54321` as `SUPABASE_URL` on an Android emulator. Never
commit `.env`, `.env.local`, linked Supabase state, signing material, or real
Stripe/OAuth credentials.

## Validation

```sh
make check          # format check, analysis/lint, typecheck, unit tests
make build          # debug Android APK and Edge Function type check
make format         # apply Dart formatting
make db-test        # pgTAP tests; requires make local-start
make edge-check     # format, lint, type-check, and unit-test Edge Functions
```

Run `make check` after code changes. Run `make build` when application,
dependency, platform, or Function changes can affect compilation.

## Working rules

- Preserve the feature/data/domain/presentation structure already in `lib/`.
- Add or update self-contained tests for behavior changes.
- Keep the Deno and npm lockfiles committed for deterministic installs.
- Do not introduce secrets, generated build output, or machine-specific paths.
- Add database changes as migrations and cover schema/RLS behavior with pgTAP.
- Keep client/backend boundaries explicit so local and CI tests stay
  credential-free.

## Environment limitations

Remote agents can run `make check` without external services. Database tests
need a Docker-compatible engine. `make build` needs an Android SDK and Java 17.
Google OAuth and Stripe webhooks still need external test-mode configuration.
Credential-free Edge Function unit tests use injected payment/database fakes;
live Stripe behavior must use Stripe test mode.
