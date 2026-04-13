-- 🚀 PURCHASE AND SALES RPC FUNCTIONS
-- These functions bypass PostgREST's schema cache to work around the "Could not find column" error
-- Use these functions instead of direct insert/update operations

-- Function to insert a new purchase
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
    -- Insert the purchase with all columns including vat_percent
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
    RETURNING * INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function to update an existing purchase
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
    -- Update the purchase with all columns including vat_percent
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
    RETURNING * INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function to insert a new sale
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
    -- Insert the sale with all columns including vat_percent
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
    RETURNING * INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function to update an existing sale
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
    -- Update the sale with all columns including vat_percent
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
    RETURNING * INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION insert_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION update_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION insert_sale TO authenticated;
GRANT EXECUTE ON FUNCTION update_sale TO authenticated;
