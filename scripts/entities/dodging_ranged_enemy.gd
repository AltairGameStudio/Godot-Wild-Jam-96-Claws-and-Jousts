class_name DodgingRangedEnemy
extends CharacterBody2D

signal enemy_died

# --- SPRITES / ANIMAÇÃO DE PULO ---
@export_group("Sprites")
@export var sprite_idle: Texture2D = preload("res://assets/sprites/entities/enemy_jumpy_000.png")
@export var sprite_jumping: Texture2D = preload("res://assets/sprites/entities/enemy_jumpy_001.png")

@onready var enemy_sprite: Sprite2D = $Sprite2D
# ----------------------------------

@export_group("Atributos")
@export var max_health: float = 35.0
@export var move_speed: float = 95.0
@export var turn_speed: float = 4.5
@export var stop_distance: float = 260.0
@export var knockback_multiplier: float = 4.0

@export_group("Esquiva / Dash Reativo")
@export var dodge_trigger_distance: float = 220.0     # Distância em que percebe o ataque
@export var min_player_speed_trigger: float = 250.0   # Velocidade mínima do player para assustar
@export var dodge_speed: float = 580.0                # Força/velocidade do dash lateral
@export var dodge_duration: float = 0.25              # Duração do impulso em segundos
@export var dodge_cooldown_time: float = 3.0          # Tempo de recarga entre esquivas

@export_group("Combate")
@export var bullet_scene: PackedScene
@export var min_shoot_interval: float = 1.3
@export var max_shoot_interval: float = 2.5
@export var shoot_spread_degrees: float = 12.0

@export_group("Distâncias de Combate")
@export var retreat_distance: float = 160.0
@export var strafe_speed_ratio: float = 0.8
@export var separation_strength: float = 60.0

@export_group("Drops de Recompensa")
@export var min_gold_drop: int = 21
@export var max_gold_drop: int = 24
var items_can_drop = [5, 7]        # Tipos de itens que esse arqueiro pode dropar (ex: Rédea e Sela)
var chances_of_drop = [0.25, 0.15] # 25% de chance para o primeiro, 15% para o segundo

@onready var separation_area: Area2D = $SeparationArea
@onready var health_bar: ProgressBar = $HealthBar
@onready var shoot_point: Marker2D = $ShootPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var hit_receivers_node: Node2D = $HitReceivers

var current_health: float
var player_ref: Node2D = null
var is_dead: bool = false
var default_sprite_scale: Vector2 = Vector2.ONE
var default_modulate: Color = Color.WHITE
var hit_tween: Tween = null

var strafe_direction: float = 1.0
var strafe_change_timer: float = 0.0

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction_vec: Vector2 = Vector2.ZERO

var drop = preload("res://scenes/ui/item.tscn")

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if enemy_sprite:
		default_sprite_scale = enemy_sprite.scale
		default_modulate = enemy_sprite.modulate
		if sprite_idle:
			enemy_sprite.texture = sprite_idle
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true
		_update_healthbar_position()
		
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	strafe_direction = 1.0 if randf() > 0.5 else -1.0
	strafe_change_timer = randf_range(1.5, 3.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta

	if is_dodging:
		_process_dodge(delta)
	else:
		_check_dodge_trigger()
		_handle_ai_combat(delta)

	move_and_slide()
	_update_healthbar_position()

func _check_dodge_trigger() -> void:
	if dodge_cooldown > 0.0 or not is_instance_valid(player_ref):
		return
		
	var player_char = player_ref as CharacterBody2D
	if not player_char:
		return
		
	var to_enemy = global_position - player_ref.global_position
	var distance = to_enemy.length()
	
	if distance > dodge_trigger_distance:
		return
		
	var player_speed = player_char.velocity.length()
	if player_speed < min_player_speed_trigger:
		return
		
	var player_move_dir = player_char.velocity.normalized()
	var dir_to_enemy = to_enemy.normalized()
	var alignment = player_move_dir.dot(dir_to_enemy)
	
	if alignment > 0.65:
		_trigger_dodge(dir_to_enemy)

func _trigger_dodge(dir_from_player: Vector2) -> void:
	is_dodging = true
	AudioManager.play_sfx(AudioManager.SFX_DODGE)
	dodge_timer = dodge_duration
	dodge_cooldown = dodge_cooldown_time
	
	# Troca para o sprite de pulo durante o salto
	if enemy_sprite and sprite_jumping:
		enemy_sprite.texture = sprite_jumping
	
	var lateral_dir = Vector2(-dir_from_player.y, dir_from_player.x).normalized()
	var side = 1.0 if randf() > 0.5 else -1.0
	dodge_direction_vec = lateral_dir * side
	
	velocity = dodge_direction_vec * dodge_speed
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.4, 0.05)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	velocity = velocity.move_toward(dodge_direction_vec * (dodge_speed * 0.4), 800.0 * delta)
	
	if dodge_timer <= 0.0:
		is_dodging = false
		# Retorna ao sprite base ao aterrissar
		if enemy_sprite and sprite_idle:
			enemy_sprite.texture = sprite_idle

