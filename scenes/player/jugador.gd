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

const BREATH_FREQ = 2.0           # Velocidad de la respiración
const BREATH_AMP = 0.035          # Amplitud de la respiración

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
var default_camera_pos := Vector3.ZERO # Guarda la posición de tus ojos del editor

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	default_camera_pos = camera_3d.position 

func _physics_process(delta: float) -> void:
	
	if en_cinematica:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
	
	# --- SI SOLO ESTÁN BLOQUEADOS LOS CONTROLES (MENÚS, DIÁLOGOS, ETC.) ---
	if controles_bloqueados:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_update_head_bob(delta) 
		
		# NUEVO: Asegurarnos de ocultar el texto de interacción si perdemos el control
		interact_prompt.hide()
		if current_interactable != null and is_instance_valid(current_interactable):
			current_interactable.set_highlight(false)
			
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
	
	last_velocity_y = velocity.y 
	
	move_and_slide()
	
	# DETECCIÓN DE ATERRIZAJE
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
	
	# Manejamos los cambios de foco
	if collider != current_interactable:
		if current_interactable != null and is_instance_valid(current_interactable):
			current_interactable.set_highlight(false)
			interact_prompt.hide()
			
		if collider != null and collider.is_in_group("interactibleObjects") and not collider.is_queued_for_deletion():
			current_interactable = collider
		else:
			current_interactable = null
			interact_prompt.hide()

	# Actualizamos el texto de la UI y controlamos visibilidad durante diálogos
	if current_interactable != null and is_instance_valid(current_interactable):
		# NUEVO: Si el diálogo está activo, forzamos a ocultar todo
		if DialogueSystem.esta_activo:
			interact_prompt.hide()
			current_interactable.set_highlight(false) # Apaga el outline del objeto
		else:
			# Si NO hay diálogo, mostramos el texto y el outline normalmente
			interact_prompt.show()
			current_interactable.set_highlight(true)
			
			if "texto_interaccion" in current_interactable:
				interact_prompt.text = current_interactable.texto_interaccion
			elif "se_puede_recoger" in current_interactable and current_interactable.se_puede_recoger:
				interact_prompt.text = "[ E ] Recoger " + current_interactable.item_name
			else:
				interact_prompt.text = "[ E ] Interactuar"

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
			# Primero ejecutamos la interacción y guardamos si la recogida fue exitosa
			var objeto_recogido: bool = current_interactable.interactuar()
			
			# Solo si devolvió 'true' disparamos el audio de inventario
			if objeto_recogido:
				miscellaneousSoundsPlayer.pitch_scale = 1.0 
				miscellaneousSoundsPlayer.stream = pickUpSound
				miscellaneousSoundsPlayer.play()
			
			current_interactable = null
			interact_prompt.hide()

func ejecutar_cinematica(transform_destino: Transform3D, duracion_total: float = 4.0) -> void:
	if en_cinematica:
		return
		
	en_cinematica = true
	controles_bloqueados = true
	interact_prompt.hide()
	if current_interactable != null:
		current_interactable.set_highlight(false)
	
	var original_local_transform = camera_3d.transform
	var tiempo_transicion : float = 2.0
	var tiempo_espera = max(0.1, duracion_total - (tiempo_transicion * 2.0))
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(camera_3d, "global_transform", transform_destino, tiempo_transicion)
	tween.tween_interval(tiempo_espera)
	tween.tween_property(camera_3d, "transform", original_local_transform, tiempo_transicion)
	
	tween.tween_callback(func(): 
		en_cinematica = false
		controles_bloqueados = false
	)

# --- SISTEMA DE MENÚ CINEMÁTICO ---

func preparar_camara_menu(transform_menu: Transform3D) -> void:
	en_cinematica = true # Evita que _physics_process llame a _update_head_bob
	controles_bloqueados = true
	camera_enabled = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	camera_3d.top_level = true
	camera_3d.global_transform = transform_menu


func transicionar_a_jugador(duracion: float = 3.5) -> void:
	var target_transform = camera_pivot.global_transform
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(camera_3d, "global_transform", target_transform, duracion)
	
	tween.tween_callback(func():
		camera_3d.top_level = false
		camera_3d.position = default_camera_pos
		camera_3d.rotation = Vector3.ZERO
		
		en_cinematica = false
		controles_bloqueados = false
		camera_enabled = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)


func _update_head_bob(delta: float) -> void:
	# Protección: Si la cámara está desacoplada del jugador, no tocar su posición
	if camera_3d.top_level:
		return

	if controles_bloqueados:
		camera_3d.position = camera_3d.position.lerp(default_camera_pos, delta * 10.0)
		return

	var target_pos = default_camera_pos
	var velocidad_horizontal = Vector2(velocity.x, velocity.z).length()

	if is_on_floor():
		if velocidad_horizontal > 0.1:
			var es_corriendo = Input.is_action_pressed("sprint")
			var freq = BOB_FREQ_SPRINT if es_corriendo else BOB_FREQ_WALK
			var amp_v = BOB_AMP_SPRINT_V if es_corriendo else BOB_AMP_WALK_V
			var amp_h = BOB_AMP_SPRINT_H if es_corriendo else BOB_AMP_WALK_H

			bob_time += delta * freq
			target_pos.y += sin(bob_time * 2.0) * amp_v
			target_pos.x += cos(bob_time) * amp_h
		else:
			breath_time += delta * BREATH_FREQ
			target_pos.y += sin(breath_time) * BREATH_AMP
	else:
		target_pos.y += clamp(velocity.y * 0.015, -0.08, 0.05)

	landing_bounce = lerp(landing_bounce, 0.0, delta * 10.0)
	target_pos.y += landing_bounce
	camera_3d.position = camera_3d.position.lerp(target_pos, delta * 12.0)
