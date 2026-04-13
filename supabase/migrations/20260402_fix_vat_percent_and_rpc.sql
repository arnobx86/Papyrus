-- 🚀 COMPREHENSIVE FIX FOR VAT_PERCENT COLUMN
-- This migration:
-- 1. Ensures vat_percent column exists in purchases and sales tables
-- 2. Creates RPC functions to bypass PostgREST schema cache

-- Step 1: Add vat_percent column to purchases table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchases' AND column_name = 'vat_percent'
    ) THEN
        ALTER TABLE purchases ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
        RAISE NOTICE 'Added vat_percent column to purchases table';
    ELSE
        RAISE NOTICE 'vat_percent column already exists in purchases table';
    END IF;
END $$;

-- Step 2: Add vat_percent column to sales table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sales' AND column_name = 'vat_percent'
    ) THEN
        ALTER TABLE sales ADD COLUMN vat_percent NUMERIC(5,2) DEFAULT 0;
        RAISE NOTICE 'Added vat_percent column to sales table';
    ELSE
        RAISE NOTICE 'vat_percent column already exists in sales table';
    END IF;
END $$;

-- Step 3: Create RPC function to insert purchase
CREATE OR REPLACE FUNCTION insert_purchase(
    p_shop_id UUID,
    p_supplier_id UUID,
    p_supplier_name TEXT,
    p_invoice_number TEXT,
    p_total_amount NUMERIC,
    p_paid_amount NUMERIC,
    p_due_amount NUMERIC,
    p_vat_amount NUMERIC,
    p_vat_percent NUMERIC,
    p_shipping_cost NUMERIC,
    p_other_cost NUMERIC,
    p_discount NUMERIC,
    p_notes TEXT,
    p_created_at TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_purchase_id UUID;
    v_result JSONB;
BEGIN
    -- Insert into purchases table
    INSERT INTO purchases (
        shop_id,
        supplier_id,
        supplier_name,
        invoice_number,
        total_amount,
        paid_amount,
        due_amount,
        vat_amount,
        vat_percent,
        shipping_cost,
        other_cost,
        discount,
        notes,
        created_at
    ) VALUES (
        p_shop_id,
        p_supplier_id,
        p_supplier_name,
        p_invoice_number,
        p_total_amount,
        p_paid_amount,
        p_due_amount,
        p_vat_amount,
        p_vat_percent,
        p_shipping_cost,
        p_other_cost,
        p_discount,
        p_notes,
        p_created_at::timestamp
    )
    RETURNING row_to_json(purchases.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Step 4: Create RPC function to update purchase
CREATE OR REPLACE FUNCTION update_purchase(
    p_purchase_id UUID,
    p_supplier_id UUID,
    p_supplier_name TEXT,
    p_invoice_number TEXT,
    p_total_amount NUMERIC,
    p_paid_amount NUMERIC,
    p_due_amount NUMERIC,
    p_vat_amount NUMERIC,
    p_vat_percent NUMERIC,
    p_shipping_cost NUMERIC,
    p_other_cost NUMERIC,
    p_discount NUMERIC,
    p_notes TEXT,
    p_created_at TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Update purchases table
    UPDATE purchases
    SET
        supplier_id = p_supplier_id,
        supplier_name = p_supplier_name,
        invoice_number = p_invoice_number,
        total_amount = p_total_amount,
        paid_amount = p_paid_amount,
        due_amount = p_due_amount,
        vat_amount = p_vat_amount,
        vat_percent = p_vat_percent,
        shipping_cost = p_shipping_cost,
        other_cost = p_other_cost,
        discount = p_discount,
        notes = p_notes,
        created_at = p_created_at::timestamp
    WHERE id = p_purchase_id
    RETURNING row_to_json(purchases.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Step 5: Create RPC function to insert sale
CREATE OR REPLACE FUNCTION insert_sale(
    p_shop_id UUID,
    p_customer_id UUID,
    p_customer_name TEXT,
    p_invoice_number TEXT,
    p_total_amount NUMERIC,
    p_paid_amount NUMERIC,
    p_due_amount NUMERIC,
    p_vat_amount NUMERIC,
    p_vat_percent NUMERIC,
    p_discount NUMERIC,
    p_notes TEXT,
    p_created_at TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Insert into sales table
    INSERT INTO sales (
        shop_id,
        customer_id,
        customer_name,
        invoice_number,
        total_amount,
        paid_amount,
        due_amount,
        vat_amount,
        vat_percent,
        discount,
        notes,
        created_at
    ) VALUES (
        p_shop_id,
        p_customer_id,
        p_customer_name,
        p_invoice_number,
        p_total_amount,
        p_paid_amount,
        p_due_amount,
        p_vat_amount,
        p_vat_percent,
        p_discount,
        p_notes,
        p_created_at::timestamp
    )
    RETURNING row_to_json(sales.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Step 6: Create RPC function to update sale
CREATE OR REPLACE FUNCTION update_sale(
    p_sale_id UUID,
    p_customer_id UUID,
    p_customer_name TEXT,
    p_invoice_number TEXT,
    p_total_amount NUMERIC,
    p_paid_amount NUMERIC,
    p_due_amount NUMERIC,
    p_vat_amount NUMERIC,
    p_vat_percent NUMERIC,
    p_discount NUMERIC,
    p_notes TEXT,
    p_created_at TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Update sales table
    UPDATE sales
    SET
        customer_id = p_customer_id,
        customer_name = p_customer_name,
        invoice_number = p_invoice_number,
        total_amount = p_total_amount,
        paid_amount = p_paid_amount,
        due_amount = p_due_amount,
        vat_amount = p_vat_amount,
        vat_percent = p_vat_percent,
        discount = p_discount,
        notes = p_notes,
        created_at = p_created_at::timestamp
    WHERE id = p_sale_id
    RETURNING row_to_json(sales.*) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Step 7: Grant execute permissions
GRANT EXECUTE ON FUNCTION insert_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION update_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION insert_sale TO authenticated;
GRANT EXECUTE ON FUNCTION update_sale TO authenticated;

-- Step 8: Verify columns exist
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICATION ===';
    RAISE NOTICE 'Checking purchases table columns...';
    PERFORM 1 FROM information_schema.columns 
    WHERE table_name = 'purchases' AND column_name = 'vat_percent';
    IF FOUND THEN
        RAISE NOTICE '✓ vat_percent column exists in purchases table';
    ELSE
        RAISE NOTICE '✗ vat_percent column NOT FOUND in purchases table';
    END IF;
    
    RAISE NOTICE 'Checking sales table columns...';
    PERFORM 1 FROM information_schema.columns 
    WHERE table_name = 'sales' AND column_name = 'vat_percent';
    IF FOUND THEN
        RAISE NOTICE '✓ vat_percent column exists in sales table';
    ELSE
        RAISE NOTICE '✗ vat_percent column NOT FOUND in sales table';
    END IF;
    
    RAISE NOTICE '=== MIGRATION COMPLETE ===';
END $$;
