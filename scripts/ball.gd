class_name Ball
extends Area2D
## Cannonball. It flies straight and bounces off the walls.
## It can only hurt a ghost AFTER it has bounced at least once.

const SPEED: float = 650.0
const RADIUS: float = 9.0
const MAX_AGE: float = 10.0

var velocity: Vector2 = Vector2.ZERO
var bounces: int = 0
var max_bounces: int = 3
var _age: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("ball")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)


func _draw() -> void:
	# Always the orange look, from the moment it is fired.
	draw_circle(Vector2.ZERO, RADIUS + 5.0, Color(1.0, 0.55, 0.1, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.6, 0.15))
	draw_circle(Vector2(-3, -3), 3.0, Color(1.0, 0.95, 0.7))


func _physics_process(delta: float) -> void:
	_age += delta
	var res: Dictionary = Arena.move(position, velocity, delta, RADIUS)
	position = res["pos"]
	velocity = res["vel"]
	if res["bounced"]:
		bounces += 1
		Sfx.play("bounce", -10.0)
		queue_redraw()
		if bounces >= max_bounces:
			queue_free()
			return
	if _age > MAX_AGE:
		queue_free()
		return
	if bounces > 0:
		for area in get_overlapping_areas():
			if area.is_in_group("ghost"):  # ghosts and zombies
				var ghost = area  # Ghost or Zombie
				if ghost.alive:
					ghost.hit()
					queue_free()
					return
