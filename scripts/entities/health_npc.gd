extends NPC

const HEAL_AMOUNT: float = 20.0
const HEAL_COST: int = 5

var player_ref: Player = null

func _ready() -> void:
	add_to_group("npcs")
	npc_type = NPCType.SHOP
	npc_name = "Doctor"
	prompt_message = "[Space] Pay %d to cure %d of life" % [HEAL_COST, int(HEAL_AMOUNT)]
	prompt_label.position += Vector2(350, -50)
	prompt_label.set_rotation_degrees(-180)
	visual.modulate = Color(0.7, 0, 0)
	prompt_label.text = prompt_message
	prompt_label.visible = false
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _update_heal_prompt() -> void:
	if not is_instance_valid(player_ref):
		return
	
	var total_max = player_ref.max_health + player_ref.extra_health
	var life_missing = total_max - player_ref.current_health
	var current_gold = get_tree().current_scene.gold

	if life_missing <= 0.0:
		prompt_label.text = "Your life is full"
	elif current_gold < HEAL_COST:
		prompt_label.text = "Come back when you have %d gold!" % HEAL_COST
	else:
		prompt_label.text = prompt_message
	var health_bar = player_ref.get_node("PlayerCanvas/HealthBarContainer")
	health_bar.show_heal_mask(player_ref.current_health, player_ref.max_health + player_ref.extra_health, HEAL_AMOUNT)
	

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_ref = body
		player_in_range = true
		_update_heal_prompt()
		prompt_label.visible = true
		_show_praise_if_eligible()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		prompt_label.visible = false
		_hide_praise()
		player_ref.get_node("PlayerCanvas/HealthBarContainer").hide_heal_mask()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and is_instance_valid(player_ref):
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			var total_max = player_ref.max_health + player_ref.extra_health
			var life_missing = total_max - player_ref.current_health
			var current_gold = get_tree().current_scene.gold
			
			# Só cura e cobra se tiver pelo menos 5 de ouro e a vida não estiver cheia
			if current_gold >= HEAL_COST and life_missing > 0.0:
				get_tree().current_scene.gold -= HEAL_COST
				player_ref.heal(HEAL_AMOUNT)
				_update_heal_prompt()
			
			interacted.emit(self)
