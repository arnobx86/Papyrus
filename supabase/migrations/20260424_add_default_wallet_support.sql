-- 🚀 Add is_default to wallets for default selection
ALTER TABLE wallets ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT FALSE;

-- Ensure only one default wallet per shop (optional but recommended)
-- Or we can just handle the toggle logic in the app.
