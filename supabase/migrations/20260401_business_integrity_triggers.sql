-- 🚀 PAPYRUS CORE SECURITY & BUSINESS INTEGRITY MIGRATION
-- 1. Full RLS Policies for all Shop-related tables
-- 2. Automatic Atomic Stock Management (via Triggers)
-- 3. Automatic Wallet Balance Management (via Triggers)
-- 4. Automatic Party Balance Management (via Triggers)

-- =============================================
-- HELPER FUNCTION FOR RLS
-- =============================================

CREATE OR REPLACE FUNCTION fix_shop_security(target_table text) RETURNS void AS $$
BEGIN
    execute format('alter table %I enable row level security', target_table);
    
    execute format('drop policy if exists "%I_select" on %I', target_table, target_table);
    execute format('create policy "%I_select" on %I for select to authenticated using (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
        or
        exists (select 1 from shop_members where shop_members.shop_id = %I.shop_id and shop_members.user_id = auth.uid())
    )', target_table, target_table, target_table, target_table);

    execute format('drop policy if exists "%I_insert" on %I', target_table, target_table);
    execute format('create policy "%I_insert" on %I for insert to authenticated with check (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
        or
        exists (select 1 from shop_members where shop_members.shop_id = %I.shop_id and shop_members.user_id = auth.uid())
    )', target_table, target_table, target_table, target_table);

    execute format('drop policy if exists "%I_update" on %I', target_table, target_table);
    execute format('create policy "%I_update" on %I for update to authenticated using (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
        or
        exists (select 1 from shop_members where shop_members.shop_id = %I.shop_id and shop_members.user_id = auth.uid())
    )', target_table, target_table, target_table, target_table);

    execute format('drop policy if exists "%I_delete" on %I', target_table, target_table);
    execute format('create policy "%I_delete" on %I for delete to authenticated using (
        exists (select 1 from shops where shops.id = %I.shop_id and shops.owner_user_id = auth.uid())
    )', target_table, target_table, target_table);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- RLS POLICIES FOR SHOP ACCESS
-- =============================================

DO $$
BEGIN
    -- These tables have a direct 'shop_id' column
    PERFORM fix_shop_security('products');
    PERFORM fix_shop_security('categories');
    PERFORM fix_shop_security('parties');
    PERFORM fix_shop_security('wallets');
    PERFORM fix_shop_security('transactions');
    PERFORM fix_shop_security('purchases');
    PERFORM fix_shop_security('sales');
    PERFORM fix_shop_security('ledger_entries');
    PERFORM fix_shop_security('returns');
    PERFORM fix_shop_security('activity_logs');
    PERFORM fix_shop_security('notifications');

    -- Special handling for tables WITHOUT direct 'shop_id'
    
    -- 1. PURCHASE_ITEMS (Links via purchases.shop_id)
    ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "purchase_items_select" ON purchase_items;
    CREATE POLICY "purchase_items_select" ON purchase_items FOR SELECT TO authenticated USING (
        EXISTS (SELECT 1 FROM purchases p JOIN shops s ON p.shop_id = s.id WHERE p.id = purchase_items.purchase_id AND (s.owner_user_id = auth.uid() OR EXISTS (SELECT 1 FROM shop_members sm WHERE sm.shop_id = s.id AND sm.user_id = auth.uid())))
    );
    DROP POLICY IF EXISTS "purchase_items_insert" ON purchase_items;
    CREATE POLICY "purchase_items_insert" ON purchase_items FOR INSERT TO authenticated WITH CHECK (
        EXISTS (SELECT 1 FROM purchases p JOIN shops s ON p.shop_id = s.id WHERE p.id = purchase_items.purchase_id AND (s.owner_user_id = auth.uid() OR EXISTS (SELECT 1 FROM shop_members sm WHERE sm.shop_id = s.id AND sm.user_id = auth.uid())))
    );
    DROP POLICY IF EXISTS "purchase_items_delete" ON purchase_items;
    CREATE POLICY "purchase_items_delete" ON purchase_items FOR DELETE TO authenticated USING (
        EXISTS (SELECT 1 FROM purchases p JOIN shops s ON p.shop_id = s.id WHERE p.id = purchase_items.purchase_id AND s.owner_user_id = auth.uid())
    );

    -- 2. SALE_ITEMS (Links via sales.shop_id)
    ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "sale_items_select" ON sale_items;
    CREATE POLICY "sale_items_select" ON sale_items FOR SELECT TO authenticated USING (
        EXISTS (SELECT 1 FROM sales sa JOIN shops s ON sa.shop_id = s.id WHERE sa.id = sale_items.sale_id AND (s.owner_user_id = auth.uid() OR EXISTS (SELECT 1 FROM shop_members sm WHERE sm.shop_id = s.id AND sm.user_id = auth.uid())))
    );
    DROP POLICY IF EXISTS "sale_items_insert" ON sale_items;
    CREATE POLICY "sale_items_insert" ON sale_items FOR INSERT TO authenticated WITH CHECK (
        EXISTS (SELECT 1 FROM sales sa JOIN shops s ON sa.shop_id = s.id WHERE sa.id = sale_items.sale_id AND (s.owner_user_id = auth.uid() OR EXISTS (SELECT 1 FROM shop_members sm WHERE sm.shop_id = s.id AND sm.user_id = auth.uid())))
    );
    DROP POLICY IF EXISTS "sale_items_delete" ON sale_items;
    CREATE POLICY "sale_items_delete" ON sale_items FOR DELETE TO authenticated USING (
        EXISTS (SELECT 1 FROM sales sa JOIN shops s ON sa.shop_id = s.id WHERE sa.id = sale_items.sale_id AND s.owner_user_id = auth.uid())
    );

