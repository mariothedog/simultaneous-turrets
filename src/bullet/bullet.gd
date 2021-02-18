extends Area2D

var friendly_turrets := []  # List of turrets the bullet will phase through

var velocity := Vector2.ZERO

onready var front = $Front


func _physics_process(delta: float) -> void:
	position += velocity * delta


func explode() -> void:
	VFX.spawn_particles(VFX.ParticleSystems.BULLET_EXPLOSION, front.global_position)
	queue_free()


func _on_Bullet_area_entered(area: Area2D) -> void:
	if area in friendly_turrets:
		return
	area.explode()
	explode()


func _on_Bullet_body_entered(_body: Node) -> void:
	explode()
