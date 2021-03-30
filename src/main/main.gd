extends Node

const FORMAT_LEVEL_PATH := "res://levels/resources/level_%s.tres"
const FORMAT_LEVEL_LABEL := "level: %s"

export var level_num := 1

var num_enemies_left: int

var _level_data: LevelData
var _num_enemies_dead := 0 setget _set_num_enemies_dead
var _step_index := 0

onready var level: Level = $Level
onready var enemies: Enemies = $Level/Enemies
onready var enemy_spawn_indicators: Node2D = $Level/EnemySpawnIndicators
onready var turrets: Turrets = $Turrets
onready var bullets: Bullets = $Turrets/Bullets
onready var placed_turrets: Node2D = $Turrets/PlacedTurrets
onready var hud: HUD = $HUDLayer/HUD
onready var level_label: Label = $HUDLayer/HUD/VBoxContainer/LevelMargin/Level
onready var lives: Lives = $HUDLayer/HUD/VBoxContainer/Lives
onready var item: Item = $HUDLayer/HUD/Inventory/ItemsMargin/Items/Item
onready var start_button: TextureButton = $HUDLayer/HUD/Buttons/Start
onready var stop_button: TextureButton = $HUDLayer/HUD/Buttons/Stop
onready var step_timer: Timer = $Step


func _ready() -> void:
	_go_to_level(level_num)
# warning-ignore:return_value_discarded
	Signals.connect("start_pressed", self, "_start")
# warning-ignore:return_value_discarded
	Signals.connect("stop_pressed", self, "_on_stop_pressed")


func _start() -> void:
	hud.slide_inventory_in()
	level.start()
	for turret in placed_turrets.get_children():
		turret.toggle_sight_lines(false)
	if not Signals.is_connected("ran_out_of_lives", self, "_on_ran_out_of_lives"):
		# Signal is deferred so the force stop happens after the lives have been set to 0
		# Signal is oneshot so there is no chance of two enemies trigerring force stop simultaneously
# warning-ignore:return_value_discarded
		Signals.connect(
			"ran_out_of_lives", self, "_on_ran_out_of_lives", [], CONNECT_DEFERRED + CONNECT_ONESHOT
		)
	Global.is_running = true
	step_timer.start()


func _stop() -> void:
	step_timer.stop()
	level.stop()
	Util.queue_free_children(enemies)
	Util.queue_free_children(bullets)
	for turret in placed_turrets.get_children():
		if turret.level > 0:
			turret.enable()
	Global.is_running = false


func _reset() -> void:
	_step_index = 0
	hud.highlight_step_labels(-1)
	lives.num_lives = _level_data.num_lives
	num_enemies_left = _level_data.num_enemies
	_num_enemies_dead = 0


func _force_stop() -> void:
	start_button.disabled = false
	stop_button.disabled = true
	_stop()


func _go_to_next_level() -> void:
	level_num += 1
	_go_to_level(level_num)


func _go_to_level(num: int) -> void:
	Util.queue_free_children(enemy_spawn_indicators)
	Util.queue_free_children(placed_turrets)
	_force_stop()
	_level_data = load(FORMAT_LEVEL_PATH % num)
	if not _level_data:
		push_warning("Level %s was not found" % num)
		return
	if not _level_data.steps:
		push_warning("Level %s has no steps" % num)
	_reset()
	hud.set_step_labels(_level_data.steps)
	item.num_left = _level_data.num_turrets
	level.build_level(_level_data)
	level_label.text = FORMAT_LEVEL_LABEL % num


func _set_num_enemies_dead(value: int) -> void:
	_num_enemies_dead = value
	if value == _level_data.num_enemies:
		_go_to_next_level()


func _on_stop_pressed() -> void:
	_stop()
	_reset()


func _on_ran_out_of_lives() -> void:
	_force_stop()
	_reset()


func _on_Enemies_enemy_reached_end_of_path(enemy: Enemy) -> void:
	lives.damage(enemy.DAMAGE)
	enemy.queue_free()
	self._num_enemies_dead += 1


func _on_Enemies_enemy_exploded(_enemy: Enemy) -> void:
	self._num_enemies_dead += 1


func _get_valid_step() -> int:
	var step: int
	var is_valid := false
	while not is_valid:
		_step_index %= _level_data.steps.size()
		step = _level_data.steps[_step_index]
		match step:
			Constants.StepTypes.ENEMY_SPAWN:
				is_valid = num_enemies_left > 0
			Constants.StepTypes.ENEMY_MOVE:
				is_valid = enemies.get_child_count() > 0
			Constants.StepTypes.BULLET_MOVE:
				is_valid = bullets.get_child_count() > 0
			Constants.StepTypes.TURRET_SHOOT:
				is_valid = placed_turrets.get_child_count() > 0
		if not is_valid:
			_step_index += 1
	return step


func _on_StepDelay_timeout() -> void:
	var step := _get_valid_step()
	hud.highlight_step_labels(_step_index)
	match step:
		Constants.StepTypes.ENEMY_SPAWN:
			num_enemies_left -= 1
			enemies.spawn_enemy()
		Constants.StepTypes.ENEMY_MOVE:
			enemies.move_enemies()
		Constants.StepTypes.BULLET_MOVE:
			bullets.move_bullets()
		Constants.StepTypes.TURRET_SHOOT:
			turrets.shoot_turrets(bullets, level.cell_size)
	_step_index += 1
