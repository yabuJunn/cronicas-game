extends CharacterBody3D

#Jugador

#Altura:
#1.80 metros

#Radio:
#0.35 m

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

var gravity = 9.8

var camera_enabled := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector(
	"move_left",
	"move_right",
	"move_forward",
    "move_back"
	)

	var direction = (
		transform.basis *
		Vector3(input_dir.x, 0, input_dir.y)
	).normalized()
	
	var speed = WALK_SPEED

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	var step := StepTester.try_step_up(
		self,
		Vector3(
			velocity.x,
			0,
			velocity.z
		),
		delta
	)

	if step.success:
		apply_step(step)
		
	move_and_slide()


func _unhandled_input(event):
	if !camera_enabled:
		return

	if event is InputEventMouseMotion:

		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		$CameraPivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)

		$CameraPivot.rotation.x = clamp(
			$CameraPivot.rotation.x,
			deg_to_rad(-85),
			deg_to_rad(85)
		)

func apply_step(step: StepResult) -> void:
	global_position += step.offset
	
func _input(event):

	if event.is_action_pressed("ui_cancel_custom"):
		camera_enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			camera_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
