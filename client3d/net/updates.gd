## A newer version of the game? At start-up the client asks GitHub for the
## latest release (public API, no login) and compares it with its own
## version (project setting application/config/version); the title screen
## then offers the download. Only exported builds check (or --update-check).
extends Node

const REPO := "mateuszpalak/startup-sim"
const LATEST_API := "https://api.github.com/repos/" + REPO + "/releases/latest"
## Where players download the game (the newest release's page).
const DOWNLOAD_PAGE := "https://github.com/" + REPO + "/releases/latest"

## This client's release files: StartupSim3D-<version>-* (the 2D client's
## are StartupSim-<version>*).
const ASSET_PREFIX := "StartupSim3D-"

## Dev: pretend to be another version (--pretend-version=0.0.9).
static var pretend := ""

var _http := HTTPRequest.new()


func _ready() -> void:
	_http.timeout = 8.0
	add_child(_http)


static func enabled(args: Dictionary) -> bool:
	return args.has("update-check") or (not OS.has_feature("editor") and not args.has("no-update-check"))


static func current() -> String:
	return pretend if pretend != "" else str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## "0.2.0" > "0.1.10"? (numbers compared part by part; a leading "v" is fine).
static func is_newer(candidate: String, than: String) -> bool:
	var a := candidate.trim_prefix("v").split(".")
	var b := than.trim_prefix("v").split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


## The latest release if it is newer than this build: {version, url}; else {}.
func check() -> Dictionary:
	if _http.request(LATEST_API, ["Accept: application/vnd.github+json", "User-Agent: StartupSim/" + current()]) != OK:
		return {}
	var res: Array = await _http.request_completed
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return {}
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or data.get("draft", false) or data.get("prerelease", false):
		return {}
	var version := str(data.get("tag_name", "")).trim_prefix("v")
	if version == "" or not is_newer(version, current()):
		return {}
	var url := str(data.get("html_url", DOWNLOAD_PAGE))
	var suffix := asset_suffix(OS.get_name(), OS.has_feature("arm64"))
	if suffix != "":
		url = asset_url(data.get("assets", []), suffix, url)
	return {"version": version, "url": url}


## Which release file this platform installs from (as the tools/build-*.sh
## scripts name them): Windows its zip, Android the release APK, macOS the
## .dmg. "" = the release page (iOS updates through TestFlight).
static func asset_suffix(os_name: String, arm64: bool) -> String:
	match os_name:
		"Windows":
			return "-windows-%s.zip" % ("arm64" if arm64 else "x86_64")
		"Android":
			return "-android.apk"
		"macOS":
			return "-macos.dmg"
	return ""


## Windows players get the zip for their machine straight away (assets named
## like tools/build-windows.sh makes them); otherwise the release page.
static func asset_url(assets, suffix: String, fallback: String) -> String:
	if typeof(assets) != TYPE_ARRAY:
		return fallback
	for a in assets:
		var name := str(a.get("name", "")) if typeof(a) == TYPE_DICTIONARY else ""
		if name.begins_with(ASSET_PREFIX) and name.ends_with(suffix) and not name.ends_with("-debug" + suffix):
			return str(a.get("browser_download_url", fallback))
	return fallback
