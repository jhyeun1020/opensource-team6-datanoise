extends CharacterBody3D
## 플레이어 (담당 A)
## 1인칭 이동, 손전등(배터리), 상호작용(E), 발소리 소음.
##
## 뼈대에서 정한 규칙(기획안 9p "손전등 제약"에 대한 제안):
##   - 손전등은 켜둔 동안 배터리가 줄고, 끄면 천천히 회복한다.
##   - 터미널 조작(미니게임) 중에는 손전등을 켤 수 없다. → 정제하다가 뒤돌아 비춰야 하는 긴장을 만든다.

signal battery_changed(ratio: float)
signal flashlight_toggled(on: bool)
signal interact_target_changed(target: Node)  # null이면 프롬프트 숨김

@export var walk_speed := 3.5
@export var sprint_speed := 6.0
@export var mouse_sensitivity := 0.0025
@export var battery_max := 25.0          # 켜둔 채 버틸 수 있는 초
@export var battery_drain := 1.0         # 초당 소모
@export var battery_recharge := 0.6      # 꺼둔 상태에서 초당 회복
@export var battery_min_to_turn_on := 2.0
@export var footstep_distance := 2.2     # 이 거리마다 발소리 소음 1회

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

var battery: float
var flashlight_on := false
var input_locked := false

var _step_accum := 0.0
var _mouse_warmup := 0.0
var _current_target: Node = null
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	battery = battery_max
	flashlight.visible = false
	interact_ray.add_exception(self)
	GameManager.register_player(self)
	GameManager.minigame_started.connect(func(_t): _set_locked(true))
	GameManager.minigame_finished.connect(func(_t, _ok): _set_locked(false))
	GameManager.player_died.connect(func(): _set_locked(true))
	GameManager.player_respawned.connect(_on_respawned)
	GameManager.game_won.connect(func(): _set_locked(true))
	_capture_mouse()
	_set_flashlight(true)  # 시작은 켜진 상태. 끄는 선택을 플레이어가 하게 한다.


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_warmup = 0.5  # 캡처 직후 커서 워프로 생기는 큰 relative 이벤트를 무시하는 시간


# ---------------------------------------------------------------- 입력

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not input_locked \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 마우스 캡처 직후 첫 이벤트는 커서 워프 때문에 relative가 크게 튄다 → 무시
		if _mouse_warmup > 0.0:
			return
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))
		return

	if input_locked:
		return

	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("ui_cancel"):
		# 에디터 테스트용: ESC로 마우스 해제 / 재캡처
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			_capture_mouse()
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_capture_mouse()


func _physics_process(delta: float) -> void:
	_mouse_warmup = maxf(_mouse_warmup - delta, 0.0)
	_update_battery(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var dir := Vector3.ZERO
	var sprinting := false
	if not input_locked:
		var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
		sprinting = Input.is_action_pressed("sprint")

	var speed := sprint_speed if sprinting else walk_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	_update_footsteps(delta, sprinting)
	_update_interact_prompt()


# ---------------------------------------------------------------- 손전등

func _update_battery(delta: float) -> void:
	if flashlight_on:
		battery = maxf(battery - battery_drain * delta, 0.0)
		if battery <= 0.0:
			_set_flashlight(false)
	else:
		battery = minf(battery + battery_recharge * delta, battery_max)
	battery_changed.emit(battery / battery_max)


func _toggle_flashlight() -> void:
	if flashlight_on:
		_set_flashlight(false)
	elif battery >= battery_min_to_turn_on:
		_set_flashlight(true)


func _set_flashlight(on: bool) -> void:
	if flashlight_on == on:
		return
	flashlight_on = on
	flashlight.visible = on
	flashlight_toggled.emit(on)
	# TODO(사운드): 손전등 클릭음 AudioStreamPlayer 재생


## 괴물 쪽에서 호출: 지금 손전등 빛이 target 지점에 닿고 있는가?
## (켜져 있고, 사거리 안이고, 원뿔 각도 안이고, 사이에 벽이 없을 때)
func is_lighting(target: Vector3) -> bool:
	if not flashlight_on:
		return false
	var origin := flashlight.global_position
	var to_target := target - origin
	var dist := to_target.length()
	if dist > flashlight.spot_range or dist < 0.001:
		return false
	var forward := -flashlight.global_transform.basis.z
	if rad_to_deg(forward.angle_to(to_target / dist)) > flashlight.spot_angle:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == GameManager.monster


func eye_position() -> Vector3:
	return camera.global_position


# ---------------------------------------------------------------- 발소리

func _update_footsteps(delta: float, sprinting: bool) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.1 or not is_on_floor():
		return
	_step_accum += horizontal * delta
	if _step_accum >= footstep_distance:
		_step_accum = 0.0
		GameManager.emit_noise(global_position, 0.45 if sprinting else 0.2)
		# TODO(사운드): 발소리 AudioStreamPlayer3D 재생


# ---------------------------------------------------------------- 상호작용

func _update_interact_prompt() -> void:
	var target: Node = null
	if not input_locked and interact_ray.is_colliding():
		var c := interact_ray.get_collider()
		if c and c.has_method("interact"):
			if not c.has_method("can_interact") or c.can_interact():
				target = c
	if target != _current_target:
		_current_target = target
		interact_target_changed.emit(target)


func _try_interact() -> void:
	if _current_target:
		_current_target.interact(self)
		# 문처럼 상태에 따라 문구가 바뀌는 대상(열기/닫기)을 HUD가 다시 읽게 한다
		if is_instance_valid(_current_target):
			interact_target_changed.emit(_current_target)


# ---------------------------------------------------------------- 잠금 / 리스폰

func _set_locked(locked: bool) -> void:
	input_locked = locked
	if locked:
		velocity = Vector3.ZERO
		_set_flashlight(false)
		if _current_target:
			_current_target = null
			interact_target_changed.emit(null)
	elif not GameManager.is_dead and not GameManager.has_won:
		_capture_mouse()


func _on_respawned(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	battery = battery_max
	battery_changed.emit(1.0)
	_set_locked(false)
