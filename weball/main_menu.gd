class_name MainMenu
extends Control

# Texturas dos Assets
const TEX_BG = preload("res://assets/sprites/start_main_menu/cat.png")
const TEX_TITLE = preload("res://assets/sprites/start_main_menu/title.png")
const TEX_START = preload("res://assets/sprites/start_main_menu/start.png")
const TEX_CONTROLS = preload("res://assets/sprites/start_main_menu/controls.png")
const TEX_CONFIG = preload("res://assets/sprites/start_main_menu/config.png")
# PLACEHOLDER: Quando tiver o sprite do botão de créditos, basta descomentar / substituir por preload:
# const TEX_CREDITS = preload("res://assets/sprites/start_main_menu/credits.png")
const TEX_CREDITS: Texture2D = null
const TEX_EXIT = preload("res://assets/sprites/start_main_menu/exit.png")
const TEX_CLOSE = preload("res://assets/sprites/start_main_menu/close.png")

# Caminho da cena central que inicia o mundo
const GAME_SCENE_PATH = "res://scenes/game.tscn"

# Cores de feedback
const COLOR_NORMAL = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_HOVER = Color(1.2, 1.2, 1.2, 1.0)
const COLOR_PRESSED = Color(0.65, 0.65, 0.65, 1.0)

var bg_rect: TextureRect
var right_box: VBoxContainer
var title_rect: TextureRect
var btn_start: Control
var btn_controls: Control
var btn_config: Control
var btn_credits: Control
var btn_exit: Control
var fade_overlay: ColorRect

var controls_modal: Panel
var config_modal: Panel
var credits_modal: Panel
var is_transitioning: bool = false

func _ready() -> void:
	AudioManager.play_menu_theme()
	set_anchors_preset(PRESET_FULL_RECT)
	
	_build_ui()
	_build_modals()
	_setup_button_effects()
	_animate_intro()

