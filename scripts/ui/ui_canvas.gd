extends CanvasLayer

const TEX_CLOSE = preload("res://assets/sprites/start_main_menu/close.png")

func _ready() -> void:
	$inventory.visible = false
	$inventory/store.visible = false
	$upgrade_shop.visible = false
	$equipment.visible = false
	
	_setup_inventory_close_button()

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	# Tecla E para abrir/fechar inventário normal
	if Input.is_action_just_pressed("toggle_inventory"):
		if $upgrade_shop.visible:
			$upgrade_shop.visible = false
		var is_open = $inventory.visible
		if not is_open:
			$inventory.visible = true
			if is_instance_valid(player) and get_tree().current_scene.is_in_run:
				player.can_move = false
				player.velocity = Vector2.ZERO
		else:
			$inventory.visible = false
			$inventory/store.visible = false
			$upgrade_shop.visible = false
			if is_instance_valid(player):
				player.can_move = true

	# Tecla ESC (ui_cancel) para fechar lojas e inventários
	# if Input.is_action_just_pressed("ui_cancel"):
		# var was_any_open = $inventory.visible or $upgrade_shop.visible or $inventory/store.visible
		# $inventory.visible = false
		# $inventory/store.visible = false
		# $upgrade_shop.visible = false
		
		# # Se alguma janela foi fechada pelo ESC, libera o movimento do player
		# if was_any_open and is_instance_valid(player):
			# player.can_move = true

func add_item_inventory(new_item: Area2D) -> bool:
	var empty = null
	for inv_slot in $inventory/invent/Container.get_children():
		if inv_slot is not slot:
			continue
		if inv_slot.id == new_item.item_id:
			var new_amount = int(inv_slot.get_node("amount").text)
			new_amount += 1
			inv_slot.get_node("amount").text = str(new_amount)
			return true
		elif inv_slot.id == 0 and empty == null:
			empty = inv_slot
	if not(empty == null):
		empty.get_node("sprite").texture = new_item.get_node("sprite").texture
		empty.get_node("amount").text = "1"
		empty.id = new_item.item_id
		return true
	return false

func close_all_menus() -> void:
	$inventory.visible = false
	if $inventory.has_node("store"):
		$inventory/store.visible = false
	$upgrade_shop.visible = false
	
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.can_move = true
		
func _create_configured_close_button(btn_size: Vector2, margin_right: float, margin_top: float) -> TextureButton:
	var close_btn = TextureButton.new()
	close_btn.texture_normal = TEX_CLOSE
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.custom_minimum_size = btn_size
	
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = - (margin_right + btn_size.x)
	close_btn.offset_right = - margin_right
	close_btn.offset_top = margin_top
	close_btn.offset_bottom = margin_top + btn_size.y
	close_btn.pressed.connect(close_all_menus)
	return close_btn

func _setup_inventory_close_button() -> void:
	# Ajuste para a aba da Loja de Itens ($inventory/store)
	# if $inventory.has_node("store"):
		# # Exemplo: Tamanho 30x30, margem direita 18px, margem do topo 12px
		# var store_btn = _create_configured_close_button(Vector2(48, 48), -350.0, 12.0)
		# $inventory/store.add_child(store_btn)

	# Ajuste para a aba do Inventário ($inventory/invent)
	if $inventory.has_node("invent"):
		# Exemplo: Tamanho 26x26, margem direita 14px, margem do topo 10px
		var invent_btn = _create_configured_close_button(Vector2(48, 48), -350.0, 10.0)
		$inventory/invent.add_child(invent_btn)
