extends Control
## 정제 미니게임 UI (담당 C)
##
## 기획안 5p: 짧은 입력(10~20초)으로 서버를 복구한다.
##   SEQUENCE : 화면의 0/1 배열을 왼쪽부터 순서대로 입력한다. 틀리면 처음부터.
##   PATTERN  : 패턴을 잠깐 보여준 뒤 가린다. 기억해서 입력하고, 틀리면 다시 보여준다.
##
## 뼈대에서 정한 규칙(기획안 9p "오답·재시도" 제안):
##   - 키 입력마다 작은 소음(0.3) → 정제 자체가 괴물을 부른다.
##   - 오답은 큰 소음(1.0) → 괴물이 바로 추격해 온다. 즉사는 아님.
##   - 제한시간 초과 = 실패 + 큰 소음. 터미널은 그대로 남아 다시 시도할 수 있다.
##   - ESC = 중단(소음 없음). 괴물이 다가오는 소리가 들리면 끊고 돌아서 비추는 게 의도된 플레이.

@export var time_limit := 20.0
@export var sequence_length := 6
@export var pattern_length := 4
@export var pattern_show_time := 2.5
@export var key_noise := 0.3
@export var mistake_noise := 1.0

var _terminal: Terminal = null
var _target: Array[int] = []
var _input: Array[int] = []
var _time_left := 0.0
var _pattern_hidden := false
var _show_timer := 0.0
var _mistakes := 0
var _resolving := false

var _title: Label
var _hint: Label
var _target_row: HBoxContainer
var _input_row: HBoxContainer
var _status: Label
var _timer_bar: ProgressBar


func _ready() -> void:
	visible = false
	_build_ui()
	GameManager.minigame_started.connect(_start)
	GameManager.player_died.connect(_on_player_died)


# ---------------------------------------------------------------- UI 구성 (코드로 생성)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(600, 0)
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_title = _make_label(vbox, 30)
	_hint = _make_label(vbox, 16)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.modulate = Color(0.8, 0.85, 0.9)

	_target_row = HBoxContainer.new()
	_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_target_row)

	_input_row = HBoxContainer.new()
	_input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_input_row.add_theme_constant_override("separation", 10)
	vbox.add_child(_input_row)

	_status = _make_label(vbox, 20)

	_timer_bar = ProgressBar.new()
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 1.0
	_timer_bar.value = 1.0
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(_timer_bar)


func _make_label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _make_cell(row: Node, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(56, 64)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	row.add_child(l)


func _clear_row(row: Node) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _rebuild_rows() -> void:
	_clear_row(_target_row)
	_clear_row(_input_row)
	var hide_target := _terminal.mode == Terminal.Mode.PATTERN and _pattern_hidden
	for i in _target.size():
		if hide_target:
			_make_cell(_target_row, "?", Color(0.5, 0.5, 0.55))
		else:
			var done := _terminal.mode == Terminal.Mode.SEQUENCE and i < _input.size()
			_make_cell(_target_row, str(_target[i]), Color(0.3, 1.0, 0.6) if done else Color(0.95, 0.95, 1.0))
	for i in _target.size():
		if i < _input.size():
			_make_cell(_input_row, str(_input[i]), Color(0.6, 0.9, 1.0))
		else:
			_make_cell(_input_row, "_", Color(0.35, 0.35, 0.4))


# ---------------------------------------------------------------- 진행

func _start(terminal: Node) -> void:
	_terminal = terminal as Terminal
	if _terminal == null:
		return
	_time_left = time_limit
	_mistakes = 0
	_resolving = false
	_input.clear()
	_target.clear()
	var n := sequence_length if _terminal.mode == Terminal.Mode.SEQUENCE else pattern_length
	for i in n:
		_target.append(randi() % 2)
	_pattern_hidden = false
	_show_timer = pattern_show_time

	_title.text = _terminal.title + "  ·  정제"
	match _terminal.mode:
		Terminal.Mode.SEQUENCE:
			_hint.text = "위 배열을 왼쪽부터 순서대로 입력하세요.  [0] [1]  ·  ESC 중단"
		Terminal.Mode.PATTERN:
			_hint.text = "패턴을 기억하세요. %d초 뒤 가려집니다. 그 다음 [0] [1]로 입력  ·  ESC 중단" % int(pattern_show_time)
	_status.text = "입력할 때마다 소음이 납니다"
	_timer_bar.value = 1.0
	_rebuild_rows()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not visible or _resolving or _terminal == null:
		return
	_time_left -= delta
	_timer_bar.value = _time_left / time_limit

	if _terminal.mode == Terminal.Mode.PATTERN and not _pattern_hidden:
		_show_timer -= delta
		if _show_timer <= 0.0:
			_pattern_hidden = true
			_status.text = "패턴을 입력하세요"
			_rebuild_rows()

	if _time_left <= 0.0:
		_status.text = "시간 초과 · 정제 실패"
		GameManager.emit_noise(_terminal.global_position, mistake_noise)
		_resolve(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _resolving or _terminal == null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)
		return
	var bit := -1
	if event.is_action_pressed("bit_0"):
		bit = 0
	elif event.is_action_pressed("bit_1"):
		bit = 1
	if bit == -1:
		return
	get_viewport().set_input_as_handled()
	if _terminal.mode == Terminal.Mode.PATTERN and not _pattern_hidden:
		return  # 아직 패턴을 보는 중
	_on_bit(bit)


func _on_bit(bit: int) -> void:
	GameManager.emit_noise(_terminal.global_position, key_noise)
	match _terminal.mode:
		Terminal.Mode.SEQUENCE:
			if bit == _target[_input.size()]:
				_input.append(bit)
				if _input.size() == _target.size():
					_succeed()
					return
			else:
				_input.clear()
				_mistake()
		Terminal.Mode.PATTERN:
			_input.append(bit)
			if _input.size() == _target.size():
				if _input == _target:
					_succeed()
					return
				_input.clear()
				_pattern_hidden = false
				_show_timer = pattern_show_time
				_mistake()
	_rebuild_rows()


func _mistake() -> void:
	_mistakes += 1
	_status.text = "오답! 큰 소음 발생 (%d회)" % _mistakes
	GameManager.emit_noise(_terminal.global_position, mistake_noise)
	# TODO(사운드): 오류 비프 + 글리치


func _succeed() -> void:
	_status.text = "정제 완료"
	_rebuild_rows()
	_resolve(true)


func _resolve(success: bool) -> void:
	_resolving = true
	await get_tree().create_timer(0.7).timeout
	if _terminal != null:
		_finish(success)


func _finish(success: bool) -> void:
	visible = false
	_resolving = false
	var t := _terminal
	_terminal = null
	GameManager.finish_minigame(t, success)


func _on_player_died() -> void:
	if visible:
		_finish(false)
