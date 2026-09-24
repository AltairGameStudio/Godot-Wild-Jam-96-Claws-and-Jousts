class_name BossMole
extends CharacterBody2D

signal boss_spawned(boss_instance: Node2D)
signal health_changed(current_hp: float, max_hp: float)
signal boss_defeated

@export_group("Atributos do Chefe")
@export var boss_name: String = "Guardian Mole"
@export var max_health: float = 8000.0
@export var move_speed: float = 100.0
@export var turn_speed: float = 4.5
@export var contact_damage: float = 25.0
@export var knockback_multiplier: float = 0.5

@export_group("Mecânica de Escavação (Burrow)")
@export var burrow_cycle_time: float = 20.0 # Segundos entre cada enterro
@export var underground_time: float = 2.0   # Tempo que passa debaixo da terra

@export_group("Invocação de Minions")
@export var minion_spawn_interval: float = 8.0

@export_group("Fase 2 - Modo Fúria & Tiro Giratório")
@export var spin_duration: float = 5.0         # Duração do ataque giratório antes de cavar (5 segundos)
@export var spin_speed: float = 3.5            # Velocidade de rotação ao atirar (rad/s)
@export var shoot_bullet_interval: float = 0.08 # Intervalo de disparos em espiral
@export var bullet_damage: float = 8.0

@export_group("Drops")
@export var gold_drop_amount: int = 60

enum State { SURFACED, SPIN_ATTACK, BURROWING_DOWN, UNDERGROUND, BURROWING_UP, DEAD }
var current_state: State = State.SURFACED

var current_health: float
var player_ref: Node2D = null
var burrow_timer: float = 0.0
var minion_timer: float = 0.0

# Controle da Fase 2
var is_phase_2: bool = false
var spin_attack_timer: float = 0.0
var shoot_bullet_timer: float = 0.0

var default_sprite_scale: Vector2 = Vector2.ONE
var default_modulate: Color = Color.WHITE
var hit_tween: Tween = null
var is_invulnerable: bool = false

# Limites da Arena para se esconder
var arena_center: Vector2 = Vector2(895, 511)
var arena_radius: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_receivers_node: Node2D = $HitReceivers
@onready var physical_collision: CollisionShape2D = $CollisionShape2D
@onready var burrow_particles: CPUParticles2D = $BurrowParticles

const SCENE_SWORD = preload("res://scenes/entities/sword_enemy.tscn")
const SCENE_RANGED = preload("res://scenes/entities/ranged_enemy.tscn")
const SCENE_BULLET = preload("res://scenes/entities/enemy_bullet.tscn")
var drop_item_scene = preload("res://scenes/ui/item.tscn")

var minion_scene: PackedScene = SCENE_SWORD

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player") as Node2D
	minion_scene = SCENE_SWORD
	
	if sprite:
		default_sprite_scale = sprite.scale
		default_modulate = sprite.modulate
		sprite.flip_v = false
		sprite.flip_h = false
		
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is HitReceiver:
				child.hit_received.connect(_on_hit_received)
				
	burrow_timer = burrow_cycle_time
	minion_timer = minion_spawn_interval
	
	# Pega o centro da arena se disponível
	var ring = get_tree().current_scene.get_node_or_null("ForestRing")
	if ring:
		arena_center = ring.global_position
		arena_radius = ring.radius - 250.0
		
	# Emite sinal de surgimento
	boss_spawned.emit(self)
	health_changed.emit(current_health, max_health)

var is_intro_mode: bool = false

func set_intro_mode(active: bool) -> void:
	is_intro_mode = active
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_intro_mode or current_state == State.DEAD:
		velocity = Vector2.ZERO
		return
		
	if current_state == State.SURFACED:
		_handle_movement_and_facing(delta)
		_process_timers(delta)
		move_and_slide()
	elif current_state == State.SPIN_ATTACK:
		_handle_spin_attack(delta)
		move_and_slide()

