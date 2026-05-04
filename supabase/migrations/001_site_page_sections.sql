-- Run once in Supabase SQL editor if you already applied schema.sql before this column existed.
alter table site_pages
  add column if not exists sections jsonb not null default '[]'::jsonb;
