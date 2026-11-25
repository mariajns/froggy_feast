class_name Water
extends MeshInstance3D

var wave_time := 0.0
var mat: ShaderMaterial


func _ready() -> void:
	mat = get_surface_override_material(0) as ShaderMaterial


func _process(delta: float) -> void:
	wave_time += delta
	mat.set_shader_parameter("wave_time", wave_time)


# Same formula as wave() in water.gdshader
# IF CHANGE THIS, CHANGE THE OTHER
func get_wave_height(world_pos: Vector3) -> float:
	var height: float = mat.get_shader_parameter("wave_height")
	var speed: float = mat.get_shader_parameter("wave_speed")
	var scale_: float = mat.get_shader_parameter("wave_scale")

	var w := sin(world_pos.x * scale_ + wave_time * speed) * 0.5 \
		   + sin(world_pos.z * scale_ * 1.3 + wave_time * speed * 0.8) * 0.5

	return global_position.y + w * height
