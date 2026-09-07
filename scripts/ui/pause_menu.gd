extends CanvasLayer

var pause_overlay: ColorRect
var pause_panel: Panel
var controls_modal: Panel
var config_modal: Panel
var confirm_modal: Panel

func _ready() -> void:
	# PROCESS_MODE_ALWAYS garante que o menu funciona enquanto o jogo estiver pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100 # Garante que fica por cima de tudo
	
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		# Se algum sub-modal estiver aberto, fecha ele primeiro
		if controls_modal.visible:
			controls_modal.visible = false
			pause_panel.visible = true
			get_viewport().set_input_as_handled()
			return
		if config_modal.visible:
			config_modal.visible = false
			pause_panel.visible = true
			get_viewport().set_input_as_handled()
			return
		if confirm_modal.visible:
			confirm_modal.visible = false
			pause_panel.visible = true
			get_viewport().set_input_as_handled()
			return
			
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	pause_overlay.visible = is_paused
	pause_panel.visible = is_paused
	controls_modal.visible = false
	config_modal.visible = false
	confirm_modal.visible = false

func _build_ui() -> void:
	# 1. Overlay Escuro
	pause_overlay = ColorRect.new()
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0, 0, 0, 0.7)
	pause_overlay.visible = false
	add_child(pause_overlay)

	# 2. Painel Principal de Pause
	pause_panel = _create_base_modal("GAME PAUSED", Vector2(460, 300))
	pause_overlay.add_child(pause_panel)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_vbox.offset_left = 40.0
	btn_vbox.offset_top = 65.0
	btn_vbox.offset_right = -40.0
	btn_vbox.offset_bottom = -25.0
	btn_vbox.add_theme_constant_override("separation", 14)
	pause_panel.add_child(btn_vbox)

	# Botões do Menu
	var btn_resume = _create_styled_button("RESUME GAME")
	btn_resume.pressed.connect(toggle_pause)
	btn_vbox.add_child(btn_resume)

	var btn_controls = _create_styled_button("CONTROLS")
	btn_controls.pressed.connect(func():
		pause_panel.visible = false
		controls_modal.visible = true
	)
	btn_vbox.add_child(btn_controls)

	var btn_config = _create_styled_button("SETTINGS")
	btn_config.pressed.connect(func():
		pause_panel.visible = false
		config_modal.visible = true
	)
	btn_vbox.add_child(btn_config)

	var btn_menu = _create_styled_button("QUIT TO MAIN MENU")
	btn_menu.pressed.connect(func():
		pause_panel.visible = false
		confirm_modal.visible = true
	)
	btn_vbox.add_child(btn_menu)

	# 3. Sub-Modal de Controles
	_build_controls_modal()

	# 4. Sub-Modal de Configurações
	_build_config_modal()

	# 5. Sub-Modal de Confirmação para Sair
	_build_confirm_modal()

# --- SUB-MODAIS ---

func _build_controls_modal() -> void:
	controls_modal = _create_base_modal("CONTROLS", Vector2(560, 350))
	controls_modal.visible = false
	pause_overlay.add_child(controls_modal)

	var text = RichTextLabel.new()
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 35.0
	text.offset_top = 60.0
	text.offset_right = -35.0
	text.offset_bottom = -70.0
	text.bbcode_enabled = true
	text.fit_content = false
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.text = """[W] Accelerate / Move forward
    [A / D] Steer / Rotate
    [E] Open / Close Inventory
    [Space] Interact

    COMBAT MECHANICS:
    Build up speed to lower and charge your lance!
    The faster you strike enemies, the more damage you deal.
    Charge at top speed for maximum impact!"""
	
	controls_modal.add_child(text)

	var btn_back = _create_styled_button("BACK")
	btn_back.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn_back.offset_left = 40.0
	btn_back.offset_right = -40.0
	btn_back.offset_bottom = -15.0
	btn_back.offset_top = -55.0
	btn_back.pressed.connect(func():
		controls_modal.visible = false
		pause_panel.visible = true
	)
	controls_modal.add_child(btn_back)

