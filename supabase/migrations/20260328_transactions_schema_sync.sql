-- 🚀 PAPYRUS TRANSACTIONS SCHEMA SYNC
-- Adds all missing columns to purchases and sales tables
-- that the Flutter app expects to insert/read.

-- =============================================
-- PURCHASES TABLE
-- =============================================
alter table purchases add column if not exists supplier_id uuid references parties(id);
alter table purchases add column if not exists supplier_name text;
alter table purchases add column if not exists invoice_number text;
alter table purchases add column if not exists due_amount numeric(20,2) default 0;
alter table purchases add column if not exists vat_amount numeric(20,2) default 0;
alter table purchases add column if not exists shipping_cost numeric(20,2) default 0;
alter table purchases add column if not exists other_cost numeric(20,2) default 0;
alter table purchases add column if not exists discount numeric(20,2) default 0;
alter table purchases add column if not exists notes text;

-- =============================================
-- PURCHASE ITEMS TABLE
-- =============================================
create table if not exists purchase_items (
    id uuid default gen_random_uuid() primary key,
    purchase_id uuid references purchases(id) on delete cascade not null,
    product_id uuid references products(id),
    product_name text,
    quantity numeric(20,2) default 0,
    price numeric(20,2) default 0,
    created_at timestamptz default now()
);
alter table purchase_items disable row level security;

-- =============================================
-- SALES TABLE
-- =============================================
alter table sales add column if not exists customer_id uuid references parties(id);
alter table sales add column if not exists customer_name text;
alter table sales add column if not exists invoice_number text;
alter table sales add column if not exists due_amount numeric(20,2) default 0;
alter table sales add column if not exists vat_amount numeric(20,2) default 0;
alter table sales add column if not exists profit numeric(20,2) default 0;
alter table sales add column if not exists shipping_cost numeric(20,2) default 0;
alter table sales add column if not exists other_cost numeric(20,2) default 0;
alter table sales add column if not exists discount numeric(20,2) default 0;
alter table sales add column if not exists notes text;

-- =============================================
-- SALE ITEMS TABLE
-- =============================================
create table if not exists sale_items (
    id uuid default gen_random_uuid() primary key,
    sale_id uuid references sales(id) on delete cascade not null,
    product_id uuid references products(id),
    product_name text,
    quantity numeric(20,2) default 0,
    price numeric(20,2) default 0,
    cost_price numeric(20,2) default 0,
    created_at timestamptz default now()
);
alter table sale_items disable row level security;

-- =============================================
-- LEDGER ENTRIES TABLE
-- =============================================
create table if not exists ledger_entries (
    id uuid default gen_random_uuid() primary key,
    shop_id uuid references shops(id) on delete cascade not null,
    party_id uuid references parties(id),
    party_name text,
    type text, -- 'due', 'loan', 'payment_received', 'payment_made'
    amount numeric(20,2) default 0,
    reference_type text, -- 'sale', 'purchase', 'manual'
    reference_id uuid,
    notes text,
    created_at timestamptz default now()
);
alter table ledger_entries disable row level security;

-- =============================================
-- DISABLE RLS on all transaction tables
-- (consistent with the rescue migration pattern)
-- =============================================
alter table purchases disable row level security;
alter table sales disable row level security;

-- =============================================
-- INDEXES for performance
-- =============================================
create index if not exists idx_purchase_items_purchase_id on purchase_items(purchase_id);
create index if not exists idx_sale_items_sale_id on sale_items(sale_id);
create index if not exists idx_ledger_entries_shop_id on ledger_entries(shop_id);
create index if not exists idx_ledger_entries_party_id on ledger_entries(party_id);

-- 🛠️ Wait ~60 seconds after running for the Supabase schema cache to refresh.
