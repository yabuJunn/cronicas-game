class_name MotionTester
extends RefCounted


static func test_motion(
	body: CharacterBody3D,
	from: Transform3D,
	motion: Vector3
) -> Dictionary:

	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion

	var result := PhysicsTestMotionResult3D.new()

	var collided := PhysicsServer3D.body_test_motion(
		body.get_rid(),
		params,
		result
	)

	return {
		"collided": collided,
		"result": result
	}