func _build_config_modal() -> void:
	config_modal = _create_base_modal("SETTINGS", Vector2(560, 220))
	config_modal.visible = false
	pause_overlay.add_child(config_modal)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 40.0
	vbox.offset_top = 60.0
	vbox.offset_right = -40.0
	vbox.offset_bottom = -70.0
	vbox.add_theme_constant_override("separation", 16)
	config_modal.add_child(vbox)

	# Fullscreen
	var fs_row = HBoxContainer.new()
	var fs_label = Label.new()
	fs_label.text = "Fullscreen Mode"
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fs_check = CheckButton.new()
	fs_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fs_check.toggled.connect(func(toggled: bool):
		if toggled:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	fs_row.add_child(fs_label)
	fs_row.add_child(fs_check)
	vbox.add_child(fs_row)

	# Master Volume Slider
	var vol_row = VBoxContainer.new()
	var vol_label = Label.new()
	vol_label.text = "Master Volume"
	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	var bus_idx = AudioServer.get_bus_index("Master")
	vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	vol_slider.value_changed.connect(func(val: float):
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))
		AudioServer.set_bus_mute(bus_idx, val <= 0.001)
	)
	vol_row.add_child(vol_label)
	vol_row.add_child(vol_slider)
	vbox.add_child(vol_row)

	# Back Button
	var btn_back = _create_styled_button("BACK")
	btn_back.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn_back.offset_left = 40.0
	btn_back.offset_right = -40.0
	btn_back.offset_bottom = -15.0
	btn_back.offset_top = -55.0
	btn_back.pressed.connect(func():
		config_modal.visible = false
		pause_panel.visible = true
	)
	config_modal.add_child(btn_back)

func _build_confirm_modal() -> void:
	confirm_modal = _create_base_modal("WARNING", Vector2(520, 225))
	confirm_modal.visible = false
	pause_overlay.add_child(confirm_modal)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30.0
	vbox.offset_top = 60.0
	vbox.offset_right = -30.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 16)
	confirm_modal.add_child(vbox)

	var msg = Label.new()
	msg.text = "Are you sure you want to quit to the Main Menu?\nAll current run progress and unbanked upgrades will be lost!"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.modulate = Color("f2d9a6ff")
	vbox.add_child(msg)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var btn_cancel = _create_styled_button("CANCEL")
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.pressed.connect(func():
		confirm_modal.visible = false
		pause_panel.visible = true
	)
	btn_row.add_child(btn_cancel)

	var btn_confirm = _create_styled_button("QUIT & RESET")
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.pressed.connect(func():
		get_tree().paused = false # Despausa o jogo antes de trocar de cena
		if get_node_or_null("/root/GameManager"):
			get_node("/root/GameManager").reset_game_to_menu()
		else:
			get_tree().change_scene_to_file("res://weball/main_menu.tscn")
	)
	btn_row.add_child(btn_confirm)

# --- FUNÇÕES DE ESTILIZAÇÃO (PADRÃO DO JOGO) ---

func _create_base_modal(title_text: String, size: Vector2) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.10, 0.95)
	style.border_color = Color(0.83, 0.64, 0.45, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)

	var header_bar = ColorRect.new()
	header_bar.color = Color(0.83, 0.64, 0.45, 0.15)
	header_bar.custom_minimum_size = Vector2(0, 42)
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.offset_bottom = 42.0
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_bar)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.offset_top = 8.0
	title.offset_bottom = 36.0
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.modulate = Color(0.95, 0.85, 0.65)
	panel.add_child(title)

	return panel

func _create_styled_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 42)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.18, 0.15, 0.9)
	btn_normal.border_color = Color(0.83, 0.64, 0.45, 0.8)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.20, 0.30, 0.25, 0.95)
	btn_hover.border_color = Color(0.95, 0.85, 0.65, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.06, 0.10, 0.08, 0.95)
	btn_pressed.border_color = Color(0.83, 0.64, 0.45, 1.0)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(6)

	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	btn.add_theme_color_override("font_color", Color("f2d9a6ff"))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return btn
