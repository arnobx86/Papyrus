-- Diagnostic function to check pg_net history
create or replace function debug_get_net_history() 
returns table(id bigint, status integer, message text, body text, created_at timestamptz) as $$
begin
  return query 
  select h.id, h.status, h.message, h.body, h.created_at
  from net.http_responses h
  order by h.created_at desc
  limit 5;
end;
$$ language plpgsql security definer;
