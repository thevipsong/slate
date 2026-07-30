-- Slate cross-device sync: one versioned archive per authenticated user.
-- Run this migration in a dedicated Supabase project.

create table if not exists public.slate_archives (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 1 check (revision > 0),
  archive jsonb not null,
  device_id text not null,
  updated_at timestamptz not null default now()
);

alter table public.slate_archives enable row level security;

revoke all on table public.slate_archives from anon;
grant select, insert, update on table public.slate_archives to authenticated;

create policy "Users read their own Slate archive"
on public.slate_archives
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users create their own Slate archive"
on public.slate_archives
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users update their own Slate archive"
on public.slate_archives
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Optimistic compare-and-swap. A stale client receives the current remote
-- record and must merge/retry instead of silently overwriting another device.
create or replace function public.sync_slate_archive(
  expected_revision bigint,
  new_archive jsonb,
  new_device_id text
)
returns table (
  accepted boolean,
  revision bigint,
  archive jsonb,
  device_id text,
  updated_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if expected_revision = 0 then
    insert into public.slate_archives (
      user_id,
      revision,
      archive,
      device_id,
      updated_at
    )
    values (
      current_user_id,
      1,
      new_archive,
      new_device_id,
      now()
    )
    on conflict (user_id) do nothing;

    if found then
      return query
      select true, row.revision, row.archive, row.device_id, row.updated_at
      from public.slate_archives as row
      where row.user_id = current_user_id;
      return;
    end if;
  else
    update public.slate_archives as row
    set
      revision = row.revision + 1,
      archive = new_archive,
      device_id = new_device_id,
      updated_at = now()
    where row.user_id = current_user_id
      and row.revision = expected_revision;

    if found then
      return query
      select true, row.revision, row.archive, row.device_id, row.updated_at
      from public.slate_archives as row
      where row.user_id = current_user_id;
      return;
    end if;
  end if;

  return query
  select false, row.revision, row.archive, row.device_id, row.updated_at
  from public.slate_archives as row
  where row.user_id = current_user_id;
end;
$$;

revoke all on function public.sync_slate_archive(bigint, jsonb, text) from public, anon;
grant execute on function public.sync_slate_archive(bigint, jsonb, text) to authenticated;