func _build_ui() -> void:
	# 1. Background
	bg_rect = TextureRect.new()
	bg_rect.texture = TEX_BG
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg_rect)

	# 2. Container alinhado à direita
	right_box = VBoxContainer.new()
	right_box.alignment = BoxContainer.ALIGNMENT_CENTER
	right_box.add_theme_constant_override("separation", 14)
	right_box.anchor_left = 1.0
	right_box.anchor_right = 1.0
	right_box.anchor_top = 0.0
	right_box.anchor_bottom = 1.0
	right_box.offset_left = -480.0
	right_box.offset_right = -80.0
	right_box.offset_top = 40.0
	right_box.offset_bottom = -40.0
	add_child(right_box)

	# 3. Título
	title_rect = TextureRect.new()
	title_rect.texture = TEX_TITLE
	title_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	title_rect.custom_minimum_size = TEX_TITLE.get_size()
	right_box.add_child(title_rect)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	right_box.add_child(spacer)

	# 4. Botões
	btn_start = _create_btn(TEX_START, "START")
	btn_controls = _create_btn(TEX_CONTROLS, "CONTROLS")
	btn_config = _create_btn(TEX_CONFIG, "CONFIG")
	btn_credits = _create_btn(TEX_CREDITS, "CREDITS")
	btn_exit = _create_btn(TEX_EXIT, "EXIT")

	right_box.add_child(btn_start)
	right_box.add_child(btn_controls)
	right_box.add_child(btn_config)
	right_box.add_child(btn_credits)
	right_box.add_child(btn_exit)

	# 5. Cortina de transição
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_preset(PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func _build_modals() -> void:
	# ==============================
	# MODAL DE CONTROLES & LORE
	# ==============================
	controls_modal = _create_base_modal("HOW TO SURVIVE")
	
	var rich_text = RichTextLabel.new()
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.scroll_active = false
	rich_text.set_anchors_preset(PRESET_FULL_RECT)
	rich_text.offset_left = 28.0
	rich_text.offset_top = 55.0
	rich_text.offset_right = -28.0
	rich_text.offset_bottom = -20.0
	
	# Conteúdo com lore bobinho, mecânicas e layout colorido
	rich_text.text = """[color=#d4a373][b]THE STORY:[/b][/color]
You entered the cursed marsh for a quick ride. The locals are aggressive, the mud is thick, and your steed only knows how to charge forward. Survive the rounds, grab the shiny loot, and make it back to town in one piece!

[color=#d4a373][b]CONTROLS:[/b][/color]
• [color=#70c1b3][W / UP][/color] Accelerate steed
• [color=#70c1b3][S / DOWN][/color] Brake & Reverse
• [color=#70c1b3][A / D][/color] Steer / Drift around obstacles
• [color=#70c1b3][SPACE][/color] Talk to Townfolk & Buy Upgrades
• [color=#70c1b3][E][/color] Open inventory

[color=#e76f51][b]COMBAT TIP:[/b][/color]
Your lance deals damage [b]proportional to your velocity[/b]. Ram enemies at maximum speed to break their lines!
"""
	controls_modal.add_child(rich_text)
	add_child(controls_modal)

	# ==============================
	# MODAL DE CONFIGURAÇÕES NATIVO
	# ==============================
	config_modal = _create_base_modal("SETTINGS")
	
	var config_vbox = VBoxContainer.new()
	config_vbox.set_anchors_preset(PRESET_FULL_RECT)
	config_vbox.offset_left = 40.0
	config_vbox.offset_top = 65.0
	config_vbox.offset_right = -40.0
	config_vbox.offset_bottom = -30.0
	config_vbox.add_theme_constant_override("separation", 18)
	config_modal.add_child(config_vbox)

	# 1. Fullscreen Toggle
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
	config_vbox.add_child(fs_row)

	# 2. Master Volume Slider
	var vol_row = VBoxContainer.new()
	var vol_label = Label.new()
	vol_label.text = "Master Volume"
	
	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	
	var bus_idx = AudioServer.get_bus_index("Master")
	var current_db = AudioServer.get_bus_volume_db(bus_idx)
	vol_slider.value = db_to_linear(current_db)
	
	vol_slider.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		AudioServer.set_bus_mute(bus_idx, value <= 0.001)
	)
	
	vol_row.add_child(vol_label)
	vol_row.add_child(vol_slider)
	config_vbox.add_child(vol_row)

	# 3. Mute Toggle
	var mute_row = HBoxContainer.new()
	var mute_label = Label.new()
	mute_label.text = "Mute All Audio"
	mute_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mute_check = CheckButton.new()
	mute_check.button_pressed = AudioServer.is_bus_mute(bus_idx)
	mute_check.toggled.connect(func(toggled: bool):
		AudioServer.set_bus_mute(bus_idx, toggled)
	)
	mute_row.add_child(mute_label)
	mute_row.add_child(mute_check)
	config_vbox.add_child(mute_row)

	add_child(config_modal)

	# ==============================
	# MODAL DE CRÉDITOS
	# ==============================
	credits_modal = _create_base_modal("CREDITS")
	
	var credits_text = RichTextLabel.new()
	credits_text.bbcode_enabled = true
	credits_text.fit_content = false
	credits_text.scroll_active = true
	credits_text.set_anchors_preset(PRESET_FULL_RECT)
	credits_text.offset_left = 32.0
	credits_text.offset_top = 58.0
	credits_text.offset_right = -32.0
	credits_text.offset_bottom = -24.0
	
	# Placeholders configuráveis para a equipe e créditos
	credits_text.text = """[center]
[color=#d4a373][b]A GAME BY[/b][/color]
[color=#ffffff]ALTAIR GAME STUDIO[/color]
	
[color=#d4a373][b]GAME DESIGN & PROGRAMMING[/b][/color]
[color=#ffffff]Pedro Coterli (@PedroPHC25)[/color]
[color=#ffffff]João Gabriel (@)[/color]
[color=#ffffff]Jean Domingueti (@)[/color]
[color=#ffffff]Pedro Thomaz (@)[/color]

[color=#d4a373][b]ART & ANIMATION[/b][/color]
[color=#ffffff]João Gabriel (@)[/color]

[color=#d4a373][b]MUSIC & SOUND DESIGN[/b][/color]
[color=#ffffff]João Gabriel[/color]

[color=#888888]Thank you for playing![/color]
[/center]"""
	credits_modal.add_child(credits_text)
	add_child(credits_modal)