func _process_timers(delta: float) -> void:
	# 1. Timer de Invocação de Minions
	minion_timer -= delta
	if minion_timer <= 0.0:
		_spawn_minions()
		minion_timer = minion_spawn_interval
		
	# 2. Timer de Escavação / Ataque Especial
	burrow_timer -= delta
	if burrow_timer <= 0.0:
		if is_phase_2:
			# Na Fase 2: antes de entrar no chão, gira atirando por 5 segundos
			start_spin_attack()
		else:
			start_burrow()

func _handle_movement_and_facing(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return
		
	var to_player = player_ref.global_position - global_position
	var dist = to_player.length()
	
	# Rotação suave olhando diretamente para o jogador.
	# Como o sprite tem o focinho virado para BAIXO (+Y), o ângulo base é to_player.angle() - (PI / 2.0)
	var target_angle = to_player.angle() - (PI / 2.0)
	rotation = rotate_toward(rotation, target_angle, turn_speed * delta)
	
	if sprite:
		sprite.flip_v = false
		sprite.flip_h = false
	
	# Movimento contínuo em perseguição pesada
	if dist > 35.0:
		var desired_velocity = to_player.normalized() * move_speed
		velocity = velocity.move_toward(desired_velocity, 250.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)

# --- ATAQUE GIRATÓRIO DA FASE 2 ---

func start_spin_attack() -> void:
	if current_state != State.SURFACED:
		return
		
	current_state = State.SPIN_ATTACK
	spin_attack_timer = spin_duration
	shoot_bullet_timer = 0.0
	velocity = Vector2.ZERO
	
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)
	if is_instance_valid(player_ref) and player_ref.has_method("apply_camera_shake"):
		player_ref.apply_camera_shake(0.35)

func _handle_spin_attack(delta: float) -> void:
	spin_attack_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
	
	# Giro contínuo rápido
	rotation += spin_speed * delta
	
	# Disparos periódicos de projéteis em espiral saindo do focinho
	shoot_bullet_timer -= delta
	if shoot_bullet_timer <= 0.0:
		_fire_spin_bullet()
		shoot_bullet_timer = shoot_bullet_interval
		
	# Ao terminar os 5 segundos girando e atirando, entra no chão
	if spin_attack_timer <= 0.0:
		start_burrow()

func _fire_spin_bullet() -> void:
	if not SCENE_BULLET:
		return
		
	var front_dir = Vector2.DOWN.rotated(rotation)
	var back_dir = -front_dir
	
	_spawn_single_bullet(front_dir)
	_spawn_single_bullet(back_dir)
	
	# Som de metralhadora com volume bem reduzido (-14.0 dB) e variação sutil de pitch
	AudioManager.play_sfx(AudioManager.SFX_SHOOT, -14.0, 0.18)

func _spawn_single_bullet(shoot_dir: Vector2) -> void:
	var bullet = SCENE_BULLET.instantiate() as Area2D
	if "direction" in bullet:
		bullet.direction = shoot_dir
	if "shooter_name" in bullet:
		bullet.shooter_name = boss_name
	if "damage" in bullet:
		bullet.damage = bullet_damage
		
	bullet.global_position = global_position + shoot_dir * 55.0
	
	if get_parent():
		get_parent().add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)

# --- MECÂNICA DE ESCAVAÇÃO (BURROW) ---

func start_burrow() -> void:
	if current_state != State.SURFACED and current_state != State.SPIN_ATTACK:
		return
		
	current_state = State.BURROWING_DOWN
	is_invulnerable = true
	velocity = Vector2.ZERO
	
	# Desativa colisões para não tomar nem causar dano
	_set_collisions_active(false)
	
	if burrow_particles:
		burrow_particles.restart()
		burrow_particles.emitting = true
		
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)
	
	# Tween de descida: encolhe e afunda na terra
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.05, 0.05), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	current_state = State.UNDERGROUND
	
	# Aguarda debaixo da terra
	await get_tree().create_timer(underground_time).timeout
	
	if current_state == State.DEAD:
		return
		
	# Escolhe nova posição na arena, distante do player
	_relocate_underground()
	
	# Emerge da terra
	_emerge_from_ground()

