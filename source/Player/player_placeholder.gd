extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_height: float = 1.6
@export var mouse_sens: float = 0.003
@export var cam_stand_height: float = 1.6
@export var cam_crouch_height: float = 1.1
@export var accel: float = 100.0
@export var decel: float = 200.0
@export var air_control: float = 0.35

var inventory := []						# optional: names/ids
var held_stack: Array[Node3D] = []		# actual nodes you picked up
var inventory_holder: Node3D = Node3D.new()

var yaw := 0.0
var pitch := 0.0
var is_crouching := false

@onready var cam: Camera3D = $Camera3D
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Reticle setup ---
enum ReticleState { NONE, PICKUP, DRAG }
var reticle_state := ReticleState.NONE

@export var reticle_tex_none: Texture2D
@export var reticle_tex_pickup: Texture2D
@export var reticle_tex_drag: Texture2D

@onready var reticle: TextureRect = $Control/TextureRect	# <-- change if your path differs

# --- Interact/drag references & state ---
@onready var look_ray: RayCast3D = $Camera3D/LookRay
var grab_anchor: AnimatableBody3D = null	# physics anchor the joint connects to

var dragging_body: RigidBody3D = null
var drag_joint: PinJoint3D = null
var drag_distance: float = 2.0
var mouse_delta_accum := Vector2.ZERO

### store original physics values so we can restore them later
var drag_prev_gravity := 1.0
var drag_prev_lin_damp := 0.0
var drag_prev_ang_damp := 0.0
var drag_hard_lock := true	# when true, freeze+teleport the body so it stays centered
var drag_prev_pos: Vector3 = Vector3.ZERO
var drag_prev_rot: Basis = Basis()
var drag_est_lin_vel: Vector3 = Vector3.ZERO
var drag_est_ang_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_child(inventory_holder)
	inventory_holder.name = "InventoryHolder"

	# Ensure we have a physics anchor under the camera (AnimatableBody3D, no collisions)
	if has_node("Camera3D/GrabAnchor"):
		grab_anchor = $Camera3D/GrabAnchor
	else:
		grab_anchor = AnimatableBody3D.new()
		grab_anchor.name = "GrabAnchor"
		grab_anchor.collision_layer = 0
		grab_anchor.collision_mask = 0
		$Camera3D.add_child(grab_anchor)

	assert(look_ray != null, "LookRay not found at $Camera3D/LookRay")
	assert(cam != null, "Camera3D not found at $Camera3D")

func _input(event: InputEvent) -> void:
	# --- Mouse look ---
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		rotation.y = yaw
		cam.rotation.x = pitch

	# --- Toggle mouse capture with Esc ---
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()

	# --- Recapture mouse on left click if visible ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
	and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Accumulate mouse delta while dragging (for throw impulse) ---
	if event is InputEventMouseMotion and dragging_body:
		mouse_delta_accum += event.relative

	# --- Interactions ---
	if event.is_action_pressed("interact"):
		_try_pickup()

	# --- Start/stop drag (hold LMB = grab) ---
	if event.is_action_pressed("grab"):
		_try_start_drag()
	if event.is_action_released("grab"):
		_release_drag(false)

	# --- Drop (Q) ---
	if event.is_action_pressed("drop"):
		if dragging_body:
			_release_drag(false)
		else:
			drop_from_inventory(false)

	# --- Throw (RMB) ---
	if event.is_action_pressed("throw"):
		if dragging_body:
			_release_drag(true)
		else:
			drop_from_inventory(true)

func _toggle_mouse_capture() -> void:
	var mode = Input.get_mouse_mode()
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	)

