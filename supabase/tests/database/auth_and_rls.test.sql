begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

-- Inserting through auth.users exercises the same profile trigger used by
-- Supabase Auth. Fixed UUIDs make failures readable; the transaction rolls back.
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'owner@example.com',
    crypt('local-password', gen_salt('bf')),
    now(),
    '{"display_name":"Owner User"}'::jsonb,
    now(),
    now()
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'other@example.com',
    crypt('local-password', gen_salt('bf')),
    now(),
    '{"display_name":"Other User"}'::jsonb,
    now(),
    now()
  );

select is(
  (select count(*) from public.profiles),
  2::bigint,
  'signup trigger creates one profile per auth user'
);

select is(
  (
    select display_name
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000001'
  ),
  'Owner User',
  'signup trigger copies display name metadata'
);

select ok(
  (
    select
      not onboarding_complete
      and notifications_enabled
      and sound_enabled
      and haptics_enabled
      and total_earned = 0
      and total_lost = 0
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000001'
  ),
  'new profiles receive application defaults'
);

insert into public.tasks (id, user_id, title, due_date)
values
  (
    '10000000-0000-0000-0000-000000000011',
    '10000000-0000-0000-0000-000000000001',
    'Owner task',
    now() + interval '1 day'
  ),
  (
    '20000000-0000-0000-0000-000000000022',
    '20000000-0000-0000-0000-000000000002',
    'Other task',
    now() + interval '1 day'
  );

insert into public.transactions (user_id, task_id, task_title, type, amount)
values
  (
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000011',
    'Owner task',
    'reward',
    5
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000022',
    'Other task',
    'penalty',
    3
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'an authenticated user sees only their profile'
);

select is(
  (select count(*) from public.tasks),
  1::bigint,
  'an authenticated user sees only their tasks'
);

select is(
  (select count(*) from public.transactions),
  1::bigint,
  'an authenticated user sees only their transactions'
);

select lives_ok(
  $$
    insert into public.tasks (user_id, title, due_date)
    values (
      '10000000-0000-0000-0000-000000000001',
      'New owner task',
      now() + interval '2 days'
    )
  $$,
  'a user can create their own task'
);

select throws_ok(
  $$
    insert into public.tasks (user_id, title, due_date)
    values (
      '20000000-0000-0000-0000-000000000002',
      'Forbidden task',
      now() + interval '2 days'
    )
  $$,
  'a user cannot create a task for another user'
);

select is(
  (
    with changed as (
      update public.tasks
      set title = 'Tampered'
      where id = '20000000-0000-0000-0000-000000000022'
      returning 1
    )
    select count(*) from changed
  ),
  0::bigint,
  'a user cannot update another user task'
);

select is(
  (
    with removed as (
      delete from public.tasks
      where id = '20000000-0000-0000-0000-000000000022'
      returning 1
    )
    select count(*) from removed
  ),
  0::bigint,
  'a user cannot delete another user task'
);

select is(
  (
    with changed as (
      update public.profiles
      set display_name = 'Tampered'
      where id = '20000000-0000-0000-0000-000000000002'
      returning 1
    )
    select count(*) from changed
  ),
  0::bigint,
  'a user cannot update another user profile'
);

select lives_ok(
  $$
    update public.profiles
    set display_name = 'Updated Owner'
    where id = '10000000-0000-0000-0000-000000000001'
  $$,
  'a user can update their own profile'
);

reset role;

select is(
  (
    select display_name
    from public.profiles
    where id = '10000000-0000-0000-0000-000000000001'
  ),
  'Updated Owner',
  'the permitted profile update is persisted'
);

delete from auth.users
where id = '20000000-0000-0000-0000-000000000002';

select is(
  (
    select count(*)
    from public.profiles
    where id = '20000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'deleting an auth user cascades to their profile'
);

select is(
  (
    select count(*)
    from public.tasks
    where user_id = '20000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'deleting an auth user cascades through profile-owned tasks'
);

select * from finish();
rollback;
