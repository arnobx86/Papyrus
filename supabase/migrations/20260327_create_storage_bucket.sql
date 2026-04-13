-- Create the storage bucket for assets
insert into storage.buckets (id, name, public)
values ('shop-assets', 'shop-assets', true)
on conflict (id) do nothing;

-- Set up access policy for the bucket
-- Allow anyone to read (since it's public)
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'shop-assets' );

-- Allow authenticated users to upload
DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
create policy "Authenticated Upload"
on storage.objects for insert
with check (
  bucket_id = 'shop-assets' AND
  auth.role() = 'authenticated'
);

-- Allow owners/managers to delete (Simplified for now)
DROP POLICY IF EXISTS "Owner Delete" ON storage.objects;
create policy "Owner Delete"
on storage.objects for delete
using (
  bucket_id = 'shop-assets' AND
  auth.role() = 'authenticated'
);