func _handle_ai_combat(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	strafe_change_timer -= delta
	if strafe_change_timer <= 0.0:
		strafe_direction *= -1.0
		strafe_change_timer = randf_range(2.0, 4.0)

	var forward_dir = to_player.normalized()
	var lateral_dir = Vector2(-forward_dir.y, forward_dir.x) * strafe_direction
	var desired_velocity = Vector2.ZERO

	if distance > stop_distance:
		var move_dir = (forward_dir + lateral_dir * 0.3).normalized()
		desired_velocity = move_dir * move_speed
	elif distance < retreat_distance:
		var retreat_dir = (-forward_dir + lateral_dir * 0.5).normalized()
		desired_velocity = retreat_dir * (move_speed * 1.1)
	else:
		desired_velocity = lateral_dir * (move_speed * strafe_speed_ratio)

	var separation = _get_separation_vector() * separation_strength
	desired_velocity += separation

	velocity = velocity.move_toward(desired_velocity, 450.0 * delta)

func _get_separation_vector() -> Vector2:
	if not separation_area:
		return Vector2.ZERO
		
	var push_vector = Vector2.ZERO
	for area in separation_area.get_overlapping_areas():
		if area != separation_area:
			var diff = global_position - area.global_position
			var distance = diff.length()
			if distance > 0.0:
				push_vector += diff.normalized() / maxf(distance, 1.0)
				
	return push_vector.normalized()

func _on_shoot_timer_timeout() -> void:
	if not is_dodging and is_instance_valid(player_ref) and (player_ref.global_position - global_position).length() < stop_distance + 500:
		shoot()
		
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))

func shoot() -> void:
	if bullet_scene == null or not is_instance_valid(player_ref):
		return
	
	AudioManager.play_sfx(AudioManager.SFX_SHOOT)
	var bullet = bullet_scene.instantiate() as Area2D
	var base_dir = (player_ref.global_position - shoot_point.global_position).normalized()
	
	var spread_rad = deg_to_rad(shoot_spread_degrees)
	var random_offset = randf_range(-spread_rad, spread_rad)
	
	bullet.direction = base_dir.rotated(random_offset)
	bullet.global_position = shoot_point.global_position
	
	get_tree().current_scene.add_child(bullet)

func _update_healthbar_position() -> void:
	if health_bar:
		health_bar.global_position = global_position + Vector2(-health_bar.size.x / 2.0, -30.0)

func create_item() -> void:
	var coin_amount = randi_range(min_gold_drop, max_gold_drop)
	var coin_drop = drop.instantiate()
	coin_drop.setup(100 + coin_amount, self.global_position)
	get_tree().current_scene.get_node("World/Arena").add_child(coin_drop)
	
	# Drop de Equipamento com chance e nível aleatório
	for idx in range(items_can_drop.size()):
		if randf() <= chances_of_drop[idx]:
			var idx_drop = drop.instantiate()
			var idx_lvl = randi_range(1, 5) # Nível aleatório entre 1 e 5
			var offset = Vector2(randi_range(-10, 10), randi_range(-10, 10))
			idx_drop.setup(items_can_drop[idx] * 100 + idx_lvl, self.global_position + offset)
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
		
	var sprite = enemy_sprite
	if sprite:
		var death_tween = create_tween().set_parallel(true)
		death_tween.tween_property(sprite, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(sprite, "scale", sprite.scale * 1.3, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.chain().tween_callback(queue_free)
	else:
		queue_free.call_deferred()

func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	play_hit_feedback(hit_type == HitReceiver.HitType.SHIELD)
	match hit_type:
		HitReceiver.HitType.SHIELD:
			velocity += direction * (impact_speed * 0.8 + 200.0)
		HitReceiver.HitType.WEAKSPOT, HitReceiver.HitType.NORMAL:
			AudioManager.play_sfx(AudioManager.SFX_HIT)
			current_health = maxf(0.0, current_health - damage)
			if health_bar:
				health_bar.value = current_health
				
				var knockback_force = impact_speed * knockback_multiplier
				if hit_type == HitReceiver.HitType.WEAKSPOT:
					knockback_force *= 1.3
				if current_health <= 0.0:
					knockback_force *= 1.35
				
				velocity += direction * knockback_force
				
				if current_health <= 0.0:
					die()

func play_hit_feedback(is_shield: bool = false) -> void:
	if not enemy_sprite:
		return
		
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		
	hit_tween = create_tween().set_parallel(true)
	
	enemy_sprite.modulate = Color(1.8, 1.8, 2.2, 1.0) if is_shield else Color(2.5, 2.5, 2.5, 1.0)
	hit_tween.tween_property(enemy_sprite, "modulate", default_modulate, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var squashed = Vector2(default_sprite_scale.x * 0.8, default_sprite_scale.y * 1.3) if is_shield else Vector2(default_sprite_scale.x * 1.4, default_sprite_scale.y * 0.65)
	enemy_sprite.scale = squashed
	hit_tween.tween_property(enemy_sprite, "scale", default_sprite_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
