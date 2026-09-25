class_name SwordEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 90.0
@export var move_speed: float = 120.0
@export var turn_speed: float = 3.5
@export var contact_damage: float = 15.0
@export var knockback_multiplier: float = 4.0

@export_group("Comportamento Orgânico")
@export var wobble_frequency: float = 3.0    # Velocidade da oscilação
@export var wobble_amplitude: float = 0.5    # Intensidade do desvio lateral (0.0 a 1.0)

@export_group("Drops de Recompensa")
@export var min_gold_drop: int = 1   # Quantidade mínima de ouro
@export var max_gold_drop: int = 4  # Quantidade máxima de ouro
@export var min_lvl_item_drop: int = 1
@export var max_lvl_item_drop: int = 3

@export var separation_strength: float = 60.0 # Força com que os inimigos se repelem
@onready var separation_area: Area2D = $SeparationArea

var time_offset: float = 0.0

var current_health: float
var player_ref: Node2D = null

@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var health_bar: ProgressBar = $HealthBar

var is_dead: bool = false
var default_sprite_scale: Vector2 = Vector2.ONE
var default_modulate: Color = Color.WHITE
var hit_tween: Tween = null

var drop = preload("res://scenes/ui/item.tscn")
var items_can_drop = [2]
var chances_of_drop = [0.2]

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
		health_bar.top_level = true # Desacopla rotação e movimento do pai
		_update_healthbar_position()

	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	time_offset = randf_range(0.0, 100.0)
	move_speed *= randf_range(0.9, 1.1)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	_handle_ai_chase(delta)
	move_and_slide()
	# _check_body_collisions()
	_update_healthbar_position()
	
func _get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
		
	var push_vector = Vector2.ZERO
	var overlapping_areas = separation_area.get_overlapping_areas()
	
	for area in overlapping_areas:
		# Ignora a própria área
		if area != separation_area:
			var diff = global_position - area.global_position
			var distance = diff.length()
			if distance > 0.0:
				# Quanto mais perto estiverem, mais forte é o empurrão
				push_vector += diff.normalized() / maxf(distance, 1.0)
				
	return push_vector.normalized()

func _handle_ai_chase(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	# Direção frontal e direção lateral
	var forward_dir = to_player.normalized()
	var lateral_dir = Vector2(-forward_dir.y, forward_dir.x)

	# Calcula desvio senoidal
	var current_time = (Time.get_ticks_msec() / 1000.0) + time_offset
	var lateral_wobble = sin(current_time * wobble_frequency) * wobble_amplitude

	# Quando estiver muito perto do player, reduz o zigue-zague para focar no ataque
	if distance < 60.0:
		lateral_wobble *= (distance / 60.0)

	var final_move_dir = (forward_dir + lateral_dir * lateral_wobble).normalized()

	# Rotação alinhada à direção do movimento
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Aplica a velocidade
	if distance > 20.0:
		# Direção desejada para ir até o player
		var desired_velocity = final_move_dir * move_speed
		
		# Adiciona a repulsão para desviar de outros inimigos
		var separation = _get_separation_vector() * separation_strength
		desired_velocity += separation
		
		velocity = velocity.move_toward(desired_velocity, 500.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)

func _check_body_collisions() -> void:
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is Player:
			var push_dir = (collider.global_position - global_position).normalized()
			collider.take_damage(contact_damage, push_dir * 500.0)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, 30.0)
	
func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	play_hit_feedback(hit_type == HitReceiver.HitType.SHIELD)
	match hit_type:
		HitReceiver.HitType.SHIELD:
			# Se acertar o escudo, empurra menos
			AudioManager.play_sfx(AudioManager.SFX_SHIELD)
			velocity += direction * (impact_speed * 0.8 + 200.0)
		HitReceiver.HitType.WEAKSPOT, HitReceiver.HitType.NORMAL:
			AudioManager.play_sfx(AudioManager.SFX_HIT)
			current_health = maxf(0.0, current_health - damage)
			if health_bar:
				health_bar.value = current_health
			
			# Força proporcional à velocidade do impacto
			var knockback_force = impact_speed * knockback_multiplier
			if hit_type == HitReceiver.HitType.WEAKSPOT:
				# Ponto fraco recebe 30% a mais de empurrão
				knockback_force *= 1.3
			if current_health <= 0.0:
				# Impulso extra e violento na morte
				knockback_force *= 1.35
			
			velocity += direction * knockback_force
			
			if current_health <= 0.0:
				die()

func play_hit_feedback(is_shield: bool = false) -> void:
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
		
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		
	hit_tween = create_tween().set_parallel(true)
	
	# 1. Flash de Dano (Branco brilhante para carne, reflexo prateado para escudo)
	sprite.modulate = Color(1.8, 1.8, 2.2, 1.0) if is_shield else Color(2.5, 2.5, 2.5, 1.0)
	hit_tween.tween_property(sprite, "modulate", default_modulate, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Deformação Elástica (Squash & Stretch)
	var squashed = Vector2(default_sprite_scale.x * 0.8, default_sprite_scale.y * 1.3) if is_shield else Vector2(default_sprite_scale.x * 1.4, default_sprite_scale.y * 0.65)
	sprite.scale = squashed
	hit_tween.tween_property(sprite, "scale", default_sprite_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func create_item() -> void:
	var coin_amount = randi_range(min_gold_drop, max_gold_drop)
	var coin_drop = drop.instantiate()
	coin_drop.setup(100 + coin_amount, self.global_position)
	get_tree().current_scene.get_node("World/Arena").add_child(coin_drop)
	
	for idx in range(items_can_drop.size()):
		if randf() <= chances_of_drop[idx]:
			var idx_drop = drop.instantiate()
			var idx_lvl = randi_range(min_lvl_item_drop, max_lvl_item_drop)
			var offset = Vector2(randi_range(-5,5), randi_range(-5,5))
			idx_drop.setup(items_can_drop[idx]*100 + idx_lvl, self.global_position + offset)
			get_tree().current_scene.get_node("World/Arena").add_child(idx_drop)
			return

func _disable_all_collisions() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	velocity = Vector2.ZERO
	
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
			for subchild in child.get_children():
				if subchild is CollisionShape2D:
					subchild.set_deferred("disabled", true)
		elif child is Node2D:
			for subchild in child.get_children():
				if subchild is Area2D:
					subchild.set_deferred("monitoring", false)
					subchild.set_deferred("monitorable", false)
					for leaf in subchild.get_children():
						if leaf is CollisionShape2D:
							leaf.set_deferred("disabled", true)
				elif subchild is CollisionShape2D:
					subchild.set_deferred("disabled", true)

func die() -> void:
	# Se já morreu neste frame, não faz nada
	if is_dead: return 
	is_dead = true
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)
	call_deferred("create_item")
	enemy_died.emit()
	
	_disable_all_collisions()
	
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
