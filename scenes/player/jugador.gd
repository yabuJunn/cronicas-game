extends CharacterBody3D

# Jugador
# Altura: 1.80 metros
# Radio: 0.35 m

const WALK_SPEED = 5 #Default is 5
const SPRINT_SPEED = 9 #Default is 9
const JUMP_VELOCITY = 6 #Default is 6
const MOUSE_SENSITIVITY = 0.003
var gravity = 9.8

var camera_enabled := true
var controles_bloqueados := false
var was_on_floor := true
var en_cinematica := false
var last_velocity_y := 0.0 # Guarda la velocidad antes de tocar el suelo

# --- CONFIGURACIÓN DE HEAD BOB Y RESPIRACIÓN ---
@export_group("Head Bob & Respiración")
const BOB_FREQ_WALK = 10.0        # Frecuencia al caminar (velocidad del bamboleo)
const BOB_AMP_WALK_V = 0.04       # Amplitud vertical al caminar (qué tanto sube/baja)
const BOB_AMP_WALK_H = 0.03       # Amplitud horizontal al caminar (qué tanto va a los lados)

const BOB_FREQ_SPRINT = 14.0      # Frecuencia al correr (más rápida)
const BOB_AMP_SPRINT_V = 0.07     # Amplitud vertical al correr (más notable)
const BOB_AMP_SPRINT_H = 0.05     # Amplitud horizontal al correr

const BREATH_FREQ = 2.0           # Velocidad de la respiración (más bajo = más lento/relajado)
const BREATH_AMP = 0.035          # Amplitud de la respiración (0.015 = 1.5 centímetros de vaivén)

var bob_time := 0.0               # Acumulador de tiempo para las ondas seno/coseno de movimiento
var breath_time := 0.0            # Acumulador de tiempo exclusivo para la respiración
var landing_bounce := 0.0         # Controla el impacto elástico al caer al suelo
# ---------------------------------

@onready var camera_pivot := $CameraPivot
@onready var camera_3d := $CameraPivot/Camera3D
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
var default_camera_pos := Vector3.ZERO # <--- NUEVA VARIABLE: Guarda la posición de tus ojos del editor

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	# Guardamos la posición exacta que le diste en el Inspector a la altura de los ojos
	default_camera_pos = camera_3d.position 

func _physics_process(delta: float) -> void:
	
	if en_cinematica:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return # ¡CORTE! Salimos de la función aquí para que nadie altere la cámara
	
	# --- SI SOLO ESTÁN BLOQUEADOS LOS CONTROLES (MENÚS, DIÁLOGOS, ETC.) ---
	if controles_bloqueados:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_update_head_bob(delta) 
		return

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
	
	# <--- GUARDAR VELOCIDAD ANTES DEL IMPACTO --->
	last_velocity_y = velocity.y 
	
	move_and_slide()
	
	# DETECCIÓN DE ATERRIZAJE (CORREGIDA)
	if is_on_floor() and not was_on_floor:
		if last_velocity_y < -3.5: 
			landingSoundPlayer.play()
			landing_bounce = -0.25
	
	was_on_floor = is_on_floor()
	
	if direction != Vector3.ZERO:
		var step_down := StepTester.try_step_down(self, Vector3(velocity.x, 0, velocity.z), delta)
		if step_down.success:
			apply_step(step_down)						
			
	camera_offset = camera_offset.lerp(Vector3.ZERO, delta * CAMERA_STEP_SPEED)
	camera_pivot.position = camera_offset
	
	# --- PROCESAR EL MOVIMIENTO DEL HEAD BOB ---
	_update_head_bob(delta)
	
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
	if controles_bloqueados:
		return

	if event.is_action_pressed("ui_cancel_custom"):
		camera_enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			camera_enabled = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("interact") and current_interactable != null:
		if is_instance_valid(current_interactable):
			if "se_puede_recoger" in current_interactable and current_interactable.se_puede_recoger:
				miscellaneousSoundsPlayer.pitch_scale = 1.0 
				miscellaneousSoundsPlayer.stream = pickUpSound
				miscellaneousSoundsPlayer.play()
			
			current_interactable.interactuar()
			current_interactable = null
			interact_prompt.hide()


# =============================================================================
# --- FUNCIÓN INTERNA: CÁLCULO DEL HEAD BOB PROCESADO (CORREGIDO) ---
# =============================================================================
func _update_head_bob(delta: float) -> void:
	if controles_bloqueados:
		camera_3d.position = camera_3d.position.lerp(default_camera_pos, delta * 10.0)
		return

	# Iniciamos en la posición base del editor en lugar de Vector3.ZERO
	var target_pos = default_camera_pos
	var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()

	# --- SI EL JUGADOR ESTÁ EN EL SUELO ---
	if is_on_floor():
		if velocidad_horizontal > 0.1:
			# MOVIMIENTO: Caminando o Corriendo
			var es_corriendo = Input.is_action_pressed("sprint")
			var freq = BOB_FREQ_SPRINT if es_corriendo else BOB_FREQ_WALK
			var amp_v = BOB_AMP_SPRINT_V if es_corriendo else BOB_AMP_WALK_V
			var amp_h = BOB_AMP_SPRINT_H if es_corriendo else BOB_AMP_WALK_H

			bob_time += delta * freq
			
			# Sumamos el desfase a la posición original
			target_pos.y += sin(bob_time * 2.0) * amp_v
			target_pos.x += cos(bob_time) * amp_h
		else:
			# REPOSO: Simulación de Respiración Orgánica
			breath_time += delta * BREATH_FREQ
			
			target_pos.y += sin(breath_time) * BREATH_AMP
	
	# --- SI EL JUGADOR ESTÁ EN EL AIRE (Salto y Caída) ---
	else:
		target_pos.y += clamp(velocity.y * 0.015, -0.08, 0.05)

	# --- IMPACTO DE ATERRIZAJE ---
	landing_bounce = lerp(landing_bounce, 0.0, delta * 10.0)
	target_pos.y += landing_bounce

	# --- INTERPOLACIÓN Y APLICACIÓN FINAL ---
	camera_3d.position = camera_3d.position.lerp(target_pos, delta * 12.0)


func ejecutar_cinematica(transform_destino: Transform3D, duracion_total: float = 4.0) -> void:
	if en_cinematica:
		return
		
	en_cinematica = true # Activamos el estado de película
	controles_bloqueados = true
	interact_prompt.hide()
	if current_interactable != null:
		current_interactable.set_highlight(false)
	
	var original_local_transform = camera_3d.transform
	var tiempo_transicion : float = 2.0 # Forzado a float para evitar fallos de cálculo
	var tiempo_espera = max(0.1, duracion_total - (tiempo_transicion * 2.0))
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Transición hacia el objetivo
	tween.tween_property(camera_3d, "global_transform", transform_destino, tiempo_transicion)
	# Tiempo de espera en el objetivo (Ahora sí se respetará por completo)
	tween.tween_interval(tiempo_espera)
	# Transición de regreso a los ojos del jugador
	tween.tween_property(camera_3d, "transform", original_local_transform, tiempo_transicion)
	
	# Al finalizar, devolvemos el control total
	tween.tween_callback(func(): 
		en_cinematica = false
		controles_bloqueados = false
	)
