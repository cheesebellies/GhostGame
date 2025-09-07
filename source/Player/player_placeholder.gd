extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_height: float = 1.6
@export var mouse_sens: float = 0.003   # radians per pixel
@export var cam_stand_height: float = 1.6
@export var cam_crouch_height: float = 1.1
@export var accel: float = 10.0          # how fast you reach target speed
@export var decel: float = 20.0          # how fast you slow down
@export var air_control: float = 0.35    # 0–1, movement control in air

var yaw := 0.0
var pitch := 0.0
var is_crouching := false

@onready var cam: Camera3D = $Camera3D
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Yaw on body, pitch on camera
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		rotation.y = yaw
		cam.rotation.x = pitch

	# Toggle capture with Esc
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()

	# Recapture on left-click
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed \
	and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
func _toggle_mouse_capture() -> void:
	var mode = Input.get_mouse_mode()
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	)

func _physics_process(delta: float) -> void:
	# --- Input ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward   := -transform.basis.z   # forward is -Z
	var right     :=  -transform.basis.x
	var wish_dir  := (right * input_dir.x + forward * input_dir.y).normalized()

	is_crouching = Input.is_action_pressed("crouch")

	var target_speed := walk_speed
	if Input.is_action_pressed("sprint") and not is_crouching:
		target_speed = sprint_speed
	if is_crouching:
		target_speed *= 0.55  # slower while crouched

	# --- Horizontal velocity (x/z) ---
	var hv := velocity
	hv.y = 0.0

	var a := accel
	if not is_on_floor():
		a *= air_control   # less control in air

	var target_vel := wish_dir * target_speed
	if wish_dir == Vector3.ZERO:
		# decelerate to a stop
		hv = hv.move_toward(Vector3.ZERO, decel * delta)
	else:
		# accelerate toward target velocity
		hv = hv.move_toward(target_vel, a * delta)

	velocity.x = hv.x
	velocity.z = hv.z

	# --- Gravity & Jump ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump") and not is_crouching:
			# v = sqrt(2gh)
			velocity.y = sqrt(2.0 * gravity * jump_height)

	# --- Apply movement ---
	move_and_slide()

	# --- Crouch camera height (simple visual crouch) ---
	var target_cam_y := cam_crouch_height if is_crouching else cam_stand_height
	cam.transform.origin.y = lerp(cam.transform.origin.y, target_cam_y, 10.0 * delta)
