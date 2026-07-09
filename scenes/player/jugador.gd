extends CharacterBody3D

# Jugador
# Altura: 1.80 metros
# Radio: 0.35 m

const WALK_SPEED = 5.0 #Default is 5
const SPRINT_SPEED = 9 #Default is 9
const JUMP_VELOCITY = 6 #Default is 6
const MOUSE_SENSITIVITY = 0.003

var gravity = 9.8
var camera_enabled := true

var controles_bloqueados := false
var was_on_floor := true 

@onready var camera_pivot := $CameraPivot
@onready var camera_3d := $CameraPivot/Camera3D # <--- NUEVA REFERENCIA DIRECTA
@onready var interact_ray := $CameraPivot/Camera3D/InteractionRayCast
@onready var interact_prompt := $HUD/InteractPrompt
@onready var miscellaneousSoundsPlayer := $Sounds/MiscellaneousSounds
@onready var jumpSoundPlayer: AudioStreamPlayer3D = $Sounds/Jump/JumpSound
@onready var landingSoundPlayer: AudioStreamPlayer3D = $Sounds/Jump/LandingSound

var pickUpSound = preload("res://sounds/player/Pick Up Item.mp3")

var camera_offset := Vector3.ZERO
const CAMERA_STEP_SPEED := 14.0

# Guardamos el objeto que estamos mirando actualmente
var current_interactable = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Nos añadimos a un grupo para que cualquier objeto del mapa nos encuentre fácil
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# --- SI LOS CONTROLES ESTÁN BLOQUEADOS, FRENAMOS Y LE JUGADORE NO MUEVE NADA ---
	if controles_bloqueados:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return # Saltamos el resto del proceso de inputs

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var speed = WALK_SPEED
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumpSoundPlayer.play()
		
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
		if $Sounds/Steps/StepsTimer.time_left <= 0:
			$Sounds/Steps/StepsSound.pitch_scale = randf_range(0.8, 1.2)
			$Sounds/Steps/StepsSound.play()
			if Input.is_action_pressed("sprint"):
				$Sounds/Steps/StepsTimer.start(0.25)
			else:
				$Sounds/Steps/StepsTimer.start(0.5)
	
	move_and_slide()
	
	if is_on_floor() and not was_on_floor:
		landingSoundPlayer.play()
	
	was_on_floor = is_on_floor()
	
	if direction != Vector3.ZERO:
		var step_down := StepTester.try_step_down(self, Vector3(velocity.x, 0, velocity.z), delta)
		if step_down.success:
			apply_step(step_down)						
			
	camera_offset = camera_offset.lerp(Vector3.ZERO, delta * CAMERA_STEP_SPEED)
	camera_pivot.position = camera_offset
	
	# --- SISTEMA DE DETECCIÓN VISUAL ---
	var collider = interact_ray.get_collider() if interact_ray.is_colliding() else null
	
	if current_interactable != null:
		if not is_instance_valid(current_interactable) or not current_interactable.is_in_group("interactibleObjects"):
			current_interactable = null
			interact_prompt.hide()
	
	if collider != current_interactable:
		if current_interactable != null and is_instance_valid(current_interactable):
			current_interactable.set_highlight(false)
			interact_prompt.hide()
			
		if collider != null and collider.is_in_group("interactibleObjects") and not collider.is_queued_for_deletion():
			current_interactable = collider
			current_interactable.set_highlight(true)
			
			if "texto_interaccion" in current_interactable:
				interact_prompt.text = current_interactable.texto_interaccion
			elif "se_puede_recoger" in current_interactable and current_interactable.se_puede_recoger:
				interact_prompt.text = "[ E ] Recoger " + current_interactable.item_name
			else:
				interact_prompt.text = "[ E ] Interactuar"
				
			interact_prompt.show()
		else:
			current_interactable = null
			interact_prompt.hide()


func _unhandled_input(event):
	# Bloqueamos el movimiento de cámara con el ratón si está la cinemática
	if !camera_enabled or controles_bloqueados:
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
	# Si está en cinemática, no permitimos interactuar ni pausar de la forma habitual
	if controles_bloqueados:
		return

	# Pausar / Liberar ratón
	if event.is_action_pressed("ui_cancel_custom"):
		camera_enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Capturar ratón al hacer clic en el juego
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			camera_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Sistema de interacción
	if event.is_action_pressed("interact") and current_interactable != null:
		if is_instance_valid(current_interactable):
			
			# --- REPRODUCIR SONIDO DE RECOGIDA ---
			if "se_puede_recoger" in current_interactable and current_interactable.se_puede_recoger:
				miscellaneousSoundsPlayer.pitch_scale = 1.0 
				miscellaneousSoundsPlayer.stream = pickUpSound
				miscellaneousSoundsPlayer.play()
			
			# Continuamos con la interacción normal
			current_interactable.interactuar()
			current_interactable = null
			interact_prompt.hide()


# =============================================================================
# --- FUNCIÓN GLOBAL DE CINEMÁTICA TRIGERIABLE ---
# =============================================================================
func ejecutar_cinematica(transform_destino: Transform3D, duracion_total: float = 4.0) -> void:
	if controles_bloqueados:
		return
		
	controles_bloqueados = true
	interact_prompt.hide()
	if current_interactable != null:
		current_interactable.set_highlight(false)
	
	# Guardamos la posición y rotación LOCAL original de la cámara para el regreso impecable
	var original_local_transform = camera_3d.transform
	
	# Calculamos tiempos (1s para ir, 1s para volver, el resto se queda fija)
	var tiempo_transicion := 2
	var tiempo_espera = max(0.1, duracion_total - (tiempo_transicion * 2.0))
	
	# Creamos la cadena de animaciones con Tween
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# 1. Viaje hacia la posición de la cinemática en el mundo entero
	tween.tween_property(camera_3d, "global_transform", transform_destino, tiempo_transicion)
	
	# 2. Mantener la toma fija observando la acción
	tween.tween_interval(tiempo_espera)
	
	# 3. Regreso suave a los ojos del jugador (usamos local para asegurar que encaje perfecto)
	tween.tween_property(camera_3d, "transform", original_local_transform, tiempo_transicion)
	
	# 4. Al terminar todo, devolvemos el control completo
	tween.tween_callback(func(): controles_bloqueados = false)
