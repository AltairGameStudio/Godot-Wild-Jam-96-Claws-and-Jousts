class_name TarEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 50.0
@export var wander_speed: float = 80.0
@export var flee_speed: float = 140.0
@export var turn_speed: float = 4.0
@export var flee_distance: float = 260.0 # Distância na qual começa a fugir do player
@export var knockback_multiplier: float = 4.0

@export_group("Rastro de Piche")
@export var tar_puddle_scene: PackedScene
@export var puddle_drop_interval_flee: float = 0.25  # Solta mais rápido ao fugir
@export var puddle_drop_interval_wander: float = 0.8 # Solta mais espaçado ao vagar

@export_group("Comportamento")
@export var separation_strength: float = 50.0
@onready var separation_area: Area2D = $SeparationArea
@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var health_bar: ProgressBar = $HealthBar

@export_group("Drops de Recompensa")
@export var min_gold_drop: int = 13
@export var max_gold_drop: int = 16

var current_health: float
var player_ref: Node2D = null
var is_dead: bool = false
var default_sprite_scale: Vector2 = Vector2.ONE
var default_modulate: Color = Color.WHITE
var hit_tween: Tween = null

var drop = preload("res://scenes/ui/item.tscn")
var items_can_drop = [6]
var chances_of_drop = [0.2]

# Controle de movimentação aleatória
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

# Controle do rastro de piche
var drop_timer: float = 0.0
var is_fleeing: bool = false

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
				
	_pick_new_wander_direction()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	_handle_ai(delta)
	_handle_tar_drop(delta)
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

func _handle_ai(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance_to_player = to_player.length()
	
	var desired_move_dir = Vector2.ZERO
	var current_move_speed = wander_speed

	if distance_to_player < flee_distance:
		# --- ESTADO: FUGINDO ---
		is_fleeing = true
		# Corre na direção contrária ao player
		desired_move_dir = -to_player.normalized()
		current_move_speed = flee_speed
	else:
		# --- ESTADO: VAGANDO ---
		is_fleeing = false
		wander_timer -= delta
		if wander_timer <= 0.0:
			_pick_new_wander_direction()
		desired_move_dir = wander_direction
		current_move_speed = wander_speed

	# Rotação suave na direção em que está correndo
	if desired_move_dir.length_squared() > 0.01:
		var target_angle = desired_move_dir.angle() - (PI / 2.0)
		rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Aplica velocidade e separação de outros inimigos
	var desired_velocity = desired_move_dir * current_move_speed
	var separation = _get_separation_vector() * separation_strength
	desired_velocity += separation

	velocity = velocity.move_toward(desired_velocity, 400.0 * delta)

func _pick_new_wander_direction() -> void:
	# Escolhe um ângulo aleatório para andar
	var random_angle = randf_range(0.0, TAU)
	wander_direction = Vector2(cos(random_angle), sin(random_angle)).normalized()
	wander_timer = randf_range(1.5, 3.5)

func _handle_tar_drop(delta: float) -> void:
	if tar_puddle_scene == null:
		return

	drop_timer -= delta
	if drop_timer <= 0.0:
		_spawn_puddle()
		var current_interval = puddle_drop_interval_flee if is_fleeing else puddle_drop_interval_wander
		drop_timer = current_interval

func _spawn_puddle() -> void:
	var puddle = tar_puddle_scene.instantiate() as Node2D
	# Posiciona ligeiramente atrás do inimigo de acordo com a rotação
	var backward_offset = -Vector2.DOWN.rotated(rotation) * 12.0
	puddle.global_position = global_position + backward_offset
	
	# Adiciona à cena principal para que a poça fique estática no mundo
	get_tree().current_scene.add_child(puddle)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, -30.0)

func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	play_hit_feedback(hit_type == HitReceiver.HitType.SHIELD)
	current_health = maxf(0.0, current_health - damage)
	AudioManager.play_sfx(AudioManager.SFX_HIT)
	if health_bar:
		health_bar.value = current_health
	
	var knockback_force = impact_speed * knockback_multiplier
	if current_health <= 0.0:
		knockback_force *= 1.35
	velocity += direction * knockback_force
	
	# Ao tomar dano, assusta e força fugir imediatamente
	is_fleeing = true
	drop_timer = 0.0
	
	if current_health <= 0.0:
		die()

func play_hit_feedback(is_shield: bool = false) -> void:
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
		
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		
	hit_tween = create_tween().set_parallel(true)
	
	sprite.modulate = Color(1.8, 1.8, 2.2, 1.0) if is_shield else Color(2.5, 2.5, 2.5, 1.0)
	hit_tween.tween_property(sprite, "modulate", default_modulate, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
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
