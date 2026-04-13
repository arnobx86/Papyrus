-- Enable Row Level Security (RLS) on all remaining public tables to secure them.
-- This fixes the 'policy_exists_rls_disabled' and 'rls_disabled_in_public' linter errors.

do $$
begin
  -- Core Tables
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'categories') then
    alter table public.categories enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'parties') then
    alter table public.parties enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'wallets') then
    alter table public.wallets enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'transactions') then
    alter table public.transactions enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'ledger_entries') then
    alter table public.ledger_entries enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'roles') then
    alter table public.roles enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'purchase_items') then
    alter table public.purchase_items enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'sale_items') then
    alter table public.sale_items enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'returns') then
    alter table public.returns enable row level security;
  end if;

  if exists (select from pg_tables where schemaname = 'public' and tablename = 'notifications') then
    alter table public.notifications enable row level security;
  end if;

end $$;
