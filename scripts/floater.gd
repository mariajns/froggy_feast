extends Node3D

@export var water: Water
@export var bob_strength := 1.0
@export var tilt_strength := 2.0
@export var sample_distance := 0.5

var rest_y: float
var rest_rotation: Vector3


func _ready() -> void:
	rest_y = global_position.y
	rest_rotation = rotation


func _process(_delta: float) -> void:
	if water == null:
		return

	var p := global_position
	var surface := water.get_wave_height(p)

	# Bob: follow how far the water is above/below its resting level
	global_position.y = rest_y + (surface - water.global_position.y) * bob_strength

	# Tilt: compare the water height a bit to the +X and +Z side
	var e := sample_distance
	var hx := water.get_wave_height(p + Vector3(e, 0, 0)) - surface
	var hz := water.get_wave_height(p + Vector3(0, 0, e)) - surface

	rotation.z = rest_rotation.z + atan2(hx, e) * tilt_strength
	rotation.x = rest_rotation.x - atan2(hz, e) * tilt_strength
