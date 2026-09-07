extends NPC

func _ready() -> void:
	# Garante que o NPC esteja no grupo para o TownUI conectar
	add_to_group("npcs")
	npc_type = NPCType.SHOP
	npc_name = "Seller"
	prompt_message = "[Space] Open the store"

	prompt_label.text = prompt_message
	prompt_label.visible = false

	if visual and "modulate" in visual:
		visual.modulate = accent_color

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		prompt_label.visible = true
		_show_praise_if_eligible()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		prompt_label.visible = false
		_hide_praise()
		
func _unhandled_input(event: InputEvent) -> void:
	if player_in_range:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			var player = get_tree().get_first_node_in_group("player")
			if is_instance_valid(player):
				var inv_node = player.get_node("PlayerCanvas/inventory")
				var store_node = player.get_node("PlayerCanvas/inventory/store")
				
				# Se o inventário/loja não estiver aberto, abre a loja
				if not (inv_node.visible and store_node.visible):
					inv_node.visible = true
					store_node.visible = true
					player.can_move = false
					player.velocity = Vector2.ZERO
					interacted.emit(self)
					get_viewport().set_input_as_handled()
				else:
					inv_node.visible = false
					store_node.visible = false
					player.can_move = true
					interacted.emit(self)
					get_viewport().set_input_as_handled()
					
