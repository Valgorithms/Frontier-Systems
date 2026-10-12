extends Control
class_name MachineryContextCard

## One client-only card anchored to the exact picked assembly. No input ownership.
const MARGIN: float = 12.0
var target: Node3D
var _panel: PanelContainer
var _lines: Array[Label] = []
var _anchor := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18232f")
	style.border_color = Color("#ffe066")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rows)
	for index in range(4):
		var line := Label.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_font_size_override("font_size", 16)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		rows.add_child(line)
		_lines.append(line)
	visible = false

func present(proxy: Node3D, lines: PackedStringArray) -> void:
	target = proxy
	for index in range(_lines.size()):
		_lines[index].text = lines[index] if index < lines.size() else ""
	_process(0.0)

func _process(_delta: float) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		visible = false
		return
	var extent: Vector2 = viewport.get_visible_rect().size
	var camera: Camera3D = viewport.get_camera_3d()
	visible = is_instance_valid(target) and camera != null and extent.x >= 180 and extent.y >= 160
	if not visible: return
	if camera.is_position_behind(target.global_position):
		visible = false
		return
	_anchor = camera.unproject_position(target.global_position)
	visible = Rect2(Vector2.ZERO, extent).has_point(_anchor)
	if not visible: return
	size = extent
	_panel.size = Vector2(minf(420, extent.x - MARGIN * 2), 116)
	_panel.position = Vector2(MARGIN, extent.y - _panel.size.y - MARGIN)
	queue_redraw()

func _draw() -> void:
	if not visible: return
	var edge := Vector2(clampf(_anchor.x, _panel.position.x, _panel.position.x + _panel.size.x), _panel.position.y)
	draw_line(edge, _anchor, Color("#ffe066"), 1.5, true)
	draw_circle(_anchor, 3.0, Color("#ffe066"))