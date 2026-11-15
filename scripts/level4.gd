extends Game
## Level 4: the cannon hangs from the ceiling and aims down.
## Every AnimatedSprite2D in this scene is an enemy (a ball that has bounced kills it).
## Hit the Coin with a ball for +2 balls. Your CollisionShape2D nodes are the walls.

const MAX_BALL_BOUNCES_L4: int = 4 # max bounces per ball in this level
const START_BALLS_L4: int = 5
const COIN_BALLS: int = 2            # balls you get for hitting the coin

var _coin: Sprite2D
var _layer: CanvasLayer  # the popups live here
var _quit_button: Button


func _ready() -> void:
	load_high_score()
	_make_walls()
	Arena.set_physics_walls()
	score = total_score
	cannon.aim_down = true
	cannon.ammo = START_BALLS_L4
	cannon.max_bounces = MAX_BALL_BOUNCES_L4
	cannon.fired.connect(_update_hud)
	_build_ui()
	hint.text = "Aim: mouse   Fire: click / space   Enemies only die after the ball BOUNCES off a wall!   Coin = +%d balls   Restart: R" % COIN_BALLS
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	for sprite in find_children("*", "AnimatedSprite2D", true, false):
		_make_enemy(sprite)
	_coin = get_node_or_null("Coin")
	if _coin:
		_make_coin(_coin)
	_update_hud()


## Your CollisionShape2D nodes sit directly in the scene. The ball only bounces off
## solid objects, so each shape gets put inside an invisible StaticBody2D here.
func _make_walls() -> void:
	for node in get_children():
		if node is CollisionShape2D:
			var body: StaticBody2D = StaticBody2D.new()
			body.position = node.position
			remove_child(node)
			node.position = Vector2.ZERO
			body.add_child(node)
			add_child(body)


func _make_enemy(sprite: AnimatedSprite2D) -> void:
	# The ghosts in this scene loop the DEATH sheet as their "default" animation.
	# Give them the same idle + death animations and burst as level 1.
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if tex is AtlasTexture and (tex as AtlasTexture).atlas.resource_path.contains("Seeker_Void_Death"):
		sprite.sprite_frames = Ghost.build_frames()
		sprite.play("idle")
		var enemy_g: Zombie = Zombie.new()
		enemy_g.killed.connect(_on_ghost_killed)
		enemy_g.died.connect(_on_ghost_died)
		enemy_g.killed.connect(func(_at: Vector2) -> void: Ghost.burst(sprite))
		sprite.add_child(enemy_g)
		remaining += 1
		return
	sprite.play(sprite.animation)
	var enemy: Zombie = Zombie.new()
	enemy.killed.connect(_on_ghost_killed)  # same score rule as the other levels
	enemy.died.connect(_on_ghost_died)
	sprite.add_child(enemy)
	remaining += 1


func _make_coin(coin: Sprite2D) -> void:
	var area: Area2D = Area2D.new()
	area.add_to_group("pickup")  # not a wall, not an enemy
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = coin.texture.get_width() / 2.0
	shape.shape = circle
	area.add_child(shape)
	coin.add_child(area)
	area.area_entered.connect(func(other: Area2D) -> void:
		if other.is_in_group("ball"):
			_collect_coin(coin, area))


func _collect_coin(coin: Sprite2D, area: Area2D) -> void:
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)
	cannon.ammo += COIN_BALLS
	_update_hud()
	Sfx.play("point", -3.0)
	var at: Vector2 = coin.global_position
	_coin_popup(at)
	_sparkles(at)
	var tw: Tween = coin.create_tween()  # the coin swells and fades away
	tw.tween_property(coin, "scale", coin.scale * 1.8, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(coin, "modulate:a", 0.0, 0.25)
	tw.tween_callback(coin.queue_free)


## A gold card with the coin icon:  [coin]  +2 BALLS
func _coin_popup(at: Vector2) -> void:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.03, 0.92)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.82, 0.25)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(1.0, 0.75, 0.1, 0.4)
	style.shadow_size = 14
	card.add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.texture = _coin.texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	row.add_child(icon)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override("separation", -4)
	row.add_child(texts)
	var big: Label = Label.new()
	big.text = "+%d BALLS" % COIN_BALLS
	big.add_theme_font_size_override("font_size", 34)
	big.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	big.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.0))
	big.add_theme_constant_override("outline_size", 8)
	texts.add_child(big)
	var small: Label = Label.new()
	small.text = "Coin collected!"
	small.add_theme_font_size_override("font_size", 16)
	small.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 0.9))
	texts.add_child(small)

	_layer.add_child(card)
	await get_tree().process_frame  # wait one frame so the card knows its size
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	var spot: Vector2 = at - Vector2(card.size.x / 2.0, card.size.y + 40.0)
	spot.x = clampf(spot.x, 12.0, 1152.0 - card.size.x - 12.0)  # keep it on screen
	spot.y = clampf(spot.y, 12.0, 648.0 - card.size.y - 12.0)
	card.position = spot
	card.scale = Vector2(0.3, 0.3)
	card.modulate.a = 0.0
	var tw: Tween = card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(card, "position:y", spot.y - 50.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)


## A burst of gold sparkles where the coin was.
func _sparkles(at: Vector2) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = at
	p.z_index = 20
	p.amount = 36
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 280.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	fade.set_color(1, Color(1.0, 0.6, 0.1, 0.0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _update_hud() -> void:
	hud.text = "Level 4    Score: %d    Best: %d    Balls: %d    Enemies: %d" % [
		score, maxi(high_score, score), cannon.ammo, remaining]


func _win_level() -> void:
	super()  # saves the score, stops the game
	next_level.visible = false  # no level 5
	_show_panel("YOU WIN!", "All levels completed!\nFinal score: %d\nBest: %d" % [score, high_score],
			"Play again", _play_from_start)
	if _quit_button == null:  # Play again + Main menu already exist; add Quit
		_quit_button = Button.new()
		_quit_button.text = "Quit"
		_quit_button.add_theme_font_size_override("font_size", 26)
		_quit_button.pressed.connect(func() -> void: get_tree().quit())
		panel.get_child(0).add_child(_quit_button)


func _play_from_start() -> void:
	new_game()
	get_tree().change_scene_to_file("res://scenes/seeker.tscn")  # back to level 1
