class_name Enemy
extends Area2D

signal stopped_moving
signal reached_end_of_path
signal exploded

const MOVEMENT_WEIGHT := 0.3
var MOVEMENT_RATE := MOVEMENT_WEIGHT * Constants.PHYSICS_FPS
const AT_TARGET_THRESHOLD := 0.1
const DAMAGE := 1

var path: PoolVector2Array setget _set_path

var _path_length: int
var _path_current_index := 0
var _target_pos: Vector2


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if Util.is_vec2_equal_with_threshold(global_position, _target_pos, AT_TARGET_THRESHOLD):
		set_physics_process(false)
		global_position = _target_pos
		emit_signal("stopped_moving")
		if _path_current_index + 1 == _path_length:
			emit_signal("reached_end_of_path")
		return
	var weight := min(MOVEMENT_RATE * delta * Global.step_speed, 1)
	global_position = global_position.linear_interpolate(_target_pos, weight)


func update_position_along_path() -> void:
	if _path_current_index + 1 == _path_length:
		return
	_path_current_index += 1
	_target_pos = path[_path_current_index]
	set_physics_process(true)


func explode() -> void:
	if is_queued_for_deletion():
		return
	emit_signal("stopped_moving")
	emit_signal("exploded")
	queue_free()


func _set_path(value: PoolVector2Array) -> void:
	path = value
	_path_length = len(path)
	global_position = path[0]
