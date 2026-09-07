extends Control

@onready var damage_mask: Panel = $DamageMask
@onready var heal_mask: Panel = $HealMask

var mask_start_x: float = 32.0
var max_mask_width: float = 284.0
var heal_tween = null

func _ready() -> void:
	if damage_mask:
		mask_start_x = damage_mask.position.x
		max_mask_width = damage_mask.size.x
		# Começa a máscara com tamanho 0 (vida 100% cheia)
		damage_mask.size.x = 0.0
	if heal_mask:
		heal_mask.size.x = 0.0
	# Aguarda 1 frame para garantir que o Player já executou o seu _ready() e definiu current_health
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player") as Player
	if player:
		_on_player_health_changed(player.current_health, player.max_health + player.extra_health)
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current: float, max_h: float) -> void:
	if not damage_mask:
		return
	var health_percent: float = clampf(current / maxf(1.0, max_h), 0.0, 1.0)
	var missing_percent: float = 1.0 - health_percent
	
	# Ajusta a largura e a posição da máscara preta conforme o dano recebido
	var current_mask_width: float = max_mask_width * missing_percent
	damage_mask.size.x = current_mask_width
	damage_mask.position.x = mask_start_x + (max_mask_width - current_mask_width)

func hide_heal_mask() -> void:
	if heal_tween:
		heal_tween.kill()
	heal_tween = create_tween()
	heal_tween.tween_property(heal_mask, "self_modulate:a", 0, 0.4)

func show_heal_mask(current: float, max_h: float, to_heal: float) -> void:
	if (current >= max_h):
		hide_heal_mask()
		return
	var health_percent: float = clampf(current / maxf(1.0, max_h), 0.0, 1.0)
	heal_mask.size.x = max_mask_width*(to_heal)/max_h
	heal_mask.position.x = mask_start_x + (max_mask_width*health_percent)
	if heal_tween:
		heal_tween.kill()
	heal_tween = create_tween().set_loops()
	heal_tween.tween_property(heal_mask, "self_modulate:a", 0.8, 0.5)
	heal_tween.tween_property(heal_mask, "self_modulate:a", 0, 0.5)
