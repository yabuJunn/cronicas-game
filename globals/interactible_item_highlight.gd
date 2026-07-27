extends InteractableItem
class_name InteractibleItemHighlight

# --- SHADER RECURSO ---
const HIGHLIGHT_SHADER: Shader = preload("res://shaders/item_highlighter.gdshader")

# --- PARÁMETROS DEL SHADER EXPORTADOS AL INSPECTOR ---
@export_group("Configuración del Destello")
@export var shine_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export_range(0.0, 25.0, 0.1) var shine_speed: float = 2.0
@export_range(0.001, 0.5, 0.005) var shine_width: float = 0.08
@export_range(0.0, 1.0, 0.05) var softness: float = 0.5
@export_range(0.0, 100.0, 0.5) var cycle_interval: float = 2.0
@export_range(0.0, 1.0, 0.05) var angle_fade: float = 0.5

@export_group("Dirección del Destello")
@export_range(-1.0, 1.0, 0.1) var x_direction: float = 0.0
@export_range(-1.0, 1.0, 0.1) var y_direction: float = 0.0
@export_range(-1.0, 1.0, 0.1) var z_direction: float = 1.0

@export_group("Comportamiento del Efecto")
## Si es true, el destello pasa continuamente. Si es false, solo brilla al mirarlo.
@export var siempre_activo: bool = true

var shader_material: ShaderMaterial


func _ready() -> void:
	# 1. Ejecutamos el _ready del padre (esto crea y configura el outline_material)
	super._ready()
	se_puede_recoger = true
	
	# 2. Creamos y encadenamos el shader de destello
	_crear_y_configurar_shader()


func _crear_y_configurar_shader() -> void:
	if not mesh:
		return

	shader_material = ShaderMaterial.new()
	shader_material.shader = HIGHLIGHT_SHADER
	
	# ¡CLAVE!: Conectamos el outline_material generado en el padre como "next_pass"
	if outline_material:
		shader_material.next_pass = outline_material
		
	# Asignamos el shader de destello a la malla
	mesh.material_overlay = shader_material
	
	actualizar_parametros_shader()


func actualizar_parametros_shader() -> void:
	if not shader_material:
		return
		
	# Si 'siempre_activo' es false y el jugador no está mirando el objeto, ocultamos el destello
	var color_final: Color = shine_color
	if not siempre_activo and not es_mirado:
		color_final.a = 0.0

	shader_material.set_shader_parameter("shine_color", color_final)
	shader_material.set_shader_parameter("shine_speed", shine_speed)
	shader_material.set_shader_parameter("shine_width", shine_width)
	shader_material.set_shader_parameter("softness", softness)
	shader_material.set_shader_parameter("cycle_interval", cycle_interval)
	shader_material.set_shader_parameter("angle_fade", angle_fade)
	shader_material.set_shader_parameter("x_direction", x_direction)
	shader_material.set_shader_parameter("y_direction", y_direction)
	shader_material.set_shader_parameter("z_direction", z_direction)


func set_highlight(activo: bool) -> void:
	# 1. Llamamos a InteractableItem.set_highlight(), que activa/desactiva el outline
	super.set_highlight(activo)
	
	# 2. Actualizamos el destello por si dependía de 'es_mirado' (cuando siempre_activo = false)
	actualizar_parametros_shader()
