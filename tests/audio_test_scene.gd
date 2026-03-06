extends Control

func _ready() -> void:
	AudioManager.play_music("hub_town")
	print("[AudioTest] Playing hub_town music on load")
	print("[AudioTest] Keys: 1=click, 2=confirm, 3=cancel, 4=catch, 5=sonar, 6=melee, 7=sell, 8=upgrade, 9=achievement")
	print("[AudioTest] M=toggle music (ocean/dive/hub/menu), W=weather, S=stop music")

var _music_index := 0
var _music_names := ["ocean_surface", "dive", "hub_town", "main_menu"]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_1: AudioManager.play_sfx("ui_click")
		KEY_2: AudioManager.play_sfx("ui_confirm")
		KEY_3: AudioManager.play_sfx("ui_cancel")
		KEY_4: AudioManager.play_sfx("catch")
		KEY_5: AudioManager.play_sfx("sonar_pulse")
		KEY_6: AudioManager.play_sfx("melee")
		KEY_7: AudioManager.play_sfx("sell")
		KEY_8: AudioManager.play_sfx("upgrade")
		KEY_9: AudioManager.play_sfx("achievement")
		KEY_M:
			var track := _music_names[_music_index]
			AudioManager.play_music(track)
			print("[AudioTest] Playing music: ", track)
			_music_index = (_music_index + 1) % _music_names.size()
		KEY_W:
			AudioManager.play_music("weather_ambience")
			print("[AudioTest] Playing weather ambience")
		KEY_S:
			AudioManager.stop_music()
			print("[AudioTest] Stopped music")
		KEY_ESCAPE:
			get_tree().quit()