func _create_base_modal(title_text: String) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(560, 500)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	panel.visible = false

	# Estilo elegante escuro com borda dourada via código
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.10, 0.95)       # Verde-escuro pântano quase opaco
	style.border_color = Color(0.83, 0.64, 0.45, 1.0)    # Dourado envelhecido
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)

	# Faixa decorativa do topo do título
	var header_bar = ColorRect.new()
	header_bar.color = Color(0.83, 0.64, 0.45, 0.15)
	header_bar.custom_minimum_size = Vector2(0, 40)
	header_bar.set_anchors_preset(PRESET_TOP_WIDE)
	header_bar.offset_bottom = 42.0
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(header_bar)

	# Título da janela
	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.offset_top = 8.0
	title.offset_bottom = 36.0
	title.set_anchors_preset(PRESET_TOP_WIDE)
	title.modulate = Color(0.95, 0.85, 0.65)
	panel.add_child(title)

	# Botão Fechar (Close.png) posicionado no canto superior direito
	var close_btn = _create_btn(TEX_CLOSE)
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -44.0
	close_btn.offset_top = 8.0
	if close_btn is BaseButton:
		close_btn.pressed.connect(func(): panel.visible = false)
	panel.add_child(close_btn)

	return panel

func _create_btn(tex: Texture2D, fallback_text: String = "") -> Control:
	if tex != null:
		var btn = TextureButton.new()
		btn.texture_normal = tex
		btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
		btn.custom_minimum_size = tex.get_size()
		btn.pivot_offset = tex.get_size() / 2.0
		return btn
	else:
		# Botão estilizado de fallback enquanto a textura não for fornecida
		var btn = Button.new()
		btn.text = fallback_text if fallback_text != "" else "BUTTON"
		btn.custom_minimum_size = Vector2(192, 56)
		btn.pivot_offset = Vector2(96, 28)
		
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.12, 0.18, 0.15, 0.95)
		btn_normal.border_color = Color(0.83, 0.64, 0.45, 0.9)
		btn_normal.set_border_width_all(2)
		btn_normal.set_corner_radius_all(6)
		
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.20, 0.30, 0.25, 0.98)
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

func _setup_button_effects() -> void:
	var buttons = [btn_start, btn_controls, btn_config, btn_credits, btn_exit]
	for btn in buttons:
		btn.mouse_entered.connect(func():
			if not is_transitioning:
				var t = create_tween().set_parallel(true)
				t.tween_property(btn, "modulate", COLOR_HOVER, 0.08)
				t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
		)
		btn.mouse_exited.connect(func():
			if not is_transitioning:
				var t = create_tween().set_parallel(true)
				t.tween_property(btn, "modulate", COLOR_NORMAL, 0.08)
				t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
		)
		if btn is BaseButton:
			btn.button_down.connect(func():
				btn.modulate = COLOR_PRESSED
				btn.position.y += 2.0
			)
			btn.button_up.connect(func():
				btn.modulate = COLOR_HOVER
				btn.position.y -= 2.0
			)

	if btn_start is BaseButton:
		btn_start.pressed.connect(_on_start_pressed)
	if btn_controls is BaseButton:
		btn_controls.pressed.connect(func():
			config_modal.visible = false
			credits_modal.visible = false
			controls_modal.visible = true
		)
	if btn_config is BaseButton:
		btn_config.pressed.connect(func():
			controls_modal.visible = false
			credits_modal.visible = false
			config_modal.visible = true
		)
	if btn_credits is BaseButton:
		btn_credits.pressed.connect(func():
			controls_modal.visible = false
			config_modal.visible = false
			credits_modal.visible = true
		)
	if btn_exit is BaseButton:
		btn_exit.pressed.connect(func():
			if not is_transitioning:
				get_tree().quit()
		)

func _animate_intro() -> void:
	title_rect.modulate.a = 0.0
	for b in [btn_start, btn_controls, btn_config, btn_credits, btn_exit]:
		b.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(title_rect, "modulate:a", 1.0, 0.35)
	for b in [btn_start, btn_controls, btn_config, btn_credits, btn_exit]:
		tween.tween_property(b, "modulate:a", 1.0, 0.1)

func _on_start_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	)
