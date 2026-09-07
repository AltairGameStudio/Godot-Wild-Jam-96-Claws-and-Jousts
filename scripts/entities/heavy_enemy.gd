class_name HeavyEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 150.0
@export var move_speed: float = 65.0
@export var turn_speed: float = 0.6
@export var knockback_multiplier: float = 2.0

@export_group("Mecânica Pesada")
@export var min_damage_impact_speed: float = 350.0 # Velocidade mínima necessária do player para furar a armadura
@export var deflect_damage: float = 20.0            # Dano que o player toma se bater devagar demais
@export var deflect_knockback: float = 600.0        # Força com que o player é empurrado ao ricochetear
@export var backstab_multiplier: float = 2.0        # Multiplicador de dano ao ser atingido por trás
@export var backstab_angle_threshold: float = 0.4   # Alinhamento vetorial para considerar golpe pelas costas

@export_group("Comportamento")
@export var separation_strength: float = 40.0
@onready var separation_area: Area2D = $SeparationArea
@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var health_bar: ProgressBar = $HealthBar

@export_group("Drops de Recompensa")
@export var min_gold_drop: int = 17
@export var max_gold_drop: int = 20

var current_health: float
var player_ref: Node2D = null
var is_dead: bool = false
var default_sprite_scale: Vector2 = Vector2.ONE
var default_modulate: Color = Color.WHITE
var hit_tween: Tween = null

var drop = preload("res://scenes/ui/item.tscn")
var items_can_drop = [3,4]
var chances_of_drop = [0.1, 0.3]

func _ready() -> void:
	add_to_group("enemies")
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		default_sprite_scale = sprite.scale
		default_modulate = sprite.modulate
	
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true
		_update_healthbar_position()
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	_handle_ai_chase(delta)
	move_and_slide()
	_update_healthbar_position()

func _get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
		
	var push_vector = Vector2.ZERO
	var overlapping_areas = separation_area.get_overlapping_areas()
	
	for area in overlapping_areas:
		if area != separation_area:
			var diff = global_position - area.global_position
			var distance = diff.length()
			if distance > 0.0:
				push_vector += diff.normalized() / maxf(distance, 1.0)
				
	return push_vector.normalized()

func _handle_ai_chase(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	# Rotação pesada e lenta em direção ao jogador
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Movimento para frente baseado na orientação atual do inimigo
	var forward_facing = Vector2.DOWN.rotated(rotation)
	
	if distance > 25.0:
		var desired_velocity = forward_facing * move_speed
		var separation = _get_separation_vector() * separation_strength
		desired_velocity += separation
		
		velocity = velocity.move_toward(desired_velocity, 300.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, 35.0)

func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	# Vetor frontal do inimigo
	var enemy_forward = Vector2.DOWN.rotated(rotation)
	AudioManager.play_sfx(AudioManager.SFX_HIT)
	
	# Verifica se o ataque veio por trás
	var is_backstab = direction.dot(enemy_forward) > backstab_angle_threshold
	
	# Caso 1: Jogador bateu devagar demais
	if impact_speed < min_damage_impact_speed and not is_backstab:
		play_hit_feedback(true)
		# Pequena reação física do inimigo
		velocity += direction * (impact_speed * 0.1 + 50.0)
		
		# Aplica dano de punição no jogador
		if is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
			var bounce_force = -direction * deflect_knockback
			player_ref.take_damage(deflect_damage, bounce_force, true)
		return

	# Caso 2: Golpe com velocidade suficiente OU golpe pelas costas
	play_hit_feedback(false)
	var final_damage = damage
	if is_backstab:
		final_damage *= backstab_multiplier

	current_health = maxf(0.0, current_health - final_damage)
	if health_bar:
		health_bar.value = current_health
	
	var knockback_force = impact_speed * knockback_multiplier
	if is_backstab:
		knockback_force *= 1.4
	if current_health <= 0.0:
		# Impulso extra e violento na morte
		knockback_force *= 1.35
	
	velocity += direction * knockback_force
	
	if current_health <= 0.0:
		die()

func play_hit_feedback(is_deflected: bool = false) -> void:
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
		
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		
	hit_tween = create_tween().set_parallel(true)
	
	# Flash metálico para deflexão, branco vivo para dano
	sprite.modulate = Color(1.8, 1.8, 2.2, 1.0) if is_deflected else Color(2.5, 2.5, 2.5, 1.0)
	hit_tween.tween_property(sprite, "modulate", default_modulate, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var squashed = Vector2(default_sprite_scale.x * 0.85, default_sprite_scale.y * 1.2) if is_deflected else Vector2(default_sprite_scale.x * 1.35, default_sprite_scale.y * 0.7)
	sprite.scale = squashed
	hit_tween.tween_property(sprite, "scale", default_sprite_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func create_item() -> void:
	var coin_amount = randi_range(min_gold_drop, max_gold_drop)
	var coin_drop = drop.instantiate()
	coin_drop.setup(100 + coin_amount, self.global_position)
	get_tree().current_scene.get_node("World/Arena").add_child(coin_drop)
	
	for idx in range(items_can_drop.size()):
		if randf() <= chances_of_drop[idx]:
			var idx_drop = drop.instantiate()
			var idx_lvl = randi_range(1,5)
			var offset = Vector2(randi_range(-5,5), randi_range(-5,5))
			idx_drop.setup(items_can_drop[idx]*100 + idx_lvl, self.global_position + offset)
			get_tree().current_scene.get_node("World/Arena").add_child(idx_drop)
			return

func die() -> void:
	if is_dead: return
	is_dead = true
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)
	call_deferred("create_item")
	enemy_died.emit()
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)
	
	if is_instance_valid(health_bar):
		health_bar.visible = false
		
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var death_tween = create_tween().set_parallel(true)
		death_tween.tween_property(sprite, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(sprite, "scale", sprite.scale * 1.3, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.chain().tween_callback(queue_free)
	else:
		queue_free.call_deferred()