END $$;

-- =============================================
-- STOCK MANAGEMENT TRIGGERS (ATOMIC)
-- =============================================

CREATE OR REPLACE FUNCTION handle_stock_operation()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_TABLE_NAME = 'purchase_items') THEN
        IF (TG_OP = 'INSERT') THEN
            UPDATE products SET stock = stock + NEW.quantity WHERE id = NEW.product_id;
        ELSIF (TG_OP = 'DELETE') THEN
            UPDATE products SET stock = stock - OLD.quantity WHERE id = OLD.product_id;
        END IF;
    ELSIF (TG_TABLE_NAME = 'sale_items') THEN
        IF (TG_OP = 'INSERT') THEN
            UPDATE products SET stock = stock - NEW.quantity WHERE id = NEW.product_id;
        ELSIF (TG_OP = 'DELETE') THEN
            UPDATE products SET stock = stock + OLD.quantity WHERE id = OLD.product_id;
        END IF;
    ELSIF (TG_TABLE_NAME = 'returns') THEN
        IF (TG_OP = 'INSERT') THEN
            -- In 'returns' table, we handle both sale returns (increase stock) and purchase returns (decrease)
            IF (NEW.type = 'sale') THEN
                UPDATE products SET stock = stock + COALESCE(NEW.quantity, 0) WHERE id = NEW.product_id;
            ELSIF (NEW.type = 'purchase') THEN
                UPDATE products SET stock = stock - COALESCE(NEW.quantity, 0) WHERE id = NEW.product_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Activation for Stock
DROP TRIGGER IF EXISTS trg_purchase_stock ON purchase_items;
CREATE TRIGGER trg_purchase_stock AFTER INSERT OR DELETE ON purchase_items FOR EACH ROW EXECUTE FUNCTION handle_stock_operation();

DROP TRIGGER IF EXISTS trg_sale_stock ON sale_items;
CREATE TRIGGER trg_sale_stock AFTER INSERT OR DELETE ON sale_items FOR EACH ROW EXECUTE FUNCTION handle_stock_operation();

-- =============================================
-- WALLET BALANCE TRIGGERS (ATOMIC)
-- =============================================

CREATE OR REPLACE FUNCTION handle_wallet_operation()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.type = 'income') THEN
            UPDATE wallets SET balance = balance + NEW.amount WHERE id = NEW.wallet_id;
        ELSIF (NEW.type = 'expense') THEN
            UPDATE wallets SET balance = balance - NEW.amount WHERE id = NEW.wallet_id;
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        IF (OLD.type = 'income') THEN
            UPDATE wallets SET balance = balance - OLD.amount WHERE id = OLD.wallet_id;
        ELSIF (OLD.type = 'expense') THEN
            UPDATE wallets SET balance = balance + OLD.amount WHERE id = OLD.wallet_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_wallet_balance ON transactions;
CREATE TRIGGER trg_wallet_balance AFTER INSERT OR DELETE ON transactions FOR EACH ROW EXECUTE FUNCTION handle_wallet_operation();

-- =============================================
-- PARTY BALANCE TRIGGERS (ATOMIC)
-- =============================================

CREATE OR REPLACE FUNCTION handle_party_balance_operation()
RETURNS TRIGGER AS $$
BEGIN
    -- types: 'due' (debt we owe), 'loan' (debt customer owes us), 'payment_received', 'payment_made'
    -- party.balance is treated as "Net Balance" (Positive is receivable, Negative is payable)
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.type IN ('loan', 'payment_made')) THEN
            UPDATE parties SET balance = balance + NEW.amount WHERE id = NEW.party_id;
        ELSIF (NEW.type IN ('due', 'payment_received')) THEN
            UPDATE parties SET balance = balance - NEW.amount WHERE id = NEW.party_id;
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        IF (OLD.type IN ('loan', 'payment_made')) THEN
            UPDATE parties SET balance = balance - OLD.amount WHERE id = OLD.party_id;
        ELSIF (OLD.type IN ('due', 'payment_received')) THEN
            UPDATE parties SET balance = balance + OLD.amount WHERE id = OLD.party_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_party_balance ON ledger_entries;
CREATE TRIGGER trg_party_balance AFTER INSERT OR DELETE ON ledger_entries FOR EACH ROW EXECUTE FUNCTION handle_party_balance_operation();
