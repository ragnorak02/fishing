extends Node

const MUSIC_TRACKS := {
	"ocean_surface": "res://assets/audio/music/ocean_surface.wav",
	"hub_town": "res://assets/audio/music/hub_town.wav",
	"dive": "res://assets/audio/music/dive.wav",
	"main_menu": "res://assets/audio/music/main_menu.wav",
	"weather_ambience": "res://assets/audio/music/weather_ambience.wav",
}

const SFX_SOUNDS := {
	"harpoon_miss": "res://assets/audio/sfx/harpoon_miss.wav",
	"catch": "res://assets/audio/sfx/catch.wav",
	"upgrade": "res://assets/audio/sfx/upgrade.wav",
	"sonar_pulse": "res://assets/audio/sfx/sonar_pulse.wav",
	"sell": "res://assets/audio/sfx/sell.wav",
	"achievement": "res://assets/audio/sfx/achievement.wav",
	"melee": "res://assets/audio/sfx/melee.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
	"ui_cancel": "res://assets/audio/sfx/ui_cancel.wav",
}

const SFX_POOL_SIZE := 8

var volume_master: float = 1.0
var volume_music: float = 0.8
var volume_sfx: float = 1.0

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _current_music_track: String = ""

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

func play_music(track: String) -> void:
	if track == _current_music_track and _music_player.playing:
		return
	_current_music_track = track
	var path: String = MUSIC_TRACKS.get(track, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(volume_master * volume_music)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_current_music_track = ""

func play_sfx(sfx_name: String) -> void:
	var path: String = SFX_SOUNDS.get(sfx_name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_index]
	player.stream = stream
	player.volume_db = linear_to_db(volume_master * volume_sfx)
	player.play()
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
