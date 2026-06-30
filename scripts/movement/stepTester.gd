class_name StepTester
extends RefCounted

const MAX_STEP_HEIGHT := 0.5
const MAX_STEP_SLOPE := 50.0

const STEP_CHECK_COUNT := 4
const WALL_MARGIN := 0.001
const MAX_SLIDE_ITERATIONS := 3

const FLOOR_SEARCH_RADIUS := 0.02

const FLOOR_OFFSETS := [

	Vector3.ZERO,

	Vector3( FLOOR_SEARCH_RADIUS,0,0),
	Vector3(-FLOOR_SEARCH_RADIUS,0,0),

	Vector3(0,0, FLOOR_SEARCH_RADIUS),
	Vector3(0,0,-FLOOR_SEARCH_RADIUS),

	Vector3( FLOOR_SEARCH_RADIUS,0, FLOOR_SEARCH_RADIUS),
	Vector3(-FLOOR_SEARCH_RADIUS,0, FLOOR_SEARCH_RADIUS),
	Vector3( FLOOR_SEARCH_RADIUS,0,-FLOOR_SEARCH_RADIUS),
	Vector3(-FLOOR_SEARCH_RADIUS,0,-FLOOR_SEARCH_RADIUS),

]

static func try_step_up(
	body: CharacterBody3D,
	velocity: Vector3,
	delta: float
) -> StepResult:

	var motion := Vector3(
		velocity.x,
		0,
		velocity.z
	) * delta

	var step := StepResult.new()

	if motion.length() < 0.01:
		return step

	for i in STEP_CHECK_COUNT:

		var height := MAX_STEP_HEIGHT - (
			float(i) * MAX_STEP_HEIGHT / STEP_CHECK_COUNT
		)

		step = _try_height(
			body,
			motion,
			height
		)

		if step.success:
			return step

	return StepResult.new()



static func _try_height(

	body: CharacterBody3D,
	motion: Vector3,
	height: float

) -> StepResult:

	var step := StepResult.new()

	var transform := body.global_transform



	#--------------------------
	# SUBIR
	#--------------------------

	if MotionTester.test_motion(
		body,
		transform,
		Vector3.UP * height
	)["collided"]:

		return step

	transform.origin += Vector3.UP * height



	#--------------------------
	# AVANZAR
	#--------------------------

	var forward := _try_forward(
		body,
		transform,
		motion
	)

	if !forward["success"]:
		return step

	transform = forward["transform"]

	motion = forward["motion"]



	#--------------------------
	# BAJAR
	#--------------------------

	return _try_down(
		body,
		transform,
		height
	)



static func _try_forward(

	body,
	transform,
	motion

) -> Dictionary:

	var result = MotionTester.test_motion(
		body,
		transform,
		motion
	)

	if !result["collided"]:

		transform.origin += motion

		return {

			"success": true,
			"transform": transform,
			"motion": motion

		}



	return _try_wall_slide(
								
		body,
		transform,
		result["result"]

	)


static func _try_wall_slide(

	body,
	transform,
	collision: PhysicsTestMotionResult3D

) -> Dictionary:

	var current_transform = transform
	var current_collision = collision

	for i in MAX_SLIDE_ITERATIONS:

		var normal := current_collision.get_collision_normal()

		# Si es suelo o techo abortamos.
		if abs(normal.y) > 0.1:
			return {
				"success": false
			}

		# Avanzar únicamente lo que Godot permitió.
		current_transform.origin += current_collision.get_travel()

		# Separarnos ligeramente.
		current_transform.origin += normal * WALL_MARGIN

		# Lo que falta por recorrer.
		var remaining_motion := current_collision.get_remainder()

		# Deslizar únicamente el resto.
		var slide_motion := remaining_motion.slide(normal)

		if slide_motion.length() < 0.001:
			return {
				"success": false
			}

		var test := MotionTester.test_motion(
			body,
			current_transform,
			slide_motion
		)

		if !test["collided"]:

			current_transform.origin += slide_motion

			return {
				"success": true,
				"transform": current_transform,
				"motion": slide_motion
			}

		current_collision = test["result"]

	return {
		"success": false
	}



static func _try_down(

	body,
	transform,
	height

) -> StepResult:

	var best_step := StepResult.new()
	var best_distance := INF

	for offset in FLOOR_OFFSETS:

		var candidate = transform
		candidate.origin += offset

		var down := MotionTester.test_motion(

			body,
			candidate,
			Vector3.DOWN * height

		)

		if !down["collided"]:
			continue

		var physics : PhysicsTestMotionResult3D = down["result"]

		if !_validate_floor(physics):
			continue

		var distance := physics.get_remainder().length()

		if distance < best_distance:

			best_distance = distance

			best_step.success = true
			best_step.offset = offset - physics.get_remainder()
			best_step.normal = physics.get_collision_normal()

	return best_step



static func _validate_floor(

	physics: PhysicsTestMotionResult3D

) -> bool:

	var normal := physics.get_collision_normal()

	if normal.angle_to(Vector3.UP) > deg_to_rad(MAX_STEP_SLOPE):
		return false

	# No aceptar techos.

	if normal.y <= 0:
		return false

	# Debe existir movimiento hacia abajo.

	if physics.get_travel().y > 0:
		return false

	return true
