class_name Turrets
extends Node2D

const TURRET_SCENE := preload("res://turrets/turret.tscn")

const TURRET_AIMING_ANGLE_SNAP := deg2rad(45)
const TURRET_AIMING_MOUSE_DIST_THRESHOLD := 2.0

export (NodePath) var level_path

var Tiles := TilesManager.new()

var _prev_angle_snapped := 0.0

onready var level: TileMap = get_node(level_path)
onready var placed_turrets: Node2D = $PlacedTurrets
onready var dragging_turret: Sprite = $DraggingTurretLayer/DraggingTurret
onready var dragging_gun: Sprite = $DraggingTurretLayer/DraggingTurret/Gun


func _ready() -> void:
	set_process(false)
	dragging_turret.visible = false
# warning-ignore:return_value_discarded
	Signals.connect("item_button_down", self, "_on_item_button_down")


func _process(_delta: float) -> void:
	if Global.is_aiming:
		# Todo: what?
		var mouse_pos: Vector2 = Global.selected_turret.get_local_mouse_position()
		if mouse_pos.length() >= TURRET_AIMING_MOUSE_DIST_THRESHOLD:
			var angle_snapped := _get_snapped_angle_to(mouse_pos)
			if angle_snapped == _prev_angle_snapped:
				return
			_prev_angle_snapped = angle_snapped
			dragging_gun.rotation = angle_snapped
			Global.selected_turret.rotate_gun_to(angle_snapped)
	else:
		dragging_turret.global_position = get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if (
		not event is InputEventMouseButton
		or (event as InputEventMouseButton).button_index != BUTTON_LEFT
		or not Global.selected_turret
	):
		return
	if not event.is_pressed():
		_release_turret(Global.selected_turret)
	elif Global.is_aiming:
		set_process(false)
		Global.selected_turret = null
		Global.is_aiming = false


func reset() -> void:
	stop_charge_up_anim_anims()


func shoot(bullets_node: Node, tile_size: Vector2) -> void:
	for turret in placed_turrets.get_children():
		if turret.is_enabled:
			turret.shoot(bullets_node, tile_size)


func charge_up_guns() -> void:
	for turret in placed_turrets.get_children():
		turret.charge_up_gun()


func stop_charge_up_anim_anims() -> void:
	for turret in placed_turrets.get_children():
		turret.stop_charge_up_anim()


func _get_snapped_angle_to(pos: Vector2) -> float:
	var angle_snapped := stepify(pos.angle(), TURRET_AIMING_ANGLE_SNAP)
	return wrapf(angle_snapped, 0, Constants.FULL_ROTATION)


func _select_turret(turret: Turret) -> void:
	var new_top_turret := _get_second_top_overlapping_turret(turret.position)
	if new_top_turret:
		new_top_turret.set_rotation(turret.gun.rotation)
		new_top_turret.rotate_gun_to(_prev_angle_snapped)
	dragging_turret.visible = true
	turret.disable()
	turret.raise()
	Global.selected_turret = turret
	_update_overlapping_turrets(turret.position)
	set_process(true)


func _release_turret(turret: Turret) -> void:
	dragging_turret.visible = false
	var tile_pos := _get_tile_pos_at_mouse()
	if not _can_place_at_tile(tile_pos):
		turret.queue_free()
		turret.item.num_left += 1
		set_process(false)
		return
	var turret_pos := _get_turret_pos_from(tile_pos)
	var prev_top_turret := _get_top_overlapping_turret(turret_pos)
	if prev_top_turret:
		turret.set_rotation(prev_top_turret.gun.rotation)
		_prev_angle_snapped = prev_top_turret.gun.rotation
	else:
		_prev_angle_snapped = turret.gun.rotation
	turret.global_position = turret_pos
	turret.enable()
	Global.is_aiming = true
	_update_overlapping_turrets(turret.position)


func _can_place_at_tile(tile_pos: Vector2) -> bool:
	var world_pos := _get_turret_pos_from(tile_pos)
	var turrets := _get_unselected_or_aiming_turrets_at(world_pos)
	return level.get_cellv(tile_pos) == Tiles.Main.GROUND and len(turrets) < 8


func _get_tile_pos_at_mouse() -> Vector2:
	var mouse_pos := level.get_local_mouse_position()
	return level.world_to_map(mouse_pos)


func _get_turret_pos_from(tile_pos: Vector2) -> Vector2:
	var world_pos := level.map_to_world(tile_pos)  # Top left of tile
	var world_pos_centered := world_pos + level.cell_size / 2
	return world_pos_centered


func _update_overlapping_turrets(pos: Vector2) -> void:
	var top_turret := _get_top_overlapping_turret(pos)
	if not top_turret:
		return
	var unselected_turrets := _get_unselected_or_aiming_turrets_at(pos)
	for turret in unselected_turrets:
		if turret == top_turret:
			continue
		turret.disable()
		turret.level = 0
	top_turret.level = len(unselected_turrets)
	top_turret.enable()


func _get_top_overlapping_turret(pos: Vector2) -> Turret:
	var top_pos_in_parent := -1
	var top_turret: Turret
	for turret in _get_unselected_or_aiming_turrets_at(pos):
		var pos_in_parent: int = turret.get_position_in_parent()
		if pos_in_parent > top_pos_in_parent:
			top_pos_in_parent = pos_in_parent
			top_turret = turret
	return top_turret


func _get_second_top_overlapping_turret(pos: Vector2) -> Turret:
	var top_turret := _get_top_overlapping_turret(pos)
	var second_top_pos_in_parent := -1
	var second_top_turret: Turret
	for turret in _get_unselected_or_aiming_turrets_at(pos):
		if turret == top_turret:
			continue
		var pos_in_parent: int = turret.get_position_in_parent()
		if pos_in_parent > second_top_pos_in_parent:
			second_top_pos_in_parent = pos_in_parent
			second_top_turret = turret
	return second_top_turret


func _get_unselected_or_aiming_turrets_at(pos: Vector2) -> Array:
	var turrets := []
	for turret in placed_turrets.get_children():
		if turret.position == pos and (turret != Global.selected_turret or Global.is_aiming):
			turrets.append(turret)
	return turrets


func _on_item_button_down(item: Item) -> void:
	item.num_left -= 1
	dragging_gun.rotation = 0
	var turret: Turret = TURRET_SCENE.instance()
	turret.item = item
# warning-ignore:return_value_discarded
	turret.connect("mouse_down", self, "_on_Turret_mouse_down", [turret])
	placed_turrets.add_child(turret)
	_select_turret(turret)


func _on_Turret_mouse_down(turret: Turret) -> void:
	if Global.is_running:
		return
	dragging_gun.rotation = _prev_angle_snapped
	_select_turret(turret)
