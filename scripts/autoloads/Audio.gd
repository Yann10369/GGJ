extends Node
## 全局音频：背景音乐 + 一次性音效。资源缺失时静默跳过。
## 音效：swipe（卡片飞出）/ flip（翻新牌）/ select（按下、选项）/ good（正向结果）/ bad（负向结果）/ end（结局）

const PATH := "res://assets/audio/"
const SFX := ["swipe", "flip", "select", "good", "bad", "end"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _loop_music := false

func _ready() -> void:
	for n in SFX:
		_load(n)
	_load("music")
	_load("daily_warm")
	_load("ending_good")
	_load("ending_bad")
	_load("ending_perfect")
	_music = AudioStreamPlayer.new()
	_music.volume_db = linear_to_db(0.22)
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	# 日常 BGM 优先用「每日温馨」曲，缺失时退回旧的 music
	var m = _streams.get("daily_warm") if _streams.has("daily_warm") else _streams.get("music")
	if m is AudioStream:
		_music.stream = m

func _on_music_finished() -> void:
	if _loop_music:
		_music.play()

func _load(name: String) -> void:
	var p := PATH + name + ".wav"
	if ResourceLoader.exists(p):
		_streams[name] = load(p)

func play_sfx(name: String, pitch := 1.0) -> void:
	var s = _streams.get(name)
	if s is AudioStream == false:
		return
	var p := _get_player()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(0.55)
	p.play()

func play_music() -> void:
	if _music == null or _music.stream == null:
		return
	_loop_music = true
	if not _music.playing:
		_music.play()

func stop_music() -> void:
	_loop_music = false
	if _music != null:
		_music.stop()

func stop_all() -> void:
	stop_music()
	for player in _players:
		player.stop()
		player.stream = null
	if _music != null: _music.stream = null

func _exit_tree() -> void:
	stop_all()

func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	add_child(p)
	_players.append(p)
	return p
