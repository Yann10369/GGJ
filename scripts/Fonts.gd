extends RefCounted
class_name Fonts

## 中文字体：优先使用项目内自带的 Noto Sans SC / Noto Serif SC，
## 若尚未被编辑器导入（首次打开项目时会自动导入），则回退到系统字体。

const PATH_REGULAR := "res://fonts/NotoSansSC-Regular.otf"
const PATH_BOLD := "res://fonts/NotoSansSC-Bold.otf"
const PATH_SERIF := "res://fonts/NotoSerifSC-VF.ttf"

const FALLBACK_NAMES := [
	"Noto Sans SC", "Noto Sans CJK SC", "Source Han Sans SC",
	"Microsoft YaHei", "PingFang SC", "Hiragino Sans GB",
	"WenQuanYi Micro Hei", "sans-serif"
]

static var _cache: Dictionary = {}
static var _fallback := false

static func regular() -> Font:
	return _obtain(PATH_REGULAR, "regular", false)

static func bold() -> Font:
	return _obtain(PATH_BOLD, "bold", false)

static func serif() -> Font:
	return _obtain(PATH_SERIF, "serif", true)

static func is_fallback() -> bool:
	return _fallback

static func _obtain(path: String, key: String, is_serif: bool) -> Font:
	if _cache.has(key):
		return _cache[key] as Font
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font
		if f is FontFile and is_serif:
			# 可变字体：把字重轴拉到 700（若该字体不支持此轴则自动忽略）
			for p in f.get_property_list():
				if str(p["name"]) == "variation_opentype":
					(f as FontFile).set(&"variation_opentype", {&"wght": 700.0})
					break
	if f == null:
		f = _system_font()
		_fallback = true
	_cache[key] = f
	return f

static func _system_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FALLBACK_NAMES)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.multichannel_signed_distance_field = false
	return f

## 一次性设置 Label 的字体、字号与颜色。
## style 可组合："bold"（粗体）、"serif"（宋体）。
static func apply(label: Label, size: int, color: Color, style := "") -> void:
	var want_serif := style.contains("serif")
	var want_bold := style.contains("bold")
	var font := serif() if want_serif else (bold() if want_bold else regular())
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if want_bold and _fallback:
		# 回退字体拿不到真正的粗体，用描边模拟加粗
		label.add_theme_constant_override("outline_size", maxi(1, int(ceil(float(size) / 18.0))))
		label.add_theme_color_override("font_outline_color", color)
