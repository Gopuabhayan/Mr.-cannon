class_name Cannon
extends Node2D
## Aims at the mouse; fires a ball on click / space.

signal fired

const MUZZLE: float = 58.0  # distance from pivot to barrel tip
const MIN_ELEVATION: float = 0.35  # radians above the horizon

var ammo: int = 0
var max_bounces: int = 3  # per ball; set by each level
var aim_down: bool = false  # true = cannon hangs from the ceiling and aims below the horizon


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	var dir: Vector2 = get_global_mouse_position() - global_position
	# Keep the barrel above the ground (aim angle: 0 = right, -PI/2 = up).
	var aim: float = dir.angle()
	if aim_down:  # keep the barrel below the horizon (0 = right, PI/2 = down)
		if aim < MIN_ELEVATION or aim > PI - MIN_ELEVATION:
			aim = MIN_ELEVATION if dir.x >= 0.0 else PI - MIN_ELEVATION
	elif aim > -MIN_ELEVATION or aim < -PI + MIN_ELEVATION:
		aim = -MIN_ELEVATION if dir.x >= 0.0 else -PI + MIN_ELEVATION
	# The sprite art points up, so add 90 degrees. Follow the mouse smoothly.
	rotation = lerp_angle(rotation, aim + PI / 2.0, minf(1.0, 20.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	var fire: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		fire = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		var key: InputEventKey = event
		fire = key.pressed and not key.echo and key.keycode == KEY_SPACE
	if fire:
		shoot()


func direction() -> Vector2:
	return Vector2.UP.rotated(rotation)


func muzzle_position() -> Vector2:
	return global_position + direction() * MUZZLE


func shoot() -> void:
	if ammo <= 0:
		return
	ammo -= 1
	Sfx.play("shoot")
	var ball: Ball = Ball.new()
	get_parent().add_child(ball)
	ball.global_position = muzzle_position()
	ball.max_bounces = max_bounces
	ball.velocity = direction() * Ball.SPEED
	fired.emit()
