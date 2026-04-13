-- 🚀 PAPYRUS WALLETS TABLE FIX
-- Ensures the wallets table exists and has RLS disabled,
-- matching the security model used by all other business tables.

-- 1. Create wallets table if it doesn't exist
create table if not exists wallets (
    id uuid default gen_random_uuid() primary key,
    shop_id uuid references shops(id) on delete cascade not null,
    name text not null,
    balance numeric(20,2) default 0,
    created_at timestamptz default now()
);

-- 2. Disable RLS (consistent with products, parties, sales, etc.)
alter table wallets disable row level security;

-- 3. Add index for fast shop-based lookups
create index if not exists idx_wallets_shop_id on wallets(shop_id);
