extends Node
## Efek suara chiptune / retro arcade prosedural ringan (tanpa file audio eksternal).

signal mute_changed(is_muted: bool)

var muted: bool = false
var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _audio_ready: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.30
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -10.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_audio_ready = _playback != null


func toggle_mute() -> void:
	muted = not muted
	mute_changed.emit(muted)


func play_click() -> void:
	_play_tone(720.0, 0.04, 0.14)


func play_success() -> void:
	_play_tone(523.25, 0.065, 0.18)
	if is_inside_tree():
		await get_tree().create_timer(0.065).timeout
	_play_tone(783.99, 0.10, 0.20)


func play_stage_clear() -> void:
	for note: Array in [[523.25, 0.07], [659.25, 0.07], [783.99, 0.08], [1046.5, 0.14]]:
		_play_tone(float(note[0]), float(note[1]), 0.20)
		if is_inside_tree():
			await get_tree().create_timer(float(note[1])).timeout


func play_error() -> void:
	_play_tone(185.0, 0.11, 0.22)


func _play_tone(freq_hz: float, duration_sec: float, amp: float) -> void:
	if muted or not _audio_ready or _playback == null:
		return
	if _player != null and not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		return
	var sample_rate: float = 22050.0
	var frames: int = mini(int(sample_rate * duration_sec), _playback.get_frames_available())
	var increment: float = TAU * freq_hz / sample_rate
	for i: int in range(frames):
		var env: float = 1.0 - (float(i) / float(maxi(1, frames)))
		var wave: float = sin(float(i) * increment)
		# Sedikit harmonik retro square-soft agar terasa seperti SFX 128-bit lembut
		var sample: float = clampf(wave * 1.15, -1.0, 1.0) * amp * env
		_playback.push_frame(Vector2(sample, sample))
