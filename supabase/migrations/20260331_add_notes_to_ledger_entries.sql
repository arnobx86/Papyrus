-- 🚀 PAPYRUS ADD NOTES COLUMN TO LEDGER_ENTRIES
-- Add notes column to ledger_entries table if it doesn't exist

alter table ledger_entries add column if not exists notes text;
