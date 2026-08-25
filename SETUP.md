# Supabase and Stripe Setup

The credential-free development path is documented in [README.md](README.md).
This guide covers the external configuration required to exercise Stripe in
test mode or deploy the backend to a hosted Supabase project.

## Local Stripe testing

1. Copy `supabase/.env.example` to `supabase/.env.local`.
2. Put a Stripe **test-mode** secret key in `STRIPE_SECRET_KEY`.
3. Start Supabase and serve the functions:

```sh
make local-start
npx supabase functions serve --env-file supabase/.env.local
```

In another terminal, forward Stripe test events to the local webhook:

```sh
stripe listen \
  --forward-to http://127.0.0.1:54321/functions/v1/stripe-webhook
```

Copy the displayed `whsec_...` value into `STRIPE_WEBHOOK_SECRET`, restart the
function server, and run the Flutter application with a Stripe test-mode
publishable key. Never commit either Stripe secret.

## Hosted Supabase deployment

Link the repository to a non-production Supabase project first:

```sh
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
npx supabase secrets set \
  STRIPE_SECRET_KEY=sk_test_YOUR_KEY \
  STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
npx supabase functions deploy
```

Register this Stripe webhook endpoint:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/stripe-webhook
```

Subscribe it to:

- `payment_intent.succeeded`
- `payment_intent.payment_failed`

The webhook does not accept Supabase JWTs. It verifies Stripe's signature over
the unmodified request body before applying an event.

## Schedule deadline processing

The `process-deadlines` function must run every 15 minutes. In the Supabase
Dashboard, create a Cron job that invokes this Edge Function with the project's
secret key in the `apikey` header. Store the project URL and secret key in
Supabase Vault; do not embed either value directly in migration SQL.

The equivalent schedule is:

```text
*/15 * * * *
```

The function atomically claims overdue tasks before charging them. Repeated or
concurrent invocations cannot claim the same task, and Stripe charges use the
task ID as their idempotency key.

## What remains external

- Stripe test/live credentials and webhook registration
- Hosted Supabase project creation and function deployment
- Supabase Cron/Vault configuration
- Google OAuth provider credentials and redirect configuration

None of these are required for `make check`, `make build`, or database tests.
