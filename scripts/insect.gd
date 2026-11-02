extends Node3D

# Temporary movement until the insect flight paths are implemented.
@export var flight_speed: float = 1.0
@export var flight_width: float = 0.7
@export var flight_height: float = 0.25
@export var phase: float = 0.0

var starting_position: Vector3
var elapsed: float = 0.0


func _ready() -> void:
    starting_position = position


func _process(delta: float) -> void:
    elapsed += delta
    position = starting_position + Vector3(
        sin(elapsed * flight_speed + phase) * flight_width,
        sin(elapsed * flight_speed * 1.4 + phase) * flight_height,
        0.0
    )
