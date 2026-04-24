-- 🚀 Add party_name to transactions for better reporting
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS party_name TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS transaction_date DATE;

-- Backfill transaction_date from created_at if it's null
UPDATE transactions SET transaction_date = created_at::date WHERE transaction_date IS NULL;
