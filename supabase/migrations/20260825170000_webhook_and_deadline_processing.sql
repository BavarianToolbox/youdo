create table public.stripe_webhook_events (
  id text primary key,
  event_type text not null,
  stripe_intent_id text not null,
  processed_at timestamptz not null default now()
);

revoke all on public.stripe_webhook_events from anon, authenticated;
grant all on public.stripe_webhook_events to service_role;

create function public.apply_payment_intent_event(
  p_event_id text,
  p_event_type text,
  p_stripe_intent_id text,
  p_status public.transaction_status
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  transaction_row public.transactions%rowtype;
  inserted_count integer;
begin
  select * into transaction_row
  from public.transactions
  where stripe_intent_id = p_stripe_intent_id
  for update;

  if not found then
    raise exception 'Transaction not found for Stripe intent %', p_stripe_intent_id;
  end if;

  insert into public.stripe_webhook_events (id, event_type, stripe_intent_id)
  values (p_event_id, p_event_type, p_stripe_intent_id)
  on conflict (id) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count = 0 then return; end if;

  update public.transactions
  set status = p_status
  where id = transaction_row.id;

  if p_status = 'succeeded' and transaction_row.status <> 'succeeded' then
    update public.profiles
    set total_lost = total_lost + transaction_row.amount
    where id = transaction_row.user_id;
  end if;
end;
$$;

create function public.claim_overdue_tasks(p_limit integer default 100)
returns setof public.tasks
language sql
security definer
set search_path = ''
as $$
  with claimed as (
    select id
    from public.tasks
    where status = 'pending'
      and due_date < clock_timestamp()
      and deadline_processed = false
    order by due_date
    for update skip locked
    limit greatest(1, least(p_limit, 500))
  )
  update public.tasks as task
  set status = 'missed', deadline_processed = true
  from claimed
  where task.id = claimed.id
  returning task.*;
$$;

create or replace function public.record_task_penalty(
  p_user_id uuid,
  p_task_id uuid,
  p_stripe_intent_id text,
  p_status public.transaction_status
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  task_row public.tasks%rowtype;
  inserted_count integer;
begin
  select * into task_row
  from public.tasks
  where id = p_task_id and user_id = p_user_id
  for update;

  if not found then raise exception 'Task not found'; end if;
  if task_row.status = 'missed' then
    if task_row.due_date >= clock_timestamp() then
      raise exception 'Task deadline has not passed';
    end if;
  elsif task_row.completed_at is null or task_row.completed_at <= task_row.due_date then
    raise exception 'Task was not completed late';
  end if;
  if task_row.status not in ('completed_on_time', 'completed_late', 'missed') then
    raise exception 'Task cannot receive a penalty from status %', task_row.status;
  end if;

  insert into public.transactions (
    user_id, task_id, task_title, type, amount, status, stripe_intent_id
  ) values (
    p_user_id, task_row.id, task_row.title, 'penalty', task_row.penalty_amount,
    p_status, p_stripe_intent_id
  ) on conflict (task_id, type) where task_id is not null do nothing;

  get diagnostics inserted_count = row_count;
  if inserted_count = 1 and p_status = 'succeeded' then
    update public.profiles
    set total_lost = total_lost + task_row.penalty_amount
    where id = p_user_id;
  end if;
end;
$$;

revoke all on function public.apply_payment_intent_event(text, text, text, public.transaction_status)
  from public, anon, authenticated;
revoke all on function public.claim_overdue_tasks(integer) from public, anon, authenticated;
grant execute on function public.apply_payment_intent_event(text, text, text, public.transaction_status)
  to service_role;
grant execute on function public.claim_overdue_tasks(integer) to service_role;
