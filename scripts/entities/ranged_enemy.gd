class_name RangedEnemy
extends CharacterBody2D

signal enemy_died

@export_group("Atributos")
@export var max_health: float = 40.0
@export var move_speed: float = 120.0
@export var turn_speed: float = 4.0
@export var stop_distance: float = 250.0
@export var knockback_multiplier: float = 4.0

@export_group("Combate")
@export var bullet_scene: PackedScene # Arraste a cena do seu EnemyBullet aqui!
@export var min_shoot_interval: float = 1.2 # Tempo mínimo de espera entre tiros
@export var max_shoot_interval: float = 2.6 # Tempo máximo de espera entre tiros
@export var shoot_spread_degrees: float = 12.0

@export_group("Distâncias de Combate")
@export var retreat_distance: float = 170.0 # Se o player chegar mais perto que isso, ele recua
@export var strafe_speed_ratio: float = 0.75 # Velocidade enquanto circula

@export_group("Drops de Recompensa")
@export var min_gold_drop: int = 5
@export var max_gold_drop: int = 8

@export var separation_strength: float = 60.0 # Força com que os inimigos se repelem
@onready var separation_area: Area2D = $SeparationArea

var strafe_direction: float = 1.0
var strafe_change_timer: float = 0.0

var current_health: float
var player_ref: Node2D = null

@onready var health_bar: ProgressBar = $HealthBar
@onready var shoot_point: Marker2D = $ShootPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var hit_receivers_node: Node2D = $HitReceivers

var is_dead: bool = false
var default_sprite_scale: Vector2 = Vector2.ONE
var default_modulate: Color = Color.WHITE
var hit_tween: Tween = null

var drop = preload("res://scenes/ui/item.tscn")
var items_can_drop = [5, 7]
var chances_of_drop = [0.2, 0.1]

func _ready() -> void:
	add_to_group("enemies")
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		default_sprite_scale = sprite.scale
		default_modulate = sprite.modulate
	
	current_health = maxf(1.0, max_health)
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.top_level = true
		_update_healthbar_position()
		
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	# Inicia o primeiro tiro com tempo aleatório
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))
	
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	strafe_direction = 1.0 if randf() > 0.5 else -1.0
	strafe_change_timer = randf_range(1.5, 3.5)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	_handle_ai_combat(delta)
	move_and_slide()
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

func _handle_ai_combat(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = player_ref.global_position - global_position
	var distance = to_player.length()

	# Mira sempre no jogador
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)

	# Atualiza timer de troca de direção do strafe
	strafe_change_timer -= delta
	if strafe_change_timer <= 0.0:
		strafe_direction *= -1.0 # Inverte o sentido (horário / anti-horário)
		strafe_change_timer = randf_range(2.0, 4.0)

	var forward_dir = to_player.normalized()
	var lateral_dir = Vector2(-forward_dir.y, forward_dir.x) * strafe_direction

	var desired_velocity = Vector2.ZERO

	if distance > stop_distance:
		# Longe demais: avança em direção ao player, com leve desvio lateral
		var move_dir = (forward_dir + lateral_dir * 0.3).normalized()
		desired_velocity = move_dir * move_speed

	elif distance < retreat_distance:
		# Perto demais: recua e esquiva para o lado
		var retreat_dir = (-forward_dir + lateral_dir * 0.5).normalized()
		desired_velocity = retreat_dir * (move_speed * 1.1)

	else:
		# Na distância ideal: circunda o jogador lateralmente
		desired_velocity = lateral_dir * (move_speed * strafe_speed_ratio)

	# Adiciona a repulsão para desviar e não colidir com outros inimigos
	var separation = _get_separation_vector() * separation_strength
	desired_velocity += separation

	velocity = velocity.move_toward(desired_velocity, 450.0 * delta)

# --- SISTEMA DE TIRO ---

func _on_shoot_timer_timeout() -> void:
	# Só atira se o player existir e estiver dentro de uma distância razoável
	if is_instance_valid(player_ref) and (player_ref.global_position - global_position).length() < stop_distance + 500:
		shoot()
		
	# Sorteia um novo intervalo aleatório para o próximo disparo
	shoot_timer.start(randf_range(min_shoot_interval, max_shoot_interval))

func shoot() -> void:
	if bullet_scene == null or not is_instance_valid(player_ref):
		return
	
	AudioManager.play_sfx(AudioManager.SFX_SHOOT)
	var bullet = bullet_scene.instantiate() as Area2D
	
	# Calcula a direção em linha reta para o player
	var base_dir = (player_ref.global_position - shoot_point.global_position).normalized()
	
	# Sorteia uma variação de ângulo em radianos entre [-spread, +spread]
	var spread_rad = deg_to_rad(shoot_spread_degrees)
	var random_offset = randf_range(-spread_rad, spread_rad)
	
	# Aplica a rotação no vetor de direção
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
	
	for idx in range(items_can_drop.size()):
		if randf() <= chances_of_drop[idx]:
			var idx_drop = drop.instantiate()
			var idx_lvl = randi_range(1,3)
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
