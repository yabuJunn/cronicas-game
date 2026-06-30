class_name StepTester
extends RefCounted

const MAX_STEP_HEIGHT := 0.5
const MAX_STEP_SLOPE := 50.0

static func try_step_up(
	body: CharacterBody3D,
	velocity: Vector3,
	delta: float
) -> StepResult:

	var step := StepResult.new()

	var motion := Vector3(
		velocity.x,
		0,
		velocity.z
	) * delta

	if motion.length() < 0.01:
		return step

	var transform := body.global_transform

	# ---------- TEST 1 ----------
	var up_test = MotionTester.test_motion(
		body,
		transform,
		Vector3.UP * MAX_STEP_HEIGHT
	)

	if up_test["collided"]:
		return step

	# ---------- TEST 2 ----------
	var elevated := transform
	elevated.origin += Vector3.UP * MAX_STEP_HEIGHT

	var forward_test = MotionTester.test_motion(
		body,
		elevated,
		motion
	)

	if forward_test["collided"]:
		return step

	# ---------- TEST 3 ----------
	elevated.origin += motion

	var down_test = MotionTester.test_motion(
		body,
		elevated,
		Vector3.DOWN * MAX_STEP_HEIGHT
	)

	if !down_test["collided"]:
		return step

	var physics_result : PhysicsTestMotionResult3D = down_test["result"]

	if physics_result.get_collision_normal().angle_to(Vector3.UP) > deg_to_rad(MAX_STEP_SLOPE):
		return step

	step.success = true
	step.offset = -physics_result.get_remainder()
	step.normal = physics_result.get_collision_normal()

	return step