func _physics_process(delta: float) -> void:
	# --- Update ray from camera center ---
	look_ray.force_raycast_update()

	# --- Movement input → world direction ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -transform.basis.z		# forward is -Z
	var right := -transform.basis.x			# flipped so strafing is correct
	var wish_dir := (right * input_dir.x + forward * input_dir.y).normalized()

	is_crouching = Input.is_action_pressed("crouch")

	var target_speed := walk_speed
	if Input.is_action_pressed("sprint") and not is_crouching:
		target_speed = sprint_speed
	if is_crouching:
		target_speed *= 0.55

	# --- Horizontal velocity (x/z) ---
	var hv := velocity
	hv.y = 0.0

	var a := accel
	if not is_on_floor():
		a *= air_control

	var target_vel := wish_dir * target_speed
	if wish_dir == Vector3.ZERO:
		hv = hv.move_toward(Vector3.ZERO, decel * delta)
	else:
		hv = hv.move_toward(target_vel, a * delta)

	velocity.x = hv.x
	velocity.z = hv.z

	# --- Gravity & Jump ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = sqrt(2.0 * gravity * jump_height)

	# --- Apply movement ---
	move_and_slide()

	# --- Crouch camera height (simple visual crouch) ---
	var target_cam_y := cam_crouch_height if is_crouching else cam_stand_height
	cam.transform.origin.y = lerp(cam.transform.origin.y, target_cam_y, 10.0 * delta)

	# --- While dragging, move the physics anchor in front of the camera (follows your look) ---
		# --- While dragging, move held body/anchor straight in front of camera ---
	if dragging_body:
		var fwd := -cam.global_transform.basis.z
		var desired := cam.global_position + fwd * drag_distance

		# clamp to first hit so you don't push through walls
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(cam.global_position, desired)
		query.exclude = [dragging_body.get_rid()]
		var hit := space.intersect_ray(query)

		var target := desired
		if hit and hit.has("position"):
			target = hit.position

		if drag_hard_lock:
			# hard lock: place the rigid body exactly at the target
			var gt := dragging_body.global_transform
			gt.origin = target
			dragging_body.global_transform = gt
		else:
			# joint mode: move the anchor instead (will have spring)
			var t := grab_anchor.global_transform
			t.origin = target
			grab_anchor.global_transform = t
	# --- Reticle state update ---
	var new_state := ReticleState.NONE

	if dragging_body:
		new_state = ReticleState.DRAG
	else:
		if look_ray.is_colliding():
			var col := look_ray.get_collider()
			# treat as "pickupable" if it’s a RigidBody3D or has an on_interact handler
			if col is RigidBody3D:
				new_state = ReticleState.PICKUP
			else:
				# climb parents to check for on_interact (e.g., pickup item scripts)
				var n := col
				while n and not n.has_method("on_interact"):
					n = n.get_parent()
				if n and n.has_method("on_interact"):
					new_state = ReticleState.PICKUP

	if new_state != reticle_state:
		reticle_state = new_state
		match reticle_state:
			ReticleState.NONE:
				reticle.texture = reticle_tex_none
			ReticleState.PICKUP:
				reticle.texture = reticle_tex_pickup
			ReticleState.DRAG:
				reticle.texture = reticle_tex_drag

# ---------- Interact helpers ----------

func _try_pickup() -> void:
	if dragging_body: return
	if not look_ray.is_colliding(): return
	var n := look_ray.get_collider()

	# If it has an explicit on_interact, let the item decide
	if n and n.has_method("on_interact"):
		n.on_interact(self)
		return

	# Otherwise, if it's a rigidbody, pick it up into inventory
	if n is RigidBody3D:
		pick_up_node(n as RigidBody3D, "")

