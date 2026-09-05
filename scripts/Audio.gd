extends Node
## 全局音频：背景音乐 + 一次性音效。资源缺失时静默跳过。
## 音效：swipe（卡片飞出）/ flip（翻新牌）/ select（按下、选项）/ good（正向结果）/ bad（负向结果）/ end（结局）

const PATH := "res://audio/"
const SFX := ["swipe", "flip", "select", "good", "bad", "end"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	for n in SFX:
		_load(n)
	_load("music")
	_music = AudioStreamPlayer.new()
	_music.volume_db = linear_to_db(0.22)
	add_child(_music)
	var m = _streams.get("music")
	if m is AudioStream:
		_music.stream = m

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
	if _music != null and not _music.playing:
		_music.play()

func stop_music() -> void:
	if _music != null:
		_music.stop()

func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	add_child(p)
	_players.append(p)
	return p
