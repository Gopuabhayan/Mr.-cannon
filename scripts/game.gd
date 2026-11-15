class_name Game
extends Node2D

# Each ghost: [x, y, drift_x, drift_y, drift_speed]
# Ghosts are spread over the whole play area.
const LEVELS: Array = [
	[[170, 150, 0, 8, 2.0], [330, 330, 0, 8, 2.0], [560, 190, 0, 8, 2.0],
	 [850, 150, 0, 8, 2.0], [960, 430, 0, 8, 2.0]],
	[[160, 420, 0, 30, 1.5], [250, 160, 30, 0, 1.2], [420, 300, 0, 40, 1.6],
	 [680, 200, 40, 0, 1.3], [800, 400, 0, 40, 1.8], [940, 170, 0, 30, 1.4],
	 [1000, 330, 0, 40, 1.7]],
	[[150, 200, 30, 30, 1.6], [200, 440, 40, 0, 1.4], [360, 140, 40, 0, 1.8],
	 [430, 400, 0, 50, 2.0], [620, 300, 50, 30, 1.5], [720, 130, 50, 0, 1.9],
	 [800, 440, 40, 0, 1.7], [930, 250, 0, 60, 2.2], [1000, 440, 0, 40, 1.6]],
]
const START_BALLS: int = 5
const MAX_BALL_BOUNCES: int = 3  # level 1
const POINTS_PER_GHOST: int = 2
const BALLS_PER_GHOST: int = 2
const SAVE_PATH: String = "user://save.cfg"

# Persist between scene reloads.
static var level_index: int = 0
static var total_score: int = 0
static var high_score: int = -1
static var last_score: int = 0

var remaining: int = 0
var score: int = 0
var over: bool = false

var hud: Label
var hint: Label
var panel: PanelContainer
var title: Label
var info: Label
var primary: Button
var primary_action: Callable
var next_level: Button

@onready var cannon: Cannon = $Cannon


static func new_game() -> void:
	level_index = 0
	total_score = 0


static func load_high_score() -> void:
	if high_score >= 0:
		return
	high_score = 0
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("game", "high_score", 0))


func _ready() -> void:
	load_high_score()
	Arena.set_background(Arena.DEFAULT_BG)
	score = total_score
	var ghost_data: Array = LEVELS[level_index]
	cannon.ammo = START_BALLS
	cannon.max_bounces = MAX_BALL_BOUNCES
	cannon.fired.connect(_update_hud)

	_build_ui()
	for g in ghost_data:
		var ghost: Ghost = Ghost.new()
		ghost.position = Vector2(g[0], g[1])
		ghost.amplitude = Vector2(g[2], g[3])
		ghost.speed = g[4]
		ghost.killed.connect(_on_ghost_killed)
		ghost.died.connect(_on_ghost_died)
		add_child(ghost)
		remaining += 1
	_update_hud()


func _make_label(size: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _build_ui() -> void:
	Sfx.start_music()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	hud = _make_label(24)
	hud.position = Vector2(24, 8)
	layer.add_child(hud)

	hint = _make_label(18)
	hint.position = Vector2(24, 608)
	hint.text = "Aim: mouse   Fire: click / space   Ghosts only die after the ball BOUNCES off a wall!   Restart: R"
	layer.add_child(hint)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	panel = PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(440, 300)
	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 26)
	box.add_child(info)

	primary = Button.new()
	primary.add_theme_font_size_override("font_size", 26)
	primary.pressed.connect(func() -> void: primary_action.call())
	box.add_child(primary)

	next_level = Button.new()
	next_level.text = "Next level"
	next_level.visible = false
	next_level.add_theme_font_size_override("font_size", 26)
	next_level.pressed.connect(_go_next_level)
	box.add_child(next_level)

	var menu: Button = Button.new()
	menu.text = "Main menu"
	menu.add_theme_font_size_override("font_size", 26)
	menu.pressed.connect(_go_menu)
	box.add_child(menu)


func _show_panel(t: String, i: String, button_text: String, action: Callable) -> void:
	title.text = t
	info.text = i
	primary.text = button_text
	primary_action = action
	panel.visible = true


func _update_hud() -> void:
	hud.text = "Level 1    Score: %d    Best: %d    Balls: %d    Ghosts: %d" % [
		score, maxi(high_score, score), cannon.ammo, remaining]


func _on_ghost_killed(at: Vector2) -> void:
	score += POINTS_PER_GHOST
	cannon.ammo += BALLS_PER_GHOST
	_update_hud()
	_popup(at, "+%d points  +%d balls" % [POINTS_PER_GHOST, BALLS_PER_GHOST])


func _popup(at: Vector2, text: String) -> void:
	var l: Label = _make_label(22)
	l.text = text
	l.position = at + Vector2(-80, -70)
	l.z_index = 10
	add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40.0, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _on_ghost_died() -> void:
	remaining -= 1
	_update_hud()
	if remaining <= 0:
		_win_level()


func _process(_delta: float) -> void:
	# Out of balls, none still flying, and enemies left -> game over.
	if over or remaining <= 0 or cannon.ammo > 0:
		return
	if get_tree().get_nodes_in_group("ball").is_empty():
		_game_over()


func _game_over() -> void:
	over = true
	Sfx.play("lose")
	_save_high_score()
	_update_hud()
	next_level.visible = false
	_show_panel("GAME OVER", "Out of balls!\nScore: %d\nBest: %d" % [score, high_score],
			"Try again", _retry_level)


func _retry_level() -> void:
	get_tree().reload_current_scene()  # same level again, keeping the score you arrived with


func _win_level() -> void:
	if over:
		return
	over = true
	Sfx.play("win")
	cannon.ammo = 0
	total_score = score
	_save_high_score()
	_update_hud()
	_show_panel("YOU WIN!", "Final score: %d\nBest: %d" % [score, high_score],
			"Play again", _restart_all)
	next_level.visible = true


func _save_high_score() -> void:
	if score > high_score:
		high_score = score
		var cfg: ConfigFile = ConfigFile.new()
		cfg.set_value("game", "high_score", high_score)
		cfg.save(SAVE_PATH)


func _restart_all() -> void:
	new_game()
	get_tree().reload_current_scene()


func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main_Menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and key.keycode == KEY_R:
			_restart_all()


func _go_next_level() -> void:
	get_tree().change_scene_to_file("res://scenes/node_2d.tscn")
