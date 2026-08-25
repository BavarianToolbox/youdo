alter table public.profiles
  add column yd_balance numeric(12, 2) not null default 0 check (yd_balance >= 0);

revoke update on public.profiles from authenticated;
grant update (
  display_name,
  onboarding_complete,
  notifications_enabled,
  sound_enabled,
  haptics_enabled
) on public.profiles to authenticated;

revoke insert, update on public.tasks from authenticated;
grant insert (
  id, user_id, title, description, due_date, reward_amount, penalty_amount
) on public.tasks to authenticated;
grant update (
  title, description, due_date, reward_amount, penalty_amount, notification_scheduled
) on public.tasks to authenticated;

create unique index transactions_task_type_idx
  on public.transactions (task_id, type)
  where task_id is not null;

create function public.complete_task(p_user_id uuid, p_task_id uuid)
returns public.tasks
language plpgsql
security definer
set search_path = ''
as $$
declare
  task_row public.tasks%rowtype;
begin
  select * into task_row
  from public.tasks
  where id = p_task_id and user_id = p_user_id
  for update;

  if not found then return null; end if;
  if task_row.status = 'pending' then
    update public.tasks
    set completed_at = clock_timestamp(),
        status = case
          when clock_timestamp() <= due_date then 'completed_on_time'::public.task_status
          else 'completed_late'::public.task_status
        end
    where id = task_row.id
    returning * into task_row;
  elsif task_row.status not in ('completed_on_time', 'completed_late') then
    raise exception 'Task cannot be completed from status %', task_row.status;
  end if;
  return task_row;
end;
$$;

create function public.apply_task_reward(p_user_id uuid, p_task_id uuid)
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
  if task_row.completed_at is null or task_row.completed_at > task_row.due_date then
    raise exception 'Task was not completed on time';
  end if;
  if task_row.status not in ('completed_on_time', 'completed_late') then
    raise exception 'Task is not complete';
  end if;

  insert into public.transactions (
    user_id, task_id, task_title, type, amount, status
  ) values (
    p_user_id, task_row.id, task_row.title, 'reward', task_row.reward_amount, 'succeeded'
  ) on conflict (task_id, type) where task_id is not null do nothing;

  get diagnostics inserted_count = row_count;
  if inserted_count = 1 then
    update public.profiles
    set yd_balance = yd_balance + task_row.reward_amount,
        total_earned = total_earned + task_row.reward_amount
    where id = p_user_id;
  end if;
end;
$$;

create function public.record_task_penalty(
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
  if task_row.completed_at is null or task_row.completed_at <= task_row.due_date then
    raise exception 'Task was not completed late';
  end if;
  if task_row.status not in ('completed_on_time', 'completed_late') then
    raise exception 'Task is not complete';
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

revoke all on function public.apply_task_reward(uuid, uuid) from public, anon, authenticated;
revoke all on function public.complete_task(uuid, uuid) from public, anon, authenticated;
revoke all on function public.record_task_penalty(uuid, uuid, text, public.transaction_status)
  from public, anon, authenticated;
grant execute on function public.apply_task_reward(uuid, uuid) to service_role;
grant execute on function public.complete_task(uuid, uuid) to service_role;
grant execute on function public.record_task_penalty(uuid, uuid, text, public.transaction_status)
  to service_role;
