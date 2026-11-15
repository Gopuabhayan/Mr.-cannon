extends Game
## Level 3: the dungeon room with the slimes. Same rules as level 2, but harder.
## Every AnimatedSprite2D in this scene is a slime (an enemy).
## The invisible StaticBody2D nodes (platforms + room walls) are what the ball bounces off.

const MAX_BALL_BOUNCES_L3: int = 4   # max bounces per ball in this level
const START_BALLS_L3: int = 5        # balls the player starts level 3 with
const BALLS_PER_KILL_L3: int = 1     # level 1 and 2 give 2
const HOP_EVERY: float = 1.5         # seconds between hops
const HOP_HEIGHT: float = 100.0      # pixels a slime rises; the ball can pass under it
const HOP_TIME: float = 0.7          # seconds a hop lasts
const ROOM_TOP: float = 54.0         # slimes never hop above the room's ceiling


func _ready() -> void:
	load_high_score()
	Arena.set_physics_walls()  # the invisible barriers
	score = total_score
	cannon.ammo = START_BALLS_L3
	cannon.max_bounces = MAX_BALL_BOUNCES_L3
	cannon.fired.connect(_update_hud)
	_build_ui()
	for child in get_children():
		if child is AnimatedSprite2D:
			_make_slime(child)
	_update_hud()


func _make_slime(sprite: AnimatedSprite2D) -> void:
	sprite.play(sprite.animation)
	var slime: Zombie = Zombie.new()
	slime.killed.connect(_on_ghost_killed)
	slime.died.connect(_on_ghost_died)
	sprite.add_child(slime)
	remaining += 1
	_hop_forever(sprite, slime)


## Wait, hop, repeat, until the slime is hit.
func _hop_forever(sprite: AnimatedSprite2D, slime: Zombie) -> void:
	await get_tree().create_timer(randf_range(0.3, HOP_EVERY)).timeout  # so they don't hop in sync
	while is_instance_valid(sprite) and slime.alive:
		var base_y: float = sprite.position.y
		var half_h: float = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_height() * sprite.scale.y / 2.0
		var height: float = clampf(base_y - half_h - ROOM_TOP, 0.0, HOP_HEIGHT)  # room left above it
		var tw: Tween = sprite.create_tween()  # up, then back down (hit area moves with it)
		tw.tween_property(sprite, "position:y", base_y - height, HOP_TIME / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position:y", base_y, HOP_TIME / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
		if not (is_instance_valid(sprite) and slime.alive):
			return
		await get_tree().create_timer(HOP_EVERY).timeout


func _on_ghost_killed(at: Vector2) -> void:
	score += POINTS_PER_GHOST
	cannon.ammo += BALLS_PER_KILL_L3
	_update_hud()
	_popup(at, "+%d points  +%d ball" % [POINTS_PER_GHOST, BALLS_PER_KILL_L3])


func _update_hud() -> void:
	hud.text = "Level 3    Score: %d    Best: %d    Balls: %d    Slimes: %d" % [
		score, maxi(high_score, score), cannon.ammo, remaining]


func _win_level() -> void:
	super()  # saves the score, stops the game
	next_level.visible = false  # the main button below replaces it
	_show_panel("LEVEL 3 COMPLETE!", "Score: %d\nBest: %d" % [score, high_score],
			"Go to level 4", _go_next_level)


func _go_next_level() -> void:
	var err: Error = get_tree().change_scene_to_file("res://scenes/level_4.tscn")
	if err != OK:
		push_error("Could not open level_4.tscn (error %d)" % err)