func _relocate_underground() -> void:
	var attempts = 0
	var new_pos = arena_center
	
	while attempts < 15:
		var angle = randf() * TAU
		var dist = sqrt(randf()) * arena_radius
		new_pos = arena_center + Vector2(cos(angle), sin(angle)) * dist
		
		if is_instance_valid(player_ref):
			if new_pos.distance_to(player_ref.global_position) >= 280.0:
				break
		attempts += 1
		
	global_position = new_pos

func _emerge_from_ground() -> void:
	current_state = State.BURROWING_UP
	
	if burrow_particles:
		burrow_particles.restart()
		burrow_particles.emitting = true
		
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)
	
	# Tremor de câmera para indicar a emergência
	if is_instance_valid(player_ref) and player_ref.has_method("apply_camera_shake"):
		player_ref.apply_camera_shake(0.5)
		
	# Tween de subida: brota do chão com salto elástico
	var tween = create_tween()
	tween.tween_property(sprite, "scale", default_sprite_scale, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.4)
	
	await tween.finished
	
	# Reativa colisões e volta ao estado normal
	_set_collisions_active(true)
	is_invulnerable = false
	current_state = State.SURFACED
	burrow_timer = burrow_cycle_time

func _set_collisions_active(active: bool) -> void:
	if physical_collision:
		physical_collision.set_deferred("disabled", !active)
		
	if hit_receivers_node:
		for child in hit_receivers_node.get_children():
			if child is Area2D:
				child.set_deferred("monitoring", active)
				child.set_deferred("monitorable", active)

func _spawn_minions() -> void:
	if minion_scene == null:
		return
		
	if burrow_particles:
		burrow_particles.restart()
		burrow_particles.emitting = true
		
	var minion_count = randi_range(3, 5)
	for i in range(minion_count):
		var angle = (TAU / minion_count) * i + randf_range(-0.25, 0.25)
		var spawn_offset = Vector2.RIGHT.rotated(angle) * randf_range(110.0, 160.0)
		var minion = minion_scene.instantiate() as Node2D
		
		get_parent().add_child(minion)
		minion.global_position = global_position + spawn_offset
		
		# Feedback visual de nascimento dos minions
		var m_sprite = minion.get_node_or_null("Sprite2D")
		if m_sprite:
			var orig_scale = m_sprite.scale
			m_sprite.scale = Vector2(0.1, 0.1)
			var tw = minion.create_tween()
			tw.tween_property(m_sprite, "scale", orig_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- REAÇÃO A DANO E TRANSIÇÃO DE FASE ---

func _on_hit_received(damage: float, direction: Vector2, hit_type: HitReceiver.HitType, impact_speed: float = 0.0) -> void:
	if is_invulnerable or (current_state != State.SURFACED and current_state != State.SPIN_ATTACK):
		return
		
	play_hit_feedback(hit_type == HitReceiver.HitType.SHIELD)
	AudioManager.play_sfx(AudioManager.SFX_HIT)
	
	current_health = maxf(0.0, current_health - damage)
	health_changed.emit(current_health, max_health)
	
	# Empurrão moderado (o boss é pesado)
	var knockback_force = impact_speed * knockback_multiplier
	if hit_type == HitReceiver.HitType.WEAKSPOT:
		knockback_force *= 1.3
		
	velocity += direction * knockback_force
	
	# Transição para a Fase 2 (50% de HP)
	if not is_phase_2 and current_health <= (max_health * 0.5):
		_enter_phase_2()
	
	if current_health <= 0.0:
		die()

func _enter_phase_2() -> void:
	is_phase_2 = true
	# Troca os lacaios futuros de SwordEnemy para RangedEnemy
	minion_scene = SCENE_RANGED
	
	# Tom avermelhado de fúria permanente
	default_modulate = Color(1.0, 0.78, 0.78)
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(3.0, 0.5, 0.5), 0.25)
		tween.tween_property(sprite, "modulate", default_modulate, 0.35)
		
	if is_instance_valid(player_ref) and player_ref.has_method("apply_camera_shake"):
		player_ref.apply_camera_shake(0.85)
		
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)

