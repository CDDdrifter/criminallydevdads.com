-- ---------------------------------------------------------------------------
-- 019 — HTML app pages (paste Gemini / Claude full HTML) + unlisted / hub.
--
-- page_mode: 'blocks' (default) = existing sections/body. 'html_app' = raw
-- HTML rendered inside a sandboxed iframe on /#/p/:slug for script safety.
-- unlisted: adds noindex on the client; pair with show_in_nav = false for
-- "secret URL only" pages.
-- show_on_apps_hub: when true and page_mode = html_app, page appears on /#/apps.
-- ---------------------------------------------------------------------------

alter table site_pages add column if not exists page_mode text not null default 'blocks';

alter table site_pages add column if not exists raw_html text not null default '';

alter table site_pages add column if not exists unlisted boolean not null default false;

alter table site_pages add column if not exists show_on_apps_hub boolean not null default true;

alter table site_pages add column if not exists html_app_summary text not null default '';

alter table site_pages add column if not exists html_iframe_compat boolean not null default false;
