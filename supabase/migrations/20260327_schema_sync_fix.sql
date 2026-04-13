-- 🚀 PAPYRUS SCHEMA SYNC MIGRATION (COMPLETE VERSION)
-- This script ensures all tables have the exact columns used in the Flutter code.

-- 1. Products Table Sync
alter table products add column if not exists sku text;
alter table products add column if not exists purchase_price numeric(20,2) default 0;
alter table products add column if not exists unit text default 'pcs';
alter table products add column if not exists min_stock numeric(20,2) default 5;
alter table products add column if not exists image_url text;

-- 2. Parties Table Sync
alter table parties add column if not exists phone text;
alter table parties add column if not exists email text;
alter table parties add column if not exists address text;
alter table parties add column if not exists image_url text;
alter table parties add column if not exists type text check (type in ('customer', 'supplier', 'both'));
alter table parties add column if not exists balance numeric(20,2) default 0;

-- 3. Sales/Purchases Sync
alter table sales add column if not exists payment_status text;
alter table purchases add column if not exists payment_status text;

-- 4. Activity Logs Sync
alter table activity_logs add column if not exists entity_type text;
alter table activity_logs add column if not exists entity_id text;

-- 🛠️ IMPORTANT: After running this, wait ~60 seconds for Supabase to refresh its API cache.