func play_hit_feedback(is_shield: bool = false) -> void:
	if not sprite:
		return
		
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		
	hit_tween = create_tween().set_parallel(true)
	
	sprite.modulate = Color(1.8, 1.8, 2.2, 1.0) if is_shield else Color(2.5, 2.5, 2.5, 1.0)
	hit_tween.tween_property(sprite, "modulate", default_modulate, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var squashed = Vector2(default_sprite_scale.x * 1.35, default_sprite_scale.y * 0.7)
	sprite.scale = squashed
	hit_tween.tween_property(sprite, "scale", default_sprite_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func die() -> void:
	if current_state == State.DEAD:
		return
		
	current_state = State.DEAD
	is_invulnerable = true
	velocity = Vector2.ZERO
	_set_collisions_active(false)
	
	# Trava o jogador para assistir ao espetáculo da vitória
	if is_instance_valid(player_ref):
		player_ref.can_move = false
		player_ref.velocity = Vector2.ZERO
		if player_ref.has_method("apply_camera_shake"):
			player_ref.apply_camera_shake(1.0)
		if player_ref.has_method("trigger_hit_stop"):
			player_ref.trigger_hit_stop(0.18, 0.08)
	
	AudioManager.play_sfx(AudioManager.SFX_IMPACT)
	boss_defeated.emit()
	
	# Drop abundante de recompensas e chuva de confetes festivos
	call_deferred("_drop_boss_rewards")
	call_deferred("_spawn_confetti")
	
	# Explosão demorada e dramática
	if burrow_particles:
		burrow_particles.amount = 45
		burrow_particles.restart()
		burrow_particles.emitting = true
		
	var tween = create_tween()
	# Expande com vibração e clarão intenso
	tween.tween_property(sprite, "modulate", Color(4.0, 4.0, 4.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", default_sprite_scale * 1.45, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Colapso épico e dissolução gradual
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.75)
	
	await tween.finished
	queue_free()

func _spawn_confetti() -> void:
	var confetti = CPUParticles2D.new()
	confetti.emitting = true
	confetti.one_shot = true
	confetti.explosiveness = 0.85
	confetti.amount = 75
	confetti.lifetime = 3.0
	confetti.spread = 180.0
	confetti.gravity = Vector2(0, 110)
	confetti.initial_velocity_min = 140.0
	confetti.initial_velocity_max = 320.0
	confetti.scale_amount_min = 6.0
	confetti.scale_amount_max = 10.0
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.85, 0.2),  # Dourado
		Color(0.2, 0.9, 0.4),   # Esmeralda
		Color(0.95, 0.25, 0.3), # Rubi
		Color(0.3, 0.7, 1.0)    # Celeste
	])
	confetti.color_ramp = gradient
	confetti.global_position = global_position
	if get_parent():
		get_parent().add_child(confetti)
	else:
		get_tree().current_scene.add_child(confetti)

func _drop_boss_rewards() -> void:
	if not is_instance_valid(drop_item_scene):
		return
		
	# Moedas em círculo
	for i in range(5):
		var coin = drop_item_scene.instantiate()
		var offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(15.0, 45.0)
		coin.setup(100 + int(gold_drop_amount / 5), global_position + offset)
		get_parent().add_child(coin)
		
	# Drop de item de equipamento de alto nível
	var equip_drop = drop_item_scene.instantiate()
	var random_equip = randi_range(2, 7)
	equip_drop.setup(random_equip * 100 + randi_range(3, 5), global_position)
	get_parent().add_child(equip_drop)
