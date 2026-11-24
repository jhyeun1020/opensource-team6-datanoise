extends Control
## HUD (담당 C 또는 D)
## 배터리, 정제 진행도, 상호작용 프롬프트, 사망/탈출 화면, 괴물 상태 디버그 표시.

var _nodes: Label
var _battery: ProgressBar
var _flash_label: Label
var _prompt: Label
var _center_bg: ColorRect
var _center: Label
var _debug: Label


func _ready() -> void:
	_build()
	GameManager.node_purified.connect(_on_node_purified)
	GameManager.player_died.connect(_on_player_died)
	GameManager.player_respawned.connect(func(_pos): _hide_center())
	GameManager.game_won.connect(_on_game_won)
	# 플레이어/괴물은 같은 프레임에 _ready 되므로 한 프레임 뒤에 연결한다.
	await get_tree().process_frame
	var p := GameManager.player
	if p:
		_flash_label.text = "손전등 [F]  %s" % ("ON" if p.flashlight_on else "OFF")
		p.battery_changed.connect(func(ratio: float): _battery.value = ratio)
		p.flashlight_toggled.connect(func(on: bool): _flash_label.text = "손전등 [F]  %s" % ("ON" if on else "OFF"))
		p.interact_target_changed.connect(_on_interact_target_changed)
	var m := GameManager.monster
	if m:
		m.state_changed.connect(func(state_name: String): _debug.text = "MONSTER: " + state_name)


func _on_interact_target_changed(target: Node) -> void:
	_prompt.visible = target != null
	if target:
		var custom = target.get("prompt_text")  # 대상이 문구를 정하면 그걸 쓴다 (예: 로비 문)
		_prompt.text = custom if custom is String else "[E]  터미널 정제"


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.has_won and event.is_action_pressed("restart"):
		GameManager.restart()


# ---------------------------------------------------------------- 구성

func _build() -> void:
	_nodes = Label.new()
	_nodes.text = "정제된 노드  0 / %d" % GameManager.TOTAL_NODES
	_nodes.add_theme_font_size_override("font_size", 20)
	add_child(_nodes)
	_nodes.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nodes.offset_left = 24
	_nodes.offset_top = 20
	_nodes.offset_right = 420
	_nodes.offset_bottom = 50

	var box := VBoxContainer.new()
	add_child(box)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 24
	box.offset_top = -90
	box.offset_right = 304
	box.offset_bottom = -24
	_flash_label = Label.new()
	_flash_label.text = "손전등 [F]  OFF"
	_flash_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_flash_label)
	_battery = ProgressBar.new()
	_battery.min_value = 0.0
	_battery.max_value = 1.0
	_battery.value = 1.0
	_battery.show_percentage = false
	_battery.custom_minimum_size = Vector2(280, 16)
	box.add_child(_battery)

	var cross := Label.new()
	cross.text = "·"
	cross.add_theme_font_size_override("font_size", 28)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(cross)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -16
	cross.offset_right = 16
	cross.offset_top = -16
	cross.offset_bottom = 16

	_prompt = Label.new()
	_prompt.text = "[E]  터미널 정제"
	_prompt.visible = false
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	add_child(_prompt)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -250
	_prompt.offset_right = 250
	_prompt.offset_top = -170
	_prompt.offset_bottom = -120

	_center_bg = ColorRect.new()
	_center_bg.color = Color(0, 0, 0, 0.75)
	_center_bg.visible = false
	_center_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_bg)
	_center_bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	_center = Label.new()
	_center.visible = false
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.add_theme_font_size_override("font_size", 34)
	add_child(_center)
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.offset_left = -450
	_center.offset_right = 450
	_center.offset_top = -140
	_center.offset_bottom = 140

	_debug = Label.new()
	_debug.text = "MONSTER: DORMANT"
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug.add_theme_font_size_override("font_size", 14)
	_debug.modulate = Color(1, 1, 1, 0.5)
	add_child(_debug)
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.offset_left = -380
	_debug.offset_right = -24
	_debug.offset_top = 20
	_debug.offset_bottom = 44


# ---------------------------------------------------------------- 이벤트

func _on_node_purified(_index: int, count: int) -> void:
	_nodes.text = "정제된 노드  %d / %d" % [count, GameManager.TOTAL_NODES]


func _on_player_died() -> void:
	_show_center("SIGNAL LOST\n\n괴물과 접촉했다.\n마지막 정제 지점으로 복귀합니다.", Color(1.0, 0.25, 0.3))


func _on_game_won() -> void:
	_show_center("ESCAPED\n\n세 번의 정제, 하나의 탈출.\n\n[R]  다시 시작", Color(0.4, 1.0, 0.6))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_center(text: String, color: Color) -> void:
	_center.text = text
	_center.add_theme_color_override("font_color", color)
	_center.visible = true
	_center_bg.visible = true


func _hide_center() -> void:
	_center.visible = false
	_center_bg.visible = false
