extends Game
## Level 2: same rules as level 1, but with the zombies you placed in the scene.
## Every AnimatedSprite2D in this scene is a zombie. Invisible StaticBody2D barriers are walls.

const MAX_BALL_BOUNCES_L2: int = 4  # max bounces per ball in this level
const DEATH_SHEET: String = "res://art/zombie_death.png"
const DEATH_FRAMES: int = 5
const DEATH_FPS: float = 8.0
const START_BALLS_L2: int = 7  # balls the player starts level 2 with
const JUMP_SHEET: String = "res://art/zombie_jump.png"
const JUMP_FRAMES: int = 7
const JUMP_FPS: float = 8.0
const WALK_TIME: float = 2.0  # seconds walking before each jump
const JUMP_HEIGHT: float = 140.0  # pixels the zombie rises; the ball can pass under it


func _ready() -> void:
	load_high_score()
	Arena.set_physics_walls()  # the invisible barriers
	score = total_score
	cannon.ammo = START_BALLS_L2
	cannon.max_bounces = MAX_BALL_BOUNCES_L2
	cannon.fired.connect(_update_hud)
	_build_ui()
	for child in get_children():
		if child is AnimatedSprite2D:
			_make_zombie(child)
	_update_hud()


func _make_zombie(sprite: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if not frames.has_animation("death"):  # the 4 zombies share one SpriteFrames
		_add_sheet(frames, "death", DEATH_SHEET, DEATH_FRAMES, DEATH_FPS)
	if not frames.has_animation("jump"):
		_add_sheet(frames, "jump", JUMP_SHEET, JUMP_FRAMES, JUMP_FPS)
	sprite.play("default")  # walking animation
	var zombie: Zombie = Zombie.new()
	zombie.killed.connect(_on_ghost_killed)  # same score rule as level 1
	zombie.died.connect(_on_ghost_died)
	sprite.add_child(zombie)
	remaining += 1
	_walk_and_jump(sprite, zombie)


## Cuts a sprite sheet (frames side by side) into a one-shot animation.
func _add_sheet(frames: SpriteFrames, anim: String, path: String, count: int, fps: float) -> void:
	var sheet: Texture2D = load(path)
	var w: float = sheet.get_width() / float(count)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, false)
	for i in count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * w, 0, w, sheet.get_height())
		frames.add_frame(anim, atlas)


## Walk for WALK_TIME seconds, jump once, repeat, until the zombie is hit.
func _walk_and_jump(sprite: AnimatedSprite2D, zombie: Zombie) -> void:
	var walk_h: float = sprite.sprite_frames.get_frame_texture("default", 0).get_height()
	var jump_h: float = sprite.sprite_frames.get_frame_texture("jump", 0).get_height()
	await get_tree().create_timer(randf_range(0.5, WALK_TIME)).timeout  # so they don't move in sync
	while is_instance_valid(sprite) and zombie.alive:
		sprite.offset.y = -(jump_h - walk_h) / 2.0  # keep the feet on the same spot
		sprite.play("jump")
		var base_y: float = sprite.position.y
		var half: float = JUMP_FRAMES / JUMP_FPS / 2.0
		var tw: Tween = sprite.create_tween()  # up, then back down (hit area moves with it)
		tw.tween_property(sprite, "position:y", base_y - JUMP_HEIGHT, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position:y", base_y, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await sprite.animation_finished
		if not (is_instance_valid(sprite) and zombie.alive):
			return
		sprite.offset.y = 0.0
		sprite.play("default")
		await get_tree().create_timer(WALK_TIME).timeout


func _update_hud() -> void:
	hud.text = "Level 2    Score: %d    Best: %d    Balls: %d    Zombies: %d" % [
		score, maxi(high_score, score), cannon.ammo, remaining]


func _win_level() -> void:
	super()  # saves the score, stops the game
	next_level.visible = false  # the main button below replaces it
	_show_panel("LEVEL 2 COMPLETE!", "Score: %d\nBest: %d" % [score, high_score],
			"Go to level 3", _go_next_level)


func _go_next_level() -> void:
	print("Next level pressed -> loading level3.tscn")
	var err: Error = get_tree().change_scene_to_file("res://scenes/level3.tscn")
	if err != OK:
		push_error("Could not open level3.tscn (error %d)" % err)
