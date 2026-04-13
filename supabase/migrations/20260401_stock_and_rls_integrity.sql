-- 🚀 PAPYRUS CORE SECURITY & STOCK INTEGRITY MIGRATION
-- 1. Enable RLS and add comprehensive policies for all transaction-related tables
-- 2. Implement robust database triggers for automatic stock management

-- =============================================
-- RLS POLICIES FOR TRANSACTION TABLES
-- =============================================

DO $$
BEGIN
    -- Tables to apply policies to:
    -- purchases, purchase_items, sales, sale_items, ledger_entries, transactions, wallets, returns, categories, products

    -- Helper for repetitive policy creation
    -- Each policy follows the rule:
    -- SELECT: User is Owner OR User is Member of the shop
    -- INSERT: User is Owner OR User is Member of the shop
    -- UPDATE: User is Owner OR User is Member of the shop
    -- DELETE: User is Owner

    -- 1. PURCHASES & ITEMS
    PERFORM fix_shop_rls('purchases');
    PERFORM fix_shop_rls('purchase_items');
    
    -- 2. SALES & ITEMS
    PERFORM fix_shop_rls('sales');
    PERFORM fix_shop_rls('sale_items');
    
    -- 3. LEDGER & TRANSACTIONS
    PERFORM fix_shop_rls('ledger_entries');
    PERFORM fix_shop_rls('transactions');
    PERFORM fix_shop_rls('wallets');
    
    -- 4. INVENTORY
    PERFORM fix_shop_rls('products');
    PERFORM fix_shop_rls('categories');
    
    -- 5. RETURNS
    PERFORM fix_shop_rls('returns');

END $$;

-- Define a helper function for RLS (Internal use during migration)
CREATE OR REPLACE FUNCTION fix_shop_rls(target_table text) RETURNS void AS $$
BEGIN
    execute format('alter table %I enable row level security', target_table);
    
    execute format('drop policy if exists "%I_select_policy" on %I', target_table, target_table);
    execute format('create policy "%I_select_policy" on %I for select to authenticated using (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
        or
        exists (select 1 from shop_members where shop_members.shop_id = %I.shop_id and shop_members.user_id = auth.uid())
    )', target_table, target_table, target_table, target_table);

    execute format('drop policy if exists "%I_insert_policy" on %I', target_table, target_table);
    execute format('create policy "%I_insert_policy" on %I for insert to authenticated with check (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
        or
        exists (select 1 from shop_members where shop_members.shop_id = %I.shop_id and shop_members.user_id = auth.uid())
    )', target_table, target_table, target_table, target_table);

    execute format('drop policy if exists "%I_update_policy" on %I', target_table, target_table);
    execute format('create policy "%I_update_policy" on %I for update to authenticated using (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
        or
        exists (select 1 from shop_members where shop_members.shop_id = %I.shop_id and shop_members.user_id = auth.uid())
    )', target_table, target_table, target_table, target_table);

    execute format('drop policy if exists "%I_delete_policy" on %I', target_table, target_table);
    execute format('create policy "%I_delete_policy" on %I for delete to authenticated using (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
    )', target_table, target_table, target_table);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- AUTOMATIC STOCK MANAGEMENT TRIGGERS
-- =============================================

-- Function to handle stock updates
CREATE OR REPLACE FUNCTION update_stock_from_transaction_items()
RETURNS TRIGGER AS $$
DECLARE
    delta NUMERIC;
BEGIN
    IF (TG_TABLE_NAME = 'purchase_items') THEN
        IF (TG_OP = 'INSERT') THEN
            delta := NEW.quantity;
            UPDATE products SET stock = stock + delta WHERE id = NEW.product_id;
        ELSIF (TG_OP = 'DELETE') THEN
            delta := OLD.quantity;
            UPDATE products SET stock = stock - delta WHERE id = OLD.product_id;
        END IF;
    ELSIF (TG_TABLE_NAME = 'sale_items') THEN
        IF (TG_OP = 'INSERT') THEN
            delta := NEW.quantity;
            UPDATE products SET stock = stock - delta WHERE id = NEW.product_id;
        ELSIF (TG_OP = 'DELETE') THEN
            delta := OLD.quantity;
            UPDATE products SET stock = stock + delta WHERE id = OLD.product_id;
        END IF;
    ELSIF (TG_TABLE_NAME = 'returns') THEN
        -- Returns logic: 
        -- sale return = increase stock
        -- purchase return = decrease stock
        IF (TG_OP = 'INSERT') THEN
            IF (NEW.type = 'sale') THEN
                UPDATE products SET stock = stock + NEW.quantity WHERE id = NEW.product_id;
            ELSIF (NEW.type = 'purchase') THEN
                UPDATE products SET stock = stock - NEW.quantity WHERE id = NEW.product_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Triggers
DROP TRIGGER IF EXISTS trg_purchase_stock_update ON purchase_items;
CREATE TRIGGER trg_purchase_stock_update
AFTER INSERT OR DELETE ON purchase_items
FOR EACH ROW EXECUTE FUNCTION update_stock_from_transaction_items();

DROP TRIGGER IF EXISTS trg_sale_stock_update ON sale_items;
CREATE TRIGGER trg_sale_stock_update
AFTER INSERT OR DELETE ON sale_items
FOR EACH ROW EXECUTE FUNCTION update_stock_from_transaction_items();

-- Fix returns table if quantity/product_id is missing (Schema Check)
ALTER TABLE returns ADD COLUMN IF NOT EXISTS quantity NUMERIC DEFAULT 0;
ALTER TABLE returns ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id);

DROP TRIGGER IF EXISTS trg_returns_stock_update ON returns;
CREATE TRIGGER trg_returns_stock_update
AFTER INSERT ON returns
FOR EACH ROW EXECUTE FUNCTION update_stock_from_transaction_items();
