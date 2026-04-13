-- 🚀 PAPYRUS TRANSACTIONS TABLE FIX
-- Creates the 'transactions' table (for income/expense/wallet tracking)
-- and disables RLS to match all other business tables.

-- 1. Create the transactions table if it doesn't exist
create table if not exists transactions (
    id uuid default gen_random_uuid() primary key,
    shop_id uuid references shops(id) on delete cascade not null,
    wallet_id uuid references wallets(id) on delete set null,
    type text not null check (type in ('income', 'expense')),
    amount numeric(20,2) default 0,
    category text,
    note text,
    created_at timestamptz default now()
);

-- 2. Disable RLS (consistent with all other business tables)
alter table transactions disable row level security;

-- 3. Index for fast lookups
create index if not exists idx_transactions_shop_id on transactions(shop_id);
create index if not exists idx_transactions_wallet_id on transactions(wallet_id);
create index if not exists idx_transactions_type on transactions(shop_id, type);
