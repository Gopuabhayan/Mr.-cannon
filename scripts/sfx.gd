class_name Sfx
extends RefCounted
## Tiny sound helper:  Sfx.play("shoot")   Sfx.start_music()
## To change a sound, just change its file path below.

const DIR: String = "res://brackeys_platformer_assets/sounds/"
const SOUNDS: Dictionary = {
	"shoot": DIR + "jump.wav",        # cannon fires
	"bounce": DIR + "tap.wav",        # ball bounces off a wall
	"kill": DIR + "explosion.wav",    # ball hits an enemy
	"point": DIR + "coin.wav",        # +points
	"win": DIR + "power_up.wav",      # level complete
	"lose": DIR + "hurt.wav",         # game over
}
const MUSIC: String = "res://brackeys_platformer_assets/music/time_for_adventure.mp3"
const MUSIC_VOLUME_DB: float = -16.0  # music is quiet so effects stand out

const SETTINGS_PATH: String = "user://settings.cfg"

static var _music: AudioStreamPlayer
static var _loaded: bool = false
static var _volume: Dictionary = {"Master": 1.0, "Music": 1.0, "SFX": 1.0}  # 0.0 .. 1.0


## Loads the saved options and applies them. Safe to call many times.
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	for bus in ["Music", "SFX"]:  # Master already exists
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for bus in _volume:
			_volume[bus] = clampf(float(cfg.get_value("audio", bus, 1.0)), 0.0, 1.0)
	for bus in _volume:
		_apply(bus)


static func get_volume(bus: String) -> float:
	load_settings()
	return _volume[bus]


## bus is "Master", "Music" or "SFX"; value is 0.0 (silent) to 1.0 (full).
static func set_volume(bus: String, value: float) -> void:
	load_settings()
	_volume[bus] = clampf(value, 0.0, 1.0)
	_apply(bus)
	save_settings()


static func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus in _volume:
		cfg.set_value("audio", bus, _volume[bus])
	cfg.save(SETTINGS_PATH)


static func _apply(bus: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(_volume[bus], 0.0001)))
	AudioServer.set_bus_mute(idx, _volume[bus] <= 0.001)




static func play(sound: String, volume_db: float = -6.0) -> void:
	if not SOUNDS.has(sound):
		return
	load_settings()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = load(SOUNDS[sound])
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	root.add_child.call_deferred(p)  # deferred: safe even while a scene is loading
	p.play.call_deferred()


## Starts the looping background music once; it keeps playing between levels.
static func start_music() -> void:
	if is_instance_valid(_music):
		return
	load_settings()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var stream: AudioStreamMP3 = load(MUSIC)
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	root.add_child.call_deferred(_music)
	_music.play.call_deferred()
