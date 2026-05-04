-- Optional path inside the uploaded ZIP to the playable index.html (e.g. "MyExport/index.html").
-- When set, that file’s folder is used as the export root instead of auto-detection.

alter table site_games add column if not exists storage_entry_in_zip text;
