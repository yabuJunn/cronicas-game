extends CharacterBody3D

# Jugador
# Altura: 1.80 metros
# Radio: 0.35 m

const WALK_SPEED = 5.0 #Default is 5
const SPRINT_SPEED = 50.0 #Default is 8 Debug 40
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

var gravity = 9.8
var camera_enabled := true

@onready var camera_pivot := $CameraPivot
@onready var interact_ray := $CameraPivot/Camera3D/InteractionRayCast
@onready var interact_prompt := $HUD/InteractPrompt

var camera_offset := Vector3.ZERO
const CAMERA_STEP_SPEED := 14.0

# Guardamos el objeto que estamos mirando actualmente
var current_interactable = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
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
	
	var step_up := StepTester.try_step_up(self, Vector3(velocity.x, 0, velocity.z), delta)
	if step_up.success:
		apply_step(step_up)
		
	# Sonidos de pasos
	if velocity.length() != 0 and is_on_floor():
		if $Steps/StepsTimer.time_left <= 0:
			$Steps/StepsSound.pitch_scale = randf_range(0.8, 1.2)
			$Steps/StepsSound.play()
			if Input.is_action_pressed("sprint"):
				$Steps/StepsTimer.start(0.25)
			else:
				$Steps/StepsTimer.start(0.5)
	
	move_and_slide()
	
	if direction != Vector3.ZERO:
		var step_down := StepTester.try_step_down(self, Vector3(velocity.x, 0, velocity.z), delta)
		if step_down.success:
			apply_step(step_down)						
			
	camera_offset = camera_offset.lerp(Vector3.ZERO, delta * CAMERA_STEP_SPEED)
	camera_pivot.position = camera_offset
	
	# --- SISTEMA DE DETECCIÓN VISUAL ---
	var collider = interact_ray.get_collider() if interact_ray.is_colliding() else null
	
	# MEJORA DE SEGURIDAD: Si el objeto es destruido O si se quitó del grupo (ej: al abrir la puerta)
	if current_interactable != null:
		if not is_instance_valid(current_interactable) or not current_interactable.is_in_group("interactibleObjects"):
			current_interactable = null
			interact_prompt.hide()
	
	if collider != current_interactable:
		# Apagar el highlight del objeto anterior si aún existe
		if current_interactable != null and is_instance_valid(current_interactable):
			current_interactable.set_highlight(false)
			interact_prompt.hide()
			
		# Detectar el nuevo objeto
		if collider != null and collider.is_in_group("interactibleObjects") and not collider.is_queued_for_deletion():
			current_interactable = collider
			current_interactable.set_highlight(true)
			
			# --- ASIGNACIÓN DINÁMICA DEL TEXTO DE INTERFAZ (UI) ---
			if "texto_interaccion" in current_interactable:
				# Si el objeto define su propio texto personalizado (como tu puerta)
				interact_prompt.text = current_interactable.texto_interaccion
			elif "se_puede_recoger" in current_interactable and current_interactable.se_puede_recoger:
				# Si es un objeto común y corriente que va al inventario (llaves, pociones)
				interact_prompt.text = "[ E ] Recoger " + current_interactable.item_name
			else:
				# Texto seguro por defecto por si acaso
				interact_prompt.text = "[ E ] Interactuar"
				
			interact_prompt.show()
		else:
			current_interactable = null
			interact_prompt.hide()


func _unhandled_input(event):
	if !camera_enabled:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		$CameraPivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		$CameraPivot.rotation.x = clamp($CameraPivot.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func apply_step(step: StepResult) -> void:
	if abs(step.offset.y) < 0.01:
		return
	global_position += step.offset
	camera_offset -= step.offset
	

func _input(event):
	if event.is_action_pressed("ui_cancel_custom"):
		camera_enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			camera_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- ENTRADA DE INTERACCIÓN (TECLA E) ---
	if event.is_action_pressed("interact") and current_interactable != null:
		if is_instance_valid(current_interactable):
			# Llamamos a la función de la clase base o clase hija
			current_interactable.interactuar()
			
			# Limpiamos inmediatamente la interfaz para evitar el "texto fantasma"
			current_interactable = null
			interact_prompt.hide()
