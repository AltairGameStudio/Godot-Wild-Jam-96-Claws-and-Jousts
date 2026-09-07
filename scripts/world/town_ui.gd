class_name TownUI
extends CanvasLayer

@onready var dialogue_box: Panel = $UI/DialogueWindow
@onready var dialogue_name: Label = $UI/DialogueWindow/NameLabel
@onready var dialogue_text: Label = $UI/DialogueWindow/TextLabel

@onready var shop_window: Panel = $UI/ShopWindow
@onready var upgrade_window: Panel = $UI/UpgradeWindow

var active_dialogue: Array[String] = []
var dialogue_index: int = 0

enum TutorialState { CONTROLS, GO_TO_NPC, VISIT_SHOPS, COMPLETED }
var current_tutorial_state: TutorialState = TutorialState.COMPLETED

var arena_npc: Node2D = null
var shop_npcs: Array[Node2D] = []
var player: Node2D = null

@onready var controls_panel = $UI/ControlsBackground
@onready var objective_label: Label = $UI/ObjectiveLabel
@onready var target_indicator: Control = $UI/TargetIndicator

const TEX_CLOSE = preload("res://assets/sprites/start_main_menu/close.png")
var tutorial_modal: Panel = null

func _ready() -> void:
	dialogue_box.visible = false
	shop_window.visible = false
	upgrade_window.visible = false
	
	# Conecta todos os NPCs presentes no mapa
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc is NPC:
			npc.interacted.connect(_handle_npc_interaction)
			if npc.npc_type == NPC.NPCType.EXPEDITION_GATE:
				arena_npc = npc
			elif npc.npc_type == NPC.NPCType.SHOP or npc.npc_type == NPC.NPCType.UPGRADE:
				shop_npcs.append(npc)
			
	player = get_tree().get_first_node_in_group("player")

	# Busca a fase atual no nó principal do jogo
	var phase = 1
	var game_node = get_tree().root.get_node_or_null("Game")
	if not game_node:
		# Tenta pegar subindo na hierarquia (TownHUD -> Town -> World -> Game)
		game_node = get_node_or_null("/root/Game")
	
	if game_node and "current_phase" in game_node:
		phase = game_node.current_phase
	elif get_tree().current_scene and "current_phase" in get_tree().current_scene:
		phase = get_tree().current_scene.current_phase

	# Cria o modal estilizado e adiciona dentro do ControlsBackground
	_build_tutorial_modal()
	
	# Aplica a estilização no banner de objetivo superior
	_style_objective_label()

	print(">>> [TownUI] Iniciando Cidade na Fase: ", phase)

	if phase == 1:
		_start_tutorial_controls()
	elif phase == 2:
		controls_panel.visible = false
		_start_tutorial_visit_shops()
	else:
		current_tutorial_state = TutorialState.COMPLETED
		controls_panel.visible = false
		objective_label.visible = false
		target_indicator.visible = false

func _handle_npc_interaction(npc: NPC) -> void:
	# Se interagiu com um NPC que tinha exclamação, remove daquele NPC
	if npc.has_quest:
		npc.has_quest = false
		target_indicator.custom_targets.erase(npc)
		
		# Se visitou todas as lojas, pode esconder o objetivo ou pedir para voltar para a arena
		if current_tutorial_state == TutorialState.VISIT_SHOPS:
			if target_indicator.custom_targets.is_empty():
				objective_label.text = "Ready? Go back to the Arena Guardian!"
				if is_instance_valid(arena_npc):
					target_indicator.custom_targets = [arena_npc]
					arena_npc.has_quest = true

	match npc.npc_type:
		NPC.NPCType.DIALOGUE, NPC.NPCType.QUEST:
			_start_dialogue(npc.npc_name, npc.dialogue_pages)
		#NPC.NPCType.SHOP:
			#shop_window.visible = true
		#NPC.NPCType.UPGRADE:
			#upgrade_window.visible = true
		NPC.NPCType.EXPEDITION_GATE:
			current_tutorial_state = TutorialState.COMPLETED
			objective_label.visible = false
			target_indicator.custom_targets.clear()
			target_indicator.visible = false
			if is_instance_valid(arena_npc):
				arena_npc.has_quest = false
			get_tree().current_scene.start_run()

func _start_dialogue(speaker: String, text_pages: Array[String]) -> void:
	dialogue_name.text = speaker
	active_dialogue = text_pages
	dialogue_index = 0
	dialogue_box.visible = true
	_show_current_page()

func _show_current_page() -> void:
	if dialogue_index < active_dialogue.size():
		dialogue_text.text = active_dialogue[dialogue_index]
	else:
		dialogue_box.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if current_tutorial_state == TutorialState.CONTROLS and event.is_action_pressed("ui_accept"):
		_advance_tutorial()
		get_viewport().set_input_as_handled()

func _start_tutorial_controls() -> void:
	current_tutorial_state = TutorialState.CONTROLS
	controls_panel.visible = true
	objective_label.visible = false
	if is_instance_valid(player):
		player.can_move = false

func _start_tutorial_go_to_npc() -> void:
	current_tutorial_state = TutorialState.GO_TO_NPC
	controls_panel.visible = false
	objective_label.visible = true
	objective_label.text = "Go to the Arena Guardian to start an expedition."
	
	if is_instance_valid(player):
		player.can_move = true
	
	# Passa o NPC da arena como alvo da seta:
	if is_instance_valid(arena_npc):
		target_indicator.custom_targets = [arena_npc]
		target_indicator.visible = true
		arena_npc.has_quest = true

