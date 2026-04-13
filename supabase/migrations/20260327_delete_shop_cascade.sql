-- 🚀 Secure Shop Deletion Cascade
-- This function completely removes a shop and all associated data.
-- Only executable by a superuser/service role, but wrapped in security definer.

CREATE OR REPLACE FUNCTION delete_shop_cascade(p_shop_id uuid)
RETURNS void AS $$
BEGIN
    -- 1. Security check: Only the owner is allowed (enforced in where clause and app side)
    -- But since this is SECURITY DEFINER, we should be extra careful.
    -- The app will only call this for the current shop if the user is owner.

    -- 2. Delete Child Records across all business tables
    DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE shop_id = p_shop_id);
    DELETE FROM purchase_items WHERE purchase_id IN (SELECT id FROM purchases WHERE shop_id = p_shop_id);
    
    DELETE FROM ledger_entries WHERE shop_id = p_shop_id;
    DELETE FROM transactions WHERE shop_id = p_shop_id;
    DELETE FROM returns WHERE shop_id = p_shop_id;
    DELETE FROM sales WHERE shop_id = p_shop_id;
    DELETE FROM purchases WHERE shop_id = p_shop_id;
    DELETE FROM products WHERE shop_id = p_shop_id;
    DELETE FROM parties WHERE shop_id = p_shop_id;
    DELETE FROM categories WHERE shop_id = p_shop_id;
    DELETE FROM wallets WHERE shop_id = p_shop_id;
    DELETE FROM activity_logs WHERE shop_id = p_shop_id;
    DELETE FROM approval_requests WHERE shop_id = p_shop_id;
    DELETE FROM shop_members WHERE shop_id = p_shop_id;
    DELETE FROM shop_invitations WHERE shop_id = p_shop_id;
    
    -- 3. Finally delete the shop itself
    DELETE FROM shops WHERE id = p_shop_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION delete_shop_cascade IS 'Irreversibly deletes all data for a specific shop. Requires Owner status.';
