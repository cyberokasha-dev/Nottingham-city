-- Account-owned game saves. Only the authenticated server writes revisions and leases.
create table if not exists public.city_accounts (
 id uuid primary key references auth.users(id) on delete cascade,
 state jsonb not null check (jsonb_typeof(state) = 'object'),
 revision bigint not null default 1 check (revision > 0),
 writer text not null default '',
 lease_until timestamptz not null default '1970-01-01T00:00:00Z',
 current_peer text not null default '',
 updated_at timestamptz not null default now()
);
alter table public.city_accounts enable row level security;
revoke all on public.city_accounts from anon, authenticated;
grant select on public.city_accounts to authenticated;
grant all on public.city_accounts to service_role;
create policy city_account_owner_read on public.city_accounts for select to authenticated
 using ((select auth.uid()) = id);
