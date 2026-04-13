-- 🚀 PAPYRUS WALLET BALANCE FUNCTIONS
-- Functions to safely increment and decrement wallet balances

-- Function to increment wallet balance
create or replace function increment_wallet_balance(p_wallet_id uuid, p_amount numeric)
returns void as $$
begin
    update wallets
    set balance = balance + p_amount
    where id = p_wallet_id;
end;
$$ language plpgsql;

-- Function to decrement wallet balance
create or replace function decrement_wallet_balance(p_wallet_id uuid, p_amount numeric)
returns void as $$
begin
    update wallets
    set balance = balance - p_amount
    where id = p_wallet_id;
end;
$$ language plpgsql;