func _try_start_drag() -> void:
	if dragging_body: return
	if not look_ray.is_colliding(): return

	var col := look_ray.get_collider()
	if col is RigidBody3D:
		dragging_body = col

		# remember original physics settings
		drag_prev_gravity = dragging_body.gravity_scale
		drag_prev_lin_damp = dragging_body.linear_damp
		drag_prev_ang_damp = dragging_body.angular_damp

		drag_distance = clamp((dragging_body.global_position - cam.global_position).length(), 1.0, 5.0)
		mouse_delta_accum = Vector2.ZERO

		# --- NEW: initialize momentum tracking ---
		drag_prev_pos = dragging_body.global_transform.origin
		drag_prev_rot = dragging_body.global_transform.basis
		drag_est_lin_vel = Vector3.ZERO
		drag_est_ang_vel = Vector3.ZERO

		# initial target point
		var hit_pos := look_ray.get_collision_point()

		if drag_hard_lock:
			dragging_body.gravity_scale = 0.0
			dragging_body.linear_velocity = Vector3.ZERO
			dragging_body.angular_velocity = Vector3.ZERO
			dragging_body.freeze = true
			dragging_body.global_transform.origin = hit_pos
		else:
			var t := grab_anchor.global_transform
			t.origin = hit_pos
			grab_anchor.global_transform = t

			drag_joint = PinJoint3D.new()
			get_tree().current_scene.add_child(drag_joint)
			drag_joint.node_a = dragging_body.get_path()
			drag_joint.node_b = grab_anchor.get_path()

			dragging_body.gravity_scale = 0.0
			dragging_body.linear_damp = 1.0
			dragging_body.angular_damp = 1.0
			dragging_body.freeze = false
	reticle_state = ReticleState.DRAG
	reticle.texture = reticle_tex_drag	

func _release_drag(apply_throw: bool) -> void:
	if not dragging_body:
		return

	# Optional extra throw impulse (RMB)
	if apply_throw:
		var throw_force := mouse_delta_accum.length() * 0.15
		var fwd := -cam.global_transform.basis.z
		dragging_body.apply_central_impulse(fwd * throw_force)

	# If we were using a joint (springy mode), clean it up
	if not drag_hard_lock:
		if is_instance_valid(drag_joint):
			drag_joint.queue_free()
		drag_joint = null

	# Restore original physics settings
	dragging_body.gravity_scale = drag_prev_gravity
	dragging_body.linear_damp = drag_prev_lin_damp
	dragging_body.angular_damp = drag_prev_ang_damp
	dragging_body.freeze = false

	# Apply momentum we estimated while holding
	var inherit := Vector3(velocity.x, 0.0, velocity.z)	# optional: inherit player motion
	dragging_body.linear_velocity = drag_est_lin_vel + inherit
	dragging_body.angular_velocity = drag_est_ang_vel

	# Clear state
	dragging_body = null
	mouse_delta_accum = Vector2.ZERO
	drag_est_lin_vel = Vector3.ZERO
	drag_est_ang_vel = Vector3.ZERO
	
	reticle_state = ReticleState.NONE
	reticle.texture = reticle_tex_none

	

# ---------- Inventory helpers (works for RigidBody3D too) ----------

func pick_up_node(n: Node3D, label: String = "") -> void:
	if label != "":
		inventory.append(label)

	# Hide & disable collisions; freeze if it’s a rigid body
	n.visible = false
	_set_colliders_enabled(n, false)
	if n is RigidBody3D:
		var rb := n as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.freeze = true

	# Reparent to inventory
	if n.get_parent():
		n.get_parent().remove_child(n)
	inventory_holder.add_child(n)

	held_stack.append(n)
	print("Picked up node: ", n.name)

func drop_from_inventory(throw: bool) -> void:
	if held_stack.is_empty():
		return
	var n: Node3D = held_stack.pop_back()

	# Unhide & re-enable collisions; unfreeze if rigid
	n.visible = true
	_set_colliders_enabled(n, true)

	inventory_holder.remove_child(n)
	get_tree().current_scene.add_child(n)

	var fwd := -cam.global_transform.basis.z
	n.global_transform.origin = cam.global_position + fwd * 1.0

	if n is RigidBody3D:
		var rb := n as RigidBody3D
		rb.freeze = false
		if throw:
			rb.apply_central_impulse(fwd * 6.0)

func _set_colliders_enabled(root: Node, enabled: bool) -> void:
	for child in root.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled
		_set_colliders_enabled(child, enabled)
