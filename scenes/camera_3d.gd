extends Camera3D

@export var camera_positions: Array[Marker3D] = []
# Camera tilt settings
@export var pitch_speed: float = 30.0
@export var min_pitch: float = -20.0
@export var max_pitch: float = 60.0
@export var pitch_angle: float = 15.0

var current_position: int = 0


func _ready() -> void:
	make_current()
	move_to_position(current_position)

func _process(delta: float) -> void:
	#üles nool -> vaata kõrgemale
	#alla nool -> vaata madalamale
	var pitch_input = Input.get_axis("ui_down", "ui_up")

	if pitch_input != 0:
		pitch_angle += pitch_input * pitch_speed * delta

		pitch_angle = clampf(
			pitch_angle,
			min_pitch,
			max_pitch
		)

		update_camera_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("ui_right"):
		change_position(1)

	elif event.is_action_pressed("ui_left"):
		change_position(-1)

#muuda kaamera positsioon markerite järjendi abil
func change_position(direction: int) -> void:
	if camera_positions.is_empty():
		return

	current_position = wrapi(
		current_position + direction,
		0,
		camera_positions.size()
	)

	move_to_position(current_position)


func move_to_position(index: int) -> void:
	if camera_positions.is_empty():
		return

	var point = camera_positions[index]

	if point == null:
		return

	#kopeeri ainult positsioon
	global_position = point.global_position

	#alati vaata x-telje suunas
	look_at(global_position + Vector3.RIGHT, Vector3.UP)

func update_camera_rotation() -> void:
	var angle = deg_to_rad(pitch_angle)

	#kaamera kallutus
	var direction = Vector3(
		cos(angle),
		sin(angle),
		0.0
	)

	look_at(global_position + direction, Vector3.UP)
