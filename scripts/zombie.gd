class_name Zombie
extends Area2D
## Put this on a hit area under an AnimatedSprite2D. A ball that has bounced kills it.
## Same contract as Ghost: alive, hit(), killed(at), died.

signal killed(at: Vector2)  # the moment a ball hits
signal died              # after the death animation finishes

var alive: bool = true
var _sprite: AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("ghost")  # the ball treats anything in this group as an enemy
	_sprite = get_parent() as AnimatedSprite2D
	var size: Vector2 = _sprite.sprite_frames.get_frame_texture(
			_sprite.animation, 0).get_size()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)


func hit() -> void:
	if not alive:
		return
	alive = false
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	killed.emit(global_position)
	Sfx.play("kill")
	Sfx.play("point", -10.0)
	if _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")
		await _sprite.animation_finished
	else:  # no death frames (e.g. slimes): flash red, squash and fade out
		_sprite.modulate = Color(1.0, 0.35, 0.35)
		var tw: Tween = _sprite.create_tween()
		tw.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.3, 0.1), 0.35)
		tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.35)
		await tw.finished
	died.emit()
	_sprite.queue_free()
