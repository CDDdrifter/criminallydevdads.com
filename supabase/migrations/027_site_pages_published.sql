-- Draft CMS pages stay hidden from the public until published (admins can still preview).
ALTER TABLE public.site_pages
  ADD COLUMN IF NOT EXISTS published boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.site_pages.published IS
  'When false, /#/p/:slug shows unavailable to visitors; signed-in site admins can preview.';
