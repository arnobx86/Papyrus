-- Add transaction_date column to transactions table
-- This stores the user-selected date separately from created_at (actual creation timestamp)
-- This allows proper ordering by created_at while displaying the user's chosen date

ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS transaction_date DATE;

-- Backfill existing transactions: copy created_at date to transaction_date for display
-- This preserves the current display behavior while fixing the ordering issue
UPDATE transactions 
SET transaction_date = created_at::DATE 
WHERE transaction_date IS NULL;

-- Add index for transaction_date queries
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_date ON transactions(transaction_date);
