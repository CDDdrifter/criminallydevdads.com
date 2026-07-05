-- Godot Web exports can include multi-GB .pck / .wasm files (was 500 MB per object).
update storage.buckets
set file_size_limit = 10737418240
where id = 'game-builds';
