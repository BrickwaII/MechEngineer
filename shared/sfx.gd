extends Node

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}

func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

func click()      -> void: _play("click",   440.0, 0.07, 0.45)
func select()     -> void: _play("select",  660.0, 0.12, 0.50)
func attack()     -> void: _play_sweep("attack",  280.0, 55.0, 0.22, 0.60)
func defend()     -> void: _play("defend",  330.0, 0.18, 0.45)
func support()    -> void: _play("support", 550.0, 0.16, 0.45)
func confirm()    -> void: _play("confirm", 880.0, 0.20, 0.50)
func cancel_sfx() -> void: _play("cancel",  200.0, 0.12, 0.40)
func enemy_act()  -> void: _play_sweep("enemy",   130.0, 75.0, 0.28, 0.55)

func _play(id: String, freq: float, dur: float, vol: float) -> void:
	if not _cache.has(id):
		_cache[id] = _make_tone(freq, dur, vol)
	var p := _get_free()
	p.stream = _cache[id] as AudioStreamWAV
	p.play()

func _play_sweep(id: String, f0: float, f1: float, dur: float, vol: float) -> void:
	if not _cache.has(id):
		_cache[id] = _make_sweep(f0, f1, dur, vol)
	var p := _get_free()
	p.stream = _cache[id] as AudioStreamWAV
	p.play()

func _get_free() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			return p
	_players[0].stop()
	return _players[0]

func _make_tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var sr := 22050
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(sr)
		var prog := t / dur
		var env := minf(t / 0.008, 1.0) * (1.0 - smoothstep(0.6, 1.0, prog))
		var s := clampi(int(sin(t * freq * TAU) * env * vol * 32767.0), -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav_from(data, sr)

func _make_sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var sr := 22050
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(sr)
		var prog := t / dur
		var freq := f0 + (f1 - f0) * prog
		var env := minf(t / 0.004, 1.0) * pow(1.0 - prog, 0.4)
		phase += freq * TAU / float(sr)
		var s := clampi(int(sin(phase) * env * vol * 32767.0), -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav_from(data, sr)

func _wav_from(data: PackedByteArray, sr: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sr
	wav.data = data
	return wav
