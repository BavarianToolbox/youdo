begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at
) values (
  '30000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'payments@example.com',
  crypt('local-password', gen_salt('bf')),
  now(),
  '{"display_name":"Payment User"}'::jsonb,
  now(),
  now()
);

insert into public.tasks (
  id, user_id, title, due_date, reward_amount, penalty_amount
) values
  (
    '30000000-0000-0000-0000-000000000031',
    '30000000-0000-0000-0000-000000000003',
    'On-time task',
    now() + interval '1 hour',
    10,
    5
  ),
  (
    '30000000-0000-0000-0000-000000000032',
    '30000000-0000-0000-0000-000000000003',
    'Late task',
    now() - interval '1 hour',
    10,
    5
  );

select is(
  (public.complete_task(
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000031'
  )).status,
  'completed_on_time'::public.task_status,
  'completion status is assigned from the server clock'
);

select ok(
  (select completed_at is not null from public.tasks where id = '30000000-0000-0000-0000-000000000031'),
  'completion records a server timestamp'
);

select lives_ok(
  $$ select public.apply_task_reward(
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000031'
  ) $$,
  'an on-time reward is applied'
);

select lives_ok(
  $$ select public.apply_task_reward(
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000031'
  ) $$,
  'reapplying an on-time reward is safe'
);

select is(
  (select count(*) from public.transactions where task_id = '30000000-0000-0000-0000-000000000031'),
  1::bigint,
  'a retry does not duplicate the reward transaction'
);

select is(
  (select yd_balance from public.profiles where id = '30000000-0000-0000-0000-000000000003'),
  10.00::numeric,
  'a retry does not duplicate reward credit'
);

select is(
  (select total_earned from public.profiles where id = '30000000-0000-0000-0000-000000000003'),
  10.00::numeric,
  'a reward updates total earned once'
);

select is(
  (public.complete_task(
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000032'
  )).status,
  'completed_late'::public.task_status,
  'an overdue task is completed late'
);

select lives_ok(
  $$ select public.record_task_penalty(
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000032',
    'pi_test_payment_functions',
    'succeeded'
  ) $$,
  'a successful penalty is recorded'
);

select lives_ok(
  $$ select public.record_task_penalty(
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000032',
    'pi_test_payment_functions',
    'succeeded'
  ) $$,
  're-recording a penalty is safe'
);

select ok(
  (select count(*) = 1 from public.transactions where task_id = '30000000-0000-0000-0000-000000000032')
    and
  (select total_lost = 5 from public.profiles where id = '30000000-0000-0000-0000-000000000003'),
  'a retry does not duplicate the penalty or total lost'
);

select * from finish();
rollback;
