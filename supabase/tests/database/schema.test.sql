begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'tasks', 'tasks table exists');
select has_table('public', 'transactions', 'transactions table exists');

select has_column('public', 'profiles', 'id', 'profiles has an id');
select has_column('public', 'tasks', 'user_id', 'tasks belong to a user');
select has_column('public', 'tasks', 'due_date', 'tasks have a deadline');
select has_column('public', 'transactions', 'task_id', 'transactions reference tasks');

select col_is_pk('public', 'profiles', 'id', 'profiles id is primary key');
select col_is_pk('public', 'tasks', 'id', 'tasks id is primary key');
select col_is_pk('public', 'transactions', 'id', 'transactions id is primary key');

select has_fk('public', 'profiles', 'profiles references auth users');
select has_fk('public', 'tasks', 'tasks reference profiles');
select has_fk('public', 'transactions', 'transactions reference users/tasks');

select policies_are(
  'public',
  'profiles',
  array['profiles_select_own', 'profiles_update_own'],
  'profiles has only owner policies'
);
select policies_are(
  'public',
  'tasks',
  array['tasks_delete_own', 'tasks_insert_own', 'tasks_select_own', 'tasks_update_own'],
  'tasks has owner CRUD policies'
);
select policies_are(
  'public',
  'transactions',
  array['transactions_select_own'],
  'transactions are client read-only'
);

select * from finish();
rollback;
