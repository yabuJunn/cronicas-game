extends OmniLight3D
class_name InteractableLight

@export_group("Configuración de Pulsación")
@export var min_energy: float = 0.02
@export var max_energy: float = 0.15 # Muy suave para que no resalte demasiado
@export var tiempo_pulso: float = 1.8

@export_group("Configuración del Destello Visual (Sutil)")
@export var min_alpha: float = 0.05
@export var max_alpha: float = 0.25  # Opacidad máxima reducida (25% max) para ser un simple "hint"
@export var min_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var max_scale: Vector3 = Vector3(0.6, 0.6, 0.6)  # Escala más pequeña

@export_group("Rango de Visibilidad (Distancias)")
@export var dist_cerca_invisible: float = 2.0  # A menos de 2m: Totalmente invisible
@export var dist_cerca_optima: float = 5.0     # Entre 2m y 5m: Aparece suavemente hasta su pico sutil
@export var dist_lejos_optima: float = 12.0    # Entre 5m y 12m: Se mantiene visible con la opacidad sutil
@export var dist_lejos_invisible: float = 22.0 # Entre 12m y 22m: Se va desvaneciendo hasta desaparecer por completo

@onready var destello_sprite: Sprite3D = $DestelloSprite

var pulse_tween: Tween
var base_alpha: float = 0.0


func _ready() -> void:
	iniciar_pulsacion()


func _process(_delta: float) -> void:
	if destello_sprite and destello_sprite.visible:
		_actualizar_transparencia_por_distancia()


func iniciar_pulsacion() -> void:
	light_energy = min_energy
	base_alpha = min_alpha
	
	if destello_sprite:
		destello_sprite.scale = min_scale
	
	pulse_tween = create_tween().set_loops()
	
	# --- 1. SUBIR ---
	pulse_tween.tween_property(self, "light_energy", max_energy, tiempo_pulso)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	pulse_tween.parallel().tween_property(self, "base_alpha", max_alpha, tiempo_pulso)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if destello_sprite:
		pulse_tween.parallel().tween_property(destello_sprite, "scale", max_scale, tiempo_pulso)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# --- 2. BAJAR ---
	pulse_tween.tween_property(self, "light_energy", min_energy, tiempo_pulso)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	#pulse_tween.parallel().tween_property(self, "base_alpha", min_alpha, tiempo_pulso)\
		#.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	if destello_sprite:
		pulse_tween.parallel().tween_property(destello_sprite, "scale", min_scale, tiempo_pulso)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _actualizar_transparencia_por_distancia() -> void:
	var camara = get_viewport().get_camera_3d()
	if not camara:
		return
		
	var distancia = global_position.distance_to(camara.global_position)
	var factor_distancia: float = 0.0
	
	# 1. Si está demasiado cerca o demasiado lejos: Invisible
	if distancia <= dist_cerca_invisible or distancia >= dist_lejos_invisible:
		factor_distancia = 0.0
		
	# 2. Transición al acercarse mucho (desaparece al acercarse al objeto)
	elif distancia < dist_cerca_optima:
		factor_distancia = remap(distancia, dist_cerca_invisible, dist_cerca_optima, 0.0, 1.0)
		
	# 3. Zona dulce (se ve con la opacidad tenue del pico)
	elif distancia <= dist_lejos_optima:
		factor_distancia = 1.0
		
	# 4. Transición al alejarse (aparece/desaparece a la distancia lejana)
	else:
		factor_distancia = remap(distancia, dist_lejos_optima, dist_lejos_invisible, 1.0, 0.0)
	
	factor_distancia = clampf(factor_distancia, 0.0, 1.0)
	destello_sprite.modulate.a = base_alpha * factor_distancia


func apagar() -> void:
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
	set_process(false)
	visible = false
