extends Control

var _options: Control  # the Options screen (built in code, hidden until the button is pressed)


func _ready() -> void:
	Game.load_high_score()
	Sfx.start_music()
	# The "option" button used to start the game; make it open the Options screen instead.
	var option_button: Button = $VBoxContainer/Button2
	if option_button.pressed.is_connected(_on_button_pressed):
		option_button.pressed.disconnect(_on_button_pressed)
	option_button.pressed.connect(_show_options)
	_build_options()


func _on_button_pressed() -> void:
	Game.new_game()
	get_tree().change_scene_to_file("res://scenes/seeker.tscn")


func _on_button_3_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible and event.is_action_pressed("ui_cancel"):
		_hide_options()


func _show_options() -> void:
	$VBoxContainer.visible = false
	_options.visible = true


func _hide_options() -> void:
	_options.visible = false
	$VBoxContainer.visible = true


func _build_options() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	add_child(center)
	_options = center

	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	_add_volume_row(box, "Volume", "Master")
	_add_volume_row(box, "Music", "Music")
	_add_volume_row(box, "Effects", "SFX")

	var back: Button = Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(_hide_options)
	box.add_child(back)


## One row:  Name  [=====slider=====]  80%
func _add_volume_row(parent: Control, label_text: String, bus: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var name_label: Label = Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.add_theme_font_size_override("font_size", 26)
	row.add_child(name_label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Sfx.get_volume(bus)
	slider.custom_minimum_size = Vector2(260, 30)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var percent: Label = Label.new()
	percent.custom_minimum_size = Vector2(70, 0)
	percent.add_theme_font_size_override("font_size", 26)
	percent.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(percent)

	slider.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(bus, v)
		percent.text = "%d%%" % roundi(v * 100.0))
	if bus != "Music":  # let you hear the new level when you let go of the slider
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("shoot"))
