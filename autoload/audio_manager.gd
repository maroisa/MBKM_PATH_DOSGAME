extends Node
## Synthesizer efek suara retro 16-bit/arcade polifonik (AudioStreamWAV prosedural, mulus di Web & Desktop).

signal mute_changed(is_muted: bool)

const SAMPLE_RATE: int = 22050
const VOICE_COUNT: int = 6

var muted: bool = false
var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor: int = 0
var _sfx_cache: Dictionary[String, AudioStreamWAV] = {}
var _rng := RandomNumberGenerator.new()
var _audio_ready: bool = false


func _ready() -> void:
	_rng.randomize()
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return
	for _i: int in range(VOICE_COUNT):
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_voices.append(p)
	_build_sfx_bank()
	_audio_ready = not _voices.is_empty()


func toggle_mute() -> void:
	muted = not muted
	mute_changed.emit(muted)
	if not muted:
		play_click()


func play_click() -> void:
	_play_cached("click", _rng.randf_range(0.95, 1.06), -9.0)


func play_block_place() -> void:
	_play_cached("place", _rng.randf_range(0.96, 1.07), -7.5)


func play_block_remove() -> void:
	_play_cached("remove", _rng.randf_range(0.95, 1.04), -8.5)


func play_pin_toggle(pinned: bool) -> void:
	_play_cached("pin_on" if pinned else "pin_off", 1.0, -7.5)


func play_folder_move() -> void:
	_play_cached("folder", _rng.randf_range(0.96, 1.05), -8.0)


func play_scan_reveal() -> void:
	_play_cached("scan", 1.0, -7.0)


func play_delete_file() -> void:
	_play_cached("delete", _rng.randf_range(0.94, 1.05), -8.0)


func play_timer_tick(urgent: bool = false) -> void:
	_play_cached("tick_urgent" if urgent else "tick", 1.0, -9.0 if urgent else -12.0)


func play_timeout_warn() -> void:
	_play_cached("timeout", 1.0, -6.5)


func play_modal_open() -> void:
	_play_cached("modal_open", 1.0, -10.0)


func play_modal_close() -> void:
	_play_cached("modal_close", 1.0, -10.5)


func play_star_pop(star_idx: int) -> void:
	var pitches: Array[float] = [1.0, 1.189, 1.498]
	var pitch: float = pitches[clampi(star_idx, 0, pitches.size() - 1)]
	_play_cached("star", pitch, -6.5)


func play_success() -> void:
	_play_cached("success", 1.0, -6.0)


func play_error() -> void:
	_play_cached("error", 1.0, -6.5)


func play_stage_clear() -> void:
	_play_cached("stage_clear", 1.0, -5.5)


func _play_cached(sfx_id: String, pitch: float = 1.0, vol_db: float = -8.0) -> void:
	if muted or not _audio_ready or not _sfx_cache.has(sfx_id):
		return
	var player: AudioStreamPlayer = _pick_voice()
	if player == null:
		return
	player.stream = _sfx_cache[sfx_id]
	player.pitch_scale = pitch
	player.volume_db = vol_db
	player.play()


func _pick_voice() -> AudioStreamPlayer:
	if _voices.is_empty():
		return null
	for v: AudioStreamPlayer in _voices:
		if not v.playing:
			return v
	var chosen: AudioStreamPlayer = _voices[_voice_cursor % _voices.size()]
	_voice_cursor += 1
	return chosen


