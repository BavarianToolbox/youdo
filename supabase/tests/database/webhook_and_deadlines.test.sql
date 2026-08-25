begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at
) values (
  '40000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'deadlines@example.com',
  crypt('local-password', gen_salt('bf')),
  now(),
  '{"display_name":"Deadline User"}'::jsonb,
  now(),
  now()
);

insert into public.tasks (
  id, user_id, title, due_date, penalty_amount
) values
  (
    '40000000-0000-0000-0000-000000000041',
    '40000000-0000-0000-0000-000000000004',
    'Overdue task',
    now() - interval '1 hour',
    5
  ),
  (
    '40000000-0000-0000-0000-000000000042',
    '40000000-0000-0000-0000-000000000004',
    'Future task',
    now() + interval '1 hour',
    5
  );

select is(
  (select count(*) from public.claim_overdue_tasks(100)),
  1::bigint,
  'the worker atomically claims only overdue tasks'
);

select is(
  (select status from public.tasks where id = '40000000-0000-0000-0000-000000000041'),
  'missed'::public.task_status,
  'a claimed overdue task is marked missed'
);

select ok(
  (select deadline_processed from public.tasks where id = '40000000-0000-0000-0000-000000000041'),
  'a claimed deadline is marked processed'
);

select is(
  (select count(*) from public.claim_overdue_tasks(100)),
  0::bigint,
  'a concurrent or repeated worker cannot reclaim the task'
);

select lives_ok(
  $$ select public.record_task_penalty(
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000041',
    'pi_webhook_test',
    'pending'
  ) $$,
  'a missed-task penalty can be recorded pending'
);

select is(
  (select total_lost from public.profiles where id = '40000000-0000-0000-0000-000000000004'),
  0.00::numeric,
  'a pending payment does not increment total lost'
);

select lives_ok(
  $$ select public.apply_payment_intent_event(
    'evt_webhook_test',
    'payment_intent.succeeded',
    'pi_webhook_test',
    'succeeded'
  ) $$,
  'a verified webhook applies its PaymentIntent status'
);

select is(
  (select status from public.transactions where stripe_intent_id = 'pi_webhook_test'),
  'succeeded'::public.transaction_status,
  'the webhook updates transaction status'
);

select lives_ok(
  $$ select public.apply_payment_intent_event(
    'evt_webhook_test',
    'payment_intent.succeeded',
    'pi_webhook_test',
    'succeeded'
  ) $$,
  'a duplicate webhook delivery is safe'
);

select ok(
  (select total_lost = 5 from public.profiles where id = '40000000-0000-0000-0000-000000000004')
    and
  (select count(*) = 1 from public.stripe_webhook_events where id = 'evt_webhook_test'),
  'webhook accounting and event recording happen exactly once'
);

select * from finish();
rollback;
