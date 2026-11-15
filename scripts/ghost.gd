class_name Ghost
extends Area2D
## Floating ghost. Plays the death animation when a ball hits it.

signal killed(at: Vector2)  # the moment a ball hits
signal died              # after the death animation finishes

const IDLE_SHEET: String = "res://Seeker_Lite/Spritesheets/Seeker_Void_Idle_30x30_24f.png"
const DEATH_SHEET: String = "res://Seeker_Lite/Seeker_Void_Death_40x50_20f.png"

var alive: bool = true
var amplitude: Vector2 = Vector2(0, 8)   # how far it drifts from its spot
var speed: float = 2.0                   # drift speed

var _origin: Vector2
var _t: float = randf() * TAU
var _sprite: AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("ghost")
	scale = Vector2(3, 3)
	_origin = position

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = build_frames()
	add_child(_sprite)
	_sprite.play("idle")

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)


## Idle + death animations (also used by level 4).
static func build_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "idle", IDLE_SHEET, Vector2i(30, 30), 24, 12.0, true)
	_add_anim(frames, "death", DEATH_SHEET, Vector2i(40, 50), 20, 14.0, false)
	return frames


static func _add_anim(frames: SpriteFrames, anim: StringName, path: String,
		size: Vector2i, count: int, fps: float, loop: bool) -> void:
	var sheet: Texture2D = load(path)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * size.x, 0, size.x, size.y)
		frames.add_frame(anim, atlas)


func _process(delta: float) -> void:
	if alive:
		_t += delta * speed
		position = _origin + Vector2(cos(_t) * amplitude.x, sin(_t) * amplitude.y)


func hit() -> void:
	if not alive:
		return
	alive = false
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	killed.emit(global_position)
	Sfx.play("kill")
	Sfx.play("point", -10.0)
	burst(self)
	_sprite.play("death")
	await _sprite.animation_finished
	died.emit()
	queue_free()


static func burst(parent: Node) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 80)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.7, 0.4, 1.0)
	parent.add_child(p)
	p.emitting = true
