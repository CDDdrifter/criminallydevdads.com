-- Per-game browser tab icon (optional). Falls back to thumbnail, then site favicon at runtime.
ALTER TABLE public.site_games
  ADD COLUMN IF NOT EXISTS tab_icon_url text;

COMMENT ON COLUMN public.site_games.tab_icon_url IS
  'Optional square icon (32–64px) for browser tab on /game/:slug and /play/:slug.';
