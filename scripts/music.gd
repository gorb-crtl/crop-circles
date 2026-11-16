extends Node
## Background music, autoloaded as "Music". Loops res://assets/music/theme.wav.
## Replace that file with a real track (same name) to change the music.

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	var stream: AudioStream = load("res://assets/music/theme.wav")
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_player.stream = stream
	refresh()
	Game.settings_changed.connect(refresh)
	if stream:
		_player.play()


func refresh() -> void:
	_player.volume_db = linear_to_db(maxf(Game.music_volume * 0.7, 0.0001))


## Muffle the music a bit (pause menu), or bring it back.
func duck(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_player, "pitch_scale", 0.9 if on else 1.0, 0.3)
