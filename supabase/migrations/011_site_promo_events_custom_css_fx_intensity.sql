-- Homepage promo / event banners + advanced theming (admin-only writes via RLS).
alter table site_settings add column if not exists promo_events jsonb not null default '[]'::jsonb;
alter table site_settings add column if not exists custom_css text not null default '';
alter table site_settings add column if not exists fx_intensity text not null default 'normal';