func _start_tutorial_visit_shops() -> void:
	current_tutorial_state = TutorialState.VISIT_SHOPS
	controls_panel.visible = false # <--- Garante que os controles estão fechados
	if is_instance_valid(player):
		player.can_move = true     # <--- Garante que o jogador pode andar
	objective_label.visible = true
	objective_label.text = "Visit the shops to upgrade your gear!"
	
	# Ativa a exclamação em todas as lojas
	for shop in shop_npcs:
		if is_instance_valid(shop):
			shop.has_quest = true
			
	# Passa todos os NPCs das lojas para o indicador de setas
	target_indicator.custom_targets = shop_npcs.duplicate()
	target_indicator.visible = true

func _build_tutorial_modal() -> void:
	# 1. Se já existir o Label antigo dentro de controls_panel na cena, oculte-o:
	var old_label = controls_panel.get_node_or_null("Label")
	if old_label:
		old_label.visible = false

	# 2. Cria a moldura (Panel)
	tutorial_modal = Panel.new()
	tutorial_modal.custom_minimum_size = Vector2(580, 360)
	tutorial_modal.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tutorial_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 3. Aplica o StyleBoxFlat (Fundo Verde Escuro + Borda Dourada)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.10, 0.95)
	style.border_color = Color(0.83, 0.64, 0.45, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	tutorial_modal.add_theme_stylebox_override("panel", style)

	# 4. Faixa de Cabeçalho
	var header_bar = ColorRect.new()
	header_bar.color = Color(0.83, 0.64, 0.45, 0.15)
	header_bar.custom_minimum_size = Vector2(0, 40)
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bar.offset_bottom = 42.0
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_modal.add_child(header_bar)

	# 5. Título da Janela
	var title = Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.offset_top = 8.0
	title.offset_bottom = 36.0
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.modulate = Color(0.95, 0.85, 0.65)
	tutorial_modal.add_child(title)

	# 6. Botão de Fechar [X]
	var close_btn = TextureButton.new()
	close_btn.texture_normal = TEX_CLOSE
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -44.0
	close_btn.offset_top = 8.0
	close_btn.pressed.connect(_advance_tutorial)
	tutorial_modal.add_child(close_btn)

	# 7. RichTextLabel com BBCode e Cores
	var rich_text = RichTextLabel.new()
	rich_text.bbcode_enabled = true
	rich_text.fit_content = true
	rich_text.scroll_active = false
	rich_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	rich_text.offset_left = 28.0
	rich_text.offset_top = 55.0
	rich_text.offset_right = -28.0
	rich_text.offset_bottom = -20.0
	
	rich_text.text = """[color=#d4a373][b]CONTROLS:[/b][/color]
• [color=#70c1b3][W / UP][/color] Accelerate / Move forward
• [color=#70c1b3][S / DOWN][/color] Brake & Reverse
• [color=#70c1b3][A / D][/color] Steer / Rotate
• [color=#70c1b3][SPACE][/color] Interact with NPCs
• [color=#70c1b3][E][/color] Open / Close Inventory

[color=#e76f51][b]COMBAT MECHANICS:[/b][/color]
Build up speed to lower and charge your lance!
The faster you strike enemies, the more damage you deal.

[center][color=#d4a373][i][ Press SPACE or (X) to continue ][/i][/color][/center]"""
	tutorial_modal.add_child(rich_text)

	# Adiciona o modal como filho do ControlsBackground
	controls_panel.add_child(tutorial_modal)
	
func _advance_tutorial() -> void:
	if current_tutorial_state != TutorialState.CONTROLS:
		return
		
	var player_node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player_node):
		var equip = player_node.get_node_or_null("PlayerCanvas/equipment")
		if equip:
			equip.visible = true
			
	_start_tutorial_go_to_npc()

func _style_objective_label() -> void:
	if not is_instance_valid(objective_label):
		return
		
	# 1. Configura o StyleBoxFlat (Mesma paleta do menu principal)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.10, 0.90)       # Verde-escuro pântano
	style.border_color = Color(0.83, 0.64, 0.45, 1.0)    # Dourado/bronze
	style.set_border_width_all(2)                         # Borda sutil de 2px
	style.set_corner_radius_all(6)                        # Cantos arredondados
	style.shadow_color = Color(0, 0, 0, 0.5)              # Sombra suave
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	
	# Margens internas para o texto respirar dentro do painel
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	
	objective_label.add_theme_stylebox_override("normal", style)
	
	# 2. Cores e tipografia do texto
	objective_label.add_theme_color_override("font_color", Color("f2d9a6ff")) # Dourado claro
	objective_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.06, 1.0)) # Contorno escuro
	objective_label.add_theme_constant_override("outline_size", 4)
	objective_label.add_theme_font_size_override("font_size", 20) # Tamanho harmonioso
	
	# 3. Posição e alinhamento no Canto Superior Direito
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Posição relativa ao canto superior direito:
	# offset_left negativo define onde a borda esquerda do banner começa
	# offset_right negativo define a margem da borda direita da tela
	objective_label.offset_left = -520.0
	objective_label.offset_right = -24.0
	objective_label.offset_top = 24.0
	objective_label.offset_bottom = 72.0
	
	# Desabilita cliques para não atrapalhar o jogo (Mouse Filter: Ignore)
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