func _build_sfx_bank() -> void:
	# 1. Click keycap taktil (pop pendek bersih)
	_sfx_cache["click"] = _synth_sequence([
		{"t": 0.0, "d": 0.042, "f0": 780.0, "f1": 620.0, "wave": "tri", "amp": 0.36},
		{"t": 0.0, "d": 0.018, "f0": 1560.0, "f1": 1200.0, "wave": "pulse", "amp": 0.14},
	], 0.05)

	# 2. Pasang blok perintah (bloop naik ceria ala puzzle game)
	_sfx_cache["place"] = _synth_sequence([
		{"t": 0.0, "d": 0.055, "f0": 420.0, "f1": 690.0, "wave": "tri", "amp": 0.40},
		{"t": 0.042, "d": 0.075, "f0": 780.0, "f1": 880.0, "wave": "pulse", "amp": 0.24},
	], 0.13)

	# 3. Lepas blok perintah (blup turun lembut)
	_sfx_cache["remove"] = _synth_sequence([
		{"t": 0.0, "d": 0.075, "f0": 560.0, "f1": 290.0, "wave": "tri", "amp": 0.36},
		{"t": 0.0, "d": 0.045, "f0": 560.0, "f1": 340.0, "wave": "pulse", "amp": 0.12},
	], 0.09)

	# 4. Semat / Lepas sematan input (latch klik mekanis ganda)
	_sfx_cache["pin_on"] = _synth_sequence([
		{"t": 0.0, "d": 0.045, "f0": 520.0, "f1": 660.0, "wave": "pulse", "amp": 0.28},
		{"t": 0.05, "d": 0.075, "f0": 880.0, "f1": 1046.5, "wave": "tri", "amp": 0.36},
	], 0.14)
	_sfx_cache["pin_off"] = _synth_sequence([
		{"t": 0.0, "d": 0.045, "f0": 820.0, "f1": 640.0, "wave": "tri", "amp": 0.30},
		{"t": 0.05, "d": 0.065, "f0": 540.0, "f1": 420.0, "wave": "pulse", "amp": 0.22},
	], 0.13)

	# 5. Navigasi folder CD / CD ..
	_sfx_cache["folder"] = _synth_sequence([
		{"t": 0.0, "d": 0.065, "f0": 370.0, "f1": 554.37, "wave": "tri", "amp": 0.35},
		{"t": 0.05, "d": 0.06, "f0": 554.37, "f1": 659.25, "wave": "pulse", "amp": 0.18},
	], 0.12)

	# 6. Scan DIR /a (radar ping berkilau)
	_sfx_cache["scan"] = _synth_sequence([
		{"t": 0.0, "d": 0.07, "f0": 659.25, "f1": 659.25, "wave": "pulse", "amp": 0.24},
		{"t": 0.065, "d": 0.07, "f0": 987.77, "f1": 987.77, "wave": "pulse", "amp": 0.24},
		{"t": 0.13, "d": 0.14, "f0": 1318.5, "f1": 1480.0, "wave": "tri", "amp": 0.36},
	], 0.29)

	# 7. Hapus file DEL (zap retro + puff lembut)
	_sfx_cache["delete"] = _synth_sequence([
		{"t": 0.0, "d": 0.09, "f0": 500.0, "f1": 150.0, "wave": "saw", "amp": 0.26},
		{"t": 0.015, "d": 0.07, "f0": 100.0, "f1": 100.0, "wave": "noise", "amp": 0.14},
	], 0.11)

	# 8. Detak timer & peringatan waktu habis (30 detik)
	_sfx_cache["tick"] = _synth_sequence([
		{"t": 0.0, "d": 0.032, "f0": 920.0, "f1": 860.0, "wave": "tri", "amp": 0.30},
	], 0.04)
	_sfx_cache["tick_urgent"] = _synth_sequence([
		{"t": 0.0, "d": 0.045, "f0": 1174.66, "f1": 1108.73, "wave": "pulse", "amp": 0.28},
		{"t": 0.0, "d": 0.045, "f0": 587.33, "f1": 587.33, "wave": "tri", "amp": 0.22},
	], 0.055)
	_sfx_cache["timeout"] = _synth_sequence([
		{"t": 0.0, "d": 0.10, "f0": 440.0, "f1": 415.0, "wave": "pulse", "amp": 0.28},
		{"t": 0.11, "d": 0.14, "f0": 329.63, "f1": 277.18, "wave": "pulse", "amp": 0.30},
		{"t": 0.11, "d": 0.14, "f0": 164.81, "f1": 146.83, "wave": "tri", "amp": 0.25},
	], 0.27)

	# 9. Modal buka/tutup
	_sfx_cache["modal_open"] = _synth_sequence([
		{"t": 0.0, "d": 0.055, "f0": 440.0, "f1": 659.25, "wave": "tri", "amp": 0.28},
		{"t": 0.045, "d": 0.075, "f0": 659.25, "f1": 880.0, "wave": "tri", "amp": 0.24},
	], 0.13)
	_sfx_cache["modal_close"] = _synth_sequence([
		{"t": 0.0, "d": 0.065, "f0": 659.25, "f1": 415.3, "wave": "tri", "amp": 0.26},
	], 0.08)

	# 10. Pop bintang (ding kristal retro)
	_sfx_cache["star"] = _synth_sequence([
		{"t": 0.0, "d": 0.16, "f0": 783.99, "f1": 783.99, "wave": "tri", "amp": 0.38},
		{"t": 0.0, "d": 0.10, "f0": 1567.98, "f1": 1567.98, "wave": "pulse", "amp": 0.16},
	], 0.18)

	# 11. Jawaban benar (arpeggio koin/power-up C5-E5-G5-C6 yang asik!)
	_sfx_cache["success"] = _synth_sequence([
		{"t": 0.00, "d": 0.075, "f0": 523.25, "f1": 523.25, "wave": "pulse", "amp": 0.26},
		{"t": 0.06, "d": 0.075, "f0": 659.25, "f1": 659.25, "wave": "pulse", "amp": 0.26},
		{"t": 0.12, "d": 0.085, "f0": 783.99, "f1": 783.99, "wave": "pulse", "amp": 0.28},
		{"t": 0.18, "d": 0.220, "f0": 1046.5, "f1": 1046.5, "wave": "pulse", "amp": 0.26},
		{"t": 0.18, "d": 0.220, "f0": 523.25, "f1": 523.25, "wave": "tri", "amp": 0.30},
	], 0.42)

	# 12. Jawaban salah (bonk arcade 2 nada turun yang jelas tapi tidak menyakitkan telinga)
	_sfx_cache["error"] = _synth_sequence([
		{"t": 0.00, "d": 0.095, "f0": 246.94, "f1": 220.0, "wave": "saw", "amp": 0.28},
		{"t": 0.095, "d": 0.165, "f0": 185.0, "f1": 146.83, "wave": "saw", "amp": 0.30},
		{"t": 0.095, "d": 0.165, "f0": 92.5, "f1": 82.41, "wave": "tri", "amp": 0.24},
	], 0.28)

	# 13. Fanfare selesai stage (melodi kemenangan retro 16-bit!)
	_sfx_cache["stage_clear"] = _synth_sequence([
		{"t": 0.00, "d": 0.085, "f0": 523.25, "f1": 523.25, "wave": "pulse", "amp": 0.25},
		{"t": 0.08, "d": 0.085, "f0": 659.25, "f1": 659.25, "wave": "pulse", "amp": 0.25},
		{"t": 0.16, "d": 0.085, "f0": 783.99, "f1": 783.99, "wave": "pulse", "amp": 0.26},
		{"t": 0.24, "d": 0.095, "f0": 659.25, "f1": 659.25, "wave": "pulse", "amp": 0.22},
		{"t": 0.33, "d": 0.360, "f0": 1046.5, "f1": 1046.5, "wave": "pulse", "amp": 0.24},
		{"t": 0.33, "d": 0.360, "f0": 783.99, "f1": 783.99, "wave": "tri", "amp": 0.24},
		{"t": 0.33, "d": 0.360, "f0": 523.25, "f1": 523.25, "wave": "tri", "amp": 0.26},
	], 0.72)


