-- Per-page comment toggle. When false, the auto comment thread is hidden on
-- that CMS page (e.g. policy / legal pages). Defaults to true so existing
-- pages keep their comment threads.

ALTER TABLE public.site_pages
  ADD COLUMN IF NOT EXISTS comments_enabled boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.site_pages.comments_enabled IS
  'When false, /#/p/:slug hides the auto comment thread (policy/legal pages).';

-- Policy / legal pages should not invite public comments.
UPDATE public.site_pages
SET comments_enabled = false
WHERE slug IN ('terms', 'privacy', 'refund', 'cookie', 'dmca', 'disclaimer', 'eula', 'acceptable-use');
