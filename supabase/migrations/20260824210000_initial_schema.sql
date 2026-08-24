create type public.task_status as enum (
  'pending',
  'completed_on_time',
  'completed_late',
  'missed'
);

create type public.transaction_type as enum ('reward', 'penalty');
create type public.transaction_status as enum ('pending', 'succeeded', 'failed');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text not null default '',
  stripe_customer_id text,
  stripe_payment_method_id text,
  has_payment_method boolean not null default false,
  onboarding_complete boolean not null default false,
  notifications_enabled boolean not null default true,
  sound_enabled boolean not null default true,
  haptics_enabled boolean not null default true,
  total_earned numeric(12, 2) not null default 0 check (total_earned >= 0),
  total_lost numeric(12, 2) not null default 0 check (total_lost >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text,
  due_date timestamptz not null,
  reward_amount numeric(12, 2) not null default 0 check (reward_amount >= 0),
  penalty_amount numeric(12, 2) not null default 0 check (penalty_amount >= 0),
  status public.task_status not null default 'pending',
  completed_at timestamptz,
  deadline_processed boolean not null default false,
  notification_scheduled boolean not null default false,
  stripe_payment_intent_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  task_id uuid references public.tasks (id) on delete set null,
  task_title text not null default '',
  type public.transaction_type not null,
  amount numeric(12, 2) not null check (amount >= 0),
  status public.transaction_status not null default 'pending',
  stripe_intent_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_user_due_date_idx on public.tasks (user_id, due_date);
create index tasks_pending_deadline_idx
  on public.tasks (due_date)
  where status = 'pending' and deadline_processed = false;
create index transactions_user_created_at_idx
  on public.transactions (user_id, created_at desc);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

create trigger transactions_set_updated_at
before update on public.transactions
for each row execute function public.set_updated_at();

create function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  return new;
end;
$$;

create trigger create_profile_after_signup
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.transactions enable row level security;

create policy "profiles_select_own"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

create policy "profiles_update_own"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "tasks_select_own"
on public.tasks for select to authenticated
using ((select auth.uid()) = user_id);

create policy "tasks_insert_own"
on public.tasks for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "tasks_update_own"
on public.tasks for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "tasks_delete_own"
on public.tasks for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "transactions_select_own"
on public.transactions for select to authenticated
using ((select auth.uid()) = user_id);

grant usage on schema public to authenticated, service_role;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.tasks to authenticated;
grant select on public.transactions to authenticated;
grant all on public.profiles, public.tasks, public.transactions to service_role;

alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.transactions;