func _synth_sequence(events: Array[Dictionary], total_sec: float) -> AudioStreamWAV:
	var total_frames: int = maxi(1, int(ceilf(total_sec * float(SAMPLE_RATE))))
	var mix := PackedFloat32Array()
	mix.resize(total_frames)

	var noise_seed: int = 1337
	for ev: Dictionary in events:
		var start_idx: int = clampi(int(float(ev["t"]) * float(SAMPLE_RATE)), 0, total_frames - 1)
		var dur_frames: int = maxi(1, int(float(ev["d"]) * float(SAMPLE_RATE)))
		var end_idx: int = mini(total_frames, start_idx + dur_frames)
		var f0: float = float(ev["f0"])
		var f1: float = float(ev["f1"])
		var amp: float = float(ev["amp"])
		var wave_type: String = str(ev["wave"])
		var phase: float = 0.0

		for idx: int in range(start_idx, end_idx):
			var local_i: int = idx - start_idx
			var progress: float = float(local_i) / float(maxi(1, dur_frames - 1))
			var freq: float = lerpf(f0, f1, progress)
			phase += freq / float(SAMPLE_RATE)
			var frac: float = phase - floorf(phase)

			# Amplop ADSR lembut (attack cepat 6%, decay halus tanpa bunyi klik)
			var env: float = (progress / 0.06) if progress < 0.06 else pow(1.0 - ((progress - 0.06) / 0.94), 1.35)
			var raw: float = 0.0
			if wave_type == "pulse":
				raw = 0.85 if frac < 0.28 else -0.85
			elif wave_type == "tri":
				raw = 1.0 - 4.0 * absf(frac - 0.5)
			elif wave_type == "saw":
				raw = (2.0 * frac - 1.0) * 0.8
			elif wave_type == "noise":
				noise_seed = (noise_seed * 1103515245 + 12345) & 0x7fffffff
				raw = (float(noise_seed & 0xffff) / 32768.0) - 1.0
			else:
				raw = sin(frac * TAU)
			mix[idx] += raw * amp * env

	var pcm := PackedByteArray()
	pcm.resize(total_frames * 2)
	for i: int in range(total_frames):
		var s_val: float = clampf(mix[i], -0.95, 0.95)
		var s16: int = clampi(int(roundf(s_val * 32767.0)), -32768, 32767)
		pcm[i * 2] = s16 & 0xFF
		pcm[i * 2 + 1] = (s16 >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav
