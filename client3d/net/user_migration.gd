## The 3D client keeps its files in a folder of its own ("Startup Sim 3D",
## see application/config/custom_user_dir_name); before that both clients
## shared Godot's default "Startup Sim" folder, which the 2D client still
## uses. On the first desktop start the 3D client copies over what makes
## sense for both: pinned server certificates, the last server and nick
## (without the login token: refreshing it in one client would log the
## other out), sound volumes and the crash-report consent. Never the crash
## session, logs, graphics/window settings or the character draft. The old
## folder is only read. iOS/Android keep each app in its own sandbox anyway.
extends RefCounted

const MARKER := "migrated_from_2d.cfg"
## settings.cfg sections copied as they are.
const SETTINGS_SECTIONS := ["audio", "privacy"]


## The folder the clients shared before (Godot's default user dir; "godot"
## is lower-case on Linux/BSD).
static func legacy_dir() -> String:
	var godot := "Godot" if OS.get_name() in ["macOS", "Windows"] else "godot"
	return OS.get_data_dir().path_join(godot).path_join("app_userdata/Startup Sim")


## At start-up: migrate once, desktop only, not in tests (STARTUP_SIM_NO_MIGRATE).
static func run_once() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web") or OS.get_environment("STARTUP_SIM_NO_MIGRATE") != "":
		return
	var new_dir := OS.get_user_data_dir()
	if new_dir.simplify_path() == legacy_dir().simplify_path():
		return
	migrate(legacy_dir(), new_dir)


## Copies from old_dir to new_dir unless new_dir has the marker; returns the
## names of the files written. Missing or corrupt files are skipped.
static func migrate(old_dir: String, new_dir: String) -> PackedStringArray:
	var done := PackedStringArray()
	if FileAccess.file_exists(new_dir.path_join(MARKER)):
		return done
	DirAccess.make_dir_recursive_absolute(new_dir)
	if DirAccess.dir_exists_absolute(old_dir):
		if _copy_pins(old_dir, new_dir):
			done.append("known_servers.cfg")
		if _copy_last_server(old_dir, new_dir):
			done.append("auth.cfg")
		if _copy_settings(old_dir, new_dir):
			done.append("settings.cfg")
	var marker := ConfigFile.new()
	marker.set_value("migration", "from", old_dir)
	marker.set_value("migration", "files", done)
	marker.set_value("migration", "at", Time.get_datetime_string_from_system(true) + " UTC")
	marker.save(new_dir.path_join(MARKER))
	return done


static func _load(path: String) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var cfg := ConfigFile.new()
	return cfg if cfg.load(path) == OK else null


## Merged into what's there (a pin the 3D client already has wins).
static func _copy_pins(old_dir: String, new_dir: String) -> bool:
	var old := _load(old_dir.path_join("known_servers.cfg"))
	if old == null or not old.has_section("pins"):
		return false
	var path := new_dir.path_join("known_servers.cfg")
	var cfg := _load(path)
	if cfg == null:
		cfg = ConfigFile.new()
	var any := false
	for address in old.get_section_keys("pins"):
		var pem = old.get_value("pins", address)
		if pem is String and pem != "" and not cfg.has_section_key("pins", address):
			cfg.set_value("pins", address, pem)
			any = true
	return any and cfg.save(path) == OK


static func _copy_last_server(old_dir: String, new_dir: String) -> bool:
	var old := _load(old_dir.path_join("auth.cfg"))
	var path := new_dir.path_join("auth.cfg")
	if old == null or FileAccess.file_exists(path):
		return false
	var address = old.get_value("session", "address", "")
	if not address is String or address == "":
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("session", "address", address)
	cfg.set_value("session", "nick", str(old.get_value("session", "nick", "")))
	cfg.set_value("session", "refresh", "")
	return cfg.save(path) == OK


static func _copy_settings(old_dir: String, new_dir: String) -> bool:
	var old := _load(old_dir.path_join("settings.cfg"))
	var path := new_dir.path_join("settings.cfg")
	if old == null or FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	for section in SETTINGS_SECTIONS:
		if old.has_section(section):
			for key in old.get_section_keys(section):
				cfg.set_value(section, key, old.get_value(section, key))
	return not cfg.get_sections().is_empty() and cfg.save(path) == OK
