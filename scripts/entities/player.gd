class_name Player
extends CharacterBody2D

signal health_changed(current: float, max_h: float)
signal power_charge_changed(current_load: float, on_load: bool)
signal player_died(killer_name: String, final_level: int, gold_collected: int)

@export_group("Vida")
@export var max_health: float = 100.0
var current_health: float

@export_group("Movimento")
@export var engine_power: float = 200.0
@export var max_speed: float = 600.0
@export var steer_speed: float = 2.0
@export var forward_friction: float = 0.98
@export var drift_traction: float = 0.85

@export_group("Combate")
@export var min_charge_speed: float = 100.0
#@export var base_damage: float = 10.0
@export var base_damage: float = 30.0
@export var damage_velocity_scale: float = 0.01
@export var bounce_force: float = 120.0  # Força fixa do recuo para trás

@export_group("Defesa e Invulnerabilidade")
@export var invulnerability_duration: float = 0.6
var is_invulnerable: bool = false

@export_group("Equipáveis")
@export var extra_damage = 0
@export var extra_health = 0
@export var defense = 0
@export var extra_speed = 0
@export var extra_steer_speed = 0
@export var extra_speed_multiplier = 0

@export_group("Habilidade Dash / Carga")
@export var charge_time_to_fill: float = 3.0   # Tempo em segundos para encher a barra de 0% a 100%
@export var dash_duration: float = 1.5         # Tempo em segundos que o Dash dura até a barra esvaziar
@export var power_charge_load: float = 0.0
@export var on_power_charge: bool = false
@export var min_dash_charge_speed: float = 285.0

@onready var lance_pivot: Node2D = $LancePivot
@onready var lance_area: Area2D = $LancePivot/LanceArea
@onready var hurtbox_area: Area2D = $HurtboxArea
@onready var camera: Camera2D = $Camera2D

@onready var lance_light: PointLight2D = get_node_or_null("LancePivot/LanceArea/LanceLight")
@onready var central_light: PointLight2D = get_node_or_null("PointLight2D")
@onready var impact_particles: CPUParticles2D = get_node_or_null("LancePivot/LanceArea/ImpactParticles")
@onready var drift_particles: CPUParticles2D = get_node_or_null("DriftParticles")
@onready var speed_particles: CPUParticles2D = get_node_or_null("SpeedParticles")

var hit_cooldowns: Dictionary = {}
var recently_hit_enemies: Dictionary = {}
var last_damager_name: String = "Unknown Enemy"
var camera_cinematic_offset: Vector2 = Vector2.ZERO

@export_group("Câmera e Efeitos")
@export var base_camera_zoom: float = 1.10
@export var min_camera_zoom: float = 0.88
@export var zoom_lerp_speed: float = 2.5
@export var max_shake_offset: float = 18.0
var camera_trauma: float = 0.0
var camera_shake_decay: float = 2.8

var heading_angle: float = 0.0

# Controle de efeitos de lentidão
var speed_multiplier: float = 1.0
var active_slow_sources: int = 0

var can_move: bool = true

# Efeito visual de velocidade
var ghost_intervals: float = 0.3
var last_ghost : float = 0.0

var current_dash_speed: float = 0.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health + extra_health
	heading_angle = rotation
	
	if lance_area:
		lance_area.area_entered.connect(_on_lance_hit)
	
	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)
	update_info()

func create_ghost() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = $Sprite2D.texture
	get_tree().current_scene.add_child(ghost)
	var tween = create_tween()
	tween.tween_property(ghost, "self_modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(ghost.queue_free)
	ghost.global_transform = $Sprite2D.global_transform

func update_info() -> void:
	$PlayerCanvas/inventory/info.update_labels(
		[max_health + extra_health,
		 current_health,
		 base_damage + extra_damage,
		 defense,
		 max_speed + extra_speed,
		 speed_multiplier + extra_speed_multiplier,
		 steer_speed + extra_steer_speed,
		 drift_traction,
		 engine_power])
	$PlayerCanvas/equipment/coin/quantity.text = "%d" % get_tree().current_scene.gold

func equipment_changed(item_id, item_equipped: bool):
	var lvl : float = item_id%100
	var is_legend : bool = (int(lvl) == 11)
	var controler = -1
	var mod_color = Color(1,1,1,0.5)
	var equip_txt = ""
	if item_equipped: 
		controler = 1
		mod_color = Color(0.65, 1.3, 0.85) if is_legend else Color(1,1,1,1)
		equip_txt = "Legend" if is_legend else ("Lvl %d" % lvl)
		
	var it_type = int(item_id/100)
	if it_type == 2:
		var bonus_dmg = 50.0 if is_legend else (lvl * 2.0)
		extra_damage += controler * bonus_dmg
		$PlayerCanvas/equipment/lance.modulate = mod_color
		$PlayerCanvas/equipment/lance/lvl.text = equip_txt
	elif it_type == 3:
		var bonus_def = 50.0 if is_legend else (lvl * 3.0)
		defense += controler * bonus_def
		$PlayerCanvas/equipment/armor.modulate = mod_color
		$PlayerCanvas/equipment/armor/lvl.text = equip_txt
	elif it_type == 4:
		var health_bonus = 250.0 if is_legend else (lvl * 10.0)
		if item_equipped:
			# Ao equipar: aumenta a vida extra e soma a mesma quantidade na vida atual
			extra_health += health_bonus
			current_health += health_bonus
		else:
			# Ao desequipar: remove a vida extra e reduz a vida atual (garantindo que não passe do novo máximo)
			extra_health -= health_bonus
			current_health = minf(current_health, max_health + extra_health)
			
		$PlayerCanvas/equipment/cape.modulate = mod_color
		$PlayerCanvas/equipment/cape/lvl.text = equip_txt
	elif it_type == 5:
		var bonus_steer = 4.0 if is_legend else (lvl / 5.0)
		extra_steer_speed += controler * bonus_steer
		$PlayerCanvas/equipment/rein.modulate = mod_color
		$PlayerCanvas/equipment/rein/lvl.text = equip_txt
	elif it_type == 6:
		var bonus_spd_mult = 2.0 if is_legend else (lvl / 10.0)
		extra_speed_multiplier += controler * bonus_spd_mult
		$PlayerCanvas/equipment/horseshoe.modulate = mod_color
		$PlayerCanvas/equipment/horseshoe/lvl.text = equip_txt
	elif it_type == 7:
		var bonus_max_spd = 1000.0 if is_legend else (lvl * 50.0)
		extra_speed += controler * bonus_max_spd
		$PlayerCanvas/equipment/saddle.modulate = mod_color
		$PlayerCanvas/equipment/saddle/lvl.text = equip_txt
	
	# Notifica a barra de vida do HUD para redesenhar com a nova vida máxima e atual
	health_changed.emit(current_health, max_health + extra_health)
	
	update_info()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
	
	# Ignora dano de contato de inimigo que acabamos de atingir com a lança
	var enemy_owner = area.owner if area.owner else area.get_parent()
	if enemy_owner and recently_hit_enemies.has(enemy_owner):
		return
	
	# Captura o nome de quem causou o dano
	var damager = "Enemy"
	if enemy_owner:
		if "boss_name" in enemy_owner and enemy_owner.boss_name != "":
			damager = enemy_owner.boss_name
		elif "enemy_name" in enemy_owner and enemy_owner.enemy_name != "":
			damager = enemy_owner.enemy_name
		elif enemy_owner is SwordEnemy:
			damager = "Shadow Swordsman"
		elif enemy_owner is HeavyEnemy:
			damager = "Heavy Knight"
		elif enemy_owner is RangedEnemy:
			damager = "Swamp Archer"
		elif enemy_owner is DodgingRangedEnemy:
			damager = "Elusive Archer"
		elif enemy_owner is TarEnemy:
			damager = "Corrosive Slime"
		elif enemy_owner.name != "":
			damager = enemy_owner.name
	elif area.name != "":
		damager = area.name
		
	last_damager_name = damager
	
	# Aceita tanto EnemyHitbox quanto classes genéricas de Hitbox
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"], payload["knockback"], false, damager)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, ignore_charge: bool = false, damager_name: String = "") -> void:
	# Invulnerável se estiver piscando ou em pleno Dash
	if is_invulnerable or on_power_charge:
		return
		
	if damager_name != "":
		last_damager_name = damager_name
		
	# Se estiver em investida rápida frontal, a lança anula o dano de frente
	if not ignore_charge:
		var forward_vec = Vector2.UP.rotated(heading_angle)
		var is_charging = velocity.length() >= min_charge_speed and velocity.normalized().dot(forward_vec) > 0.5
		if is_charging:
			return
		
	current_health = maxf(0.0, current_health - (amount * (1.0 - defense / 100.0)))
	velocity += knockback
	health_changed.emit(current_health, max_health + extra_health)
	AudioManager.play_sfx(AudioManager.SFX_HURT)
	apply_camera_shake(0.45)
	_trigger_damage_squash()
	_trigger_invulnerability()
	update_info()
	if current_health <= 0.0:
		die()

func _trigger_damage_squash() -> void:
	var spr = get_node_or_null("Sprite2D")
	if not spr:
		return
	var base_scale = Vector2.ONE
	var tween = create_tween()
	tween.tween_property(spr, "scale", Vector2(base_scale.x * 1.3, base_scale.y * 0.7), 0.05)
	tween.tween_property(spr, "scale", base_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
func heal(amount: float) -> void:
	var total_max = max_health + extra_health
	current_health = minf(total_max, current_health + amount)
	health_changed.emit(current_health, total_max)
	update_info()

func _trigger_invulnerability() -> void:
	is_invulnerable = true
	var tween = create_tween().set_loops(int(invulnerability_duration / 0.1))
	tween.tween_property(self, "modulate:a", 0.2, 0.05)
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	
	await get_tree().create_timer(invulnerability_duration).timeout
	is_invulnerable = false
	modulate.a = 1.0
	
	_check_overlapping_hitboxes()

func _update_hit_cooldowns(delta: float) -> void:
	for area in hit_cooldowns.keys():
		if not is_instance_valid(area):
			hit_cooldowns.erase(area)
		else:
			hit_cooldowns[area] -= delta
			if hit_cooldowns[area] <= 0.0:
				hit_cooldowns.erase(area)
			
	for target in recently_hit_enemies.keys():
		if not is_instance_valid(target):
			recently_hit_enemies.erase(target)
		else:
			recently_hit_enemies[target] -= delta
			if recently_hit_enemies[target] <= 0.0:
				recently_hit_enemies.erase(target)

func _physics_process(delta: float) -> void:
	_update_hit_cooldowns(delta)
	
	if Input.is_key_pressed(KEY_SHIFT):
		if not on_power_charge and power_charge_load >= 1.0:
			on_power_charge = true
			var forward_vec = Vector2.UP.rotated(heading_angle)
			
			# Calcula a velocidade fixa do dash baseada na velocidade atual multiplicada (ex: 1.7x)
			var base_spd = maxf(velocity.length(), min_charge_speed)
			current_dash_speed = base_spd * 1.7
			
			# Aplica o vetor de velocidade instantâneo
			velocity = forward_vec * current_dash_speed
			apply_camera_shake(0.35)
			
			power_charge_changed.emit(power_charge_load, on_power_charge)
	
	_handle_movement(delta)
	var is_charging = lance_area.monitoring
	_update_lance_state()
	_update_visual_effects(delta)
	_update_camera(delta)
	
	if !is_charging and lance_area.monitoring:
		var tween = create_tween()
		tween.tween_property(lance_area, "modulate", Color(1,0,0,0.6), 0.2)
	elif is_charging and !lance_area.monitoring:
		var tween = create_tween()
		tween.tween_property(lance_area, "modulate", Color(1,1,1,1), 0.2)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return
	
	var turn_input = Input.get_axis("ui_left", "ui_right")
	var throttle_input = Input.get_axis("ui_down", "ui_up")
	
	heading_angle += turn_input * (steer_speed + extra_steer_speed) * delta
	rotation = heading_angle
	
	var forward_vec = Vector2.UP.rotated(heading_angle)
	var right_vec = Vector2.RIGHT.rotated(heading_angle)
	
	if on_power_charge:
		# Durante o Dash: Mantém a velocidade fixa na direção que você estiver virando
		velocity = forward_vec * current_dash_speed
	else:
		# Fora do Dash: Física normal de aceleração e atrito
		var effective_power = engine_power * (speed_multiplier + extra_speed_multiplier)
		var effective_max_speed = (max_speed + extra_speed) * (speed_multiplier + extra_speed_multiplier)
		
		if throttle_input > 0.0:
			velocity += forward_vec * effective_power * throttle_input * delta
		elif throttle_input < 0.0:
			velocity += forward_vec * (effective_power * 0.4) * throttle_input * delta
		
		var forward_velocity = forward_vec * velocity.dot(forward_vec)
		var lateral_velocity = right_vec * velocity.dot(right_vec)
		
		lateral_velocity *= pow(1.0 - drift_traction, delta)
		forward_velocity *= pow(forward_friction, delta)
		
		velocity = forward_velocity + lateral_velocity
		
		if velocity.length() > effective_max_speed:
			velocity = velocity.normalized() * effective_max_speed
	
	if get_tree().current_scene.is_in_run:
		if ((velocity.length() >= min_dash_charge_speed) and not on_power_charge):
			# Enche proporcionalmente ao tempo definido em charge_time_to_fill
			var fill_rate = delta / maxf(0.5, charge_time_to_fill) # Evita divisão por zero ou tempo negativo
			power_charge_load = min(power_charge_load + fill_rate, 1.0)
			power_charge_changed.emit(power_charge_load, on_power_charge)

		elif on_power_charge:
			if last_ghost >= ghost_intervals:
				create_ghost()
				last_ghost = 0.0
			else:
				last_ghost += delta

			# Esvazia proporcionalmente ao tempo definido em dash_duration
			var drain_rate = delta / maxf(0.01, dash_duration)
			power_charge_load = max(power_charge_load - drain_rate, 0.0)
			power_charge_changed.emit(power_charge_load, on_power_charge)
			
			if power_charge_load <= 0.0:
				on_power_charge = false

func _update_lance_state() -> void:
	if not lance_area:
		return
		
	var is_charging = velocity.length() >= min_charge_speed
	lance_area.monitoring = is_charging
	
	# Garante impacto mesmo se já estiver colidindo ao atingir a velocidade
	if is_charging:
		for area in lance_area.get_overlapping_areas():
			_on_lance_hit(area)

func _on_lance_hit(area: Area2D) -> void:
	if not area is HitReceiver:
		return
		
	# Evita acertos duplicados sucessivos na mesma área no mesmo ataque
	if hit_cooldowns.has(area):
		return
		
	var current_speed = velocity.length()
	var forward_vec = Vector2.UP.rotated(heading_angle)
	var forward_alignment = velocity.normalized().dot(forward_vec) if current_speed > 1.0 else 0.0
	
	var hit_enemy = area.owner
	
	# Se colidir com o Boss sem velocidade de carga ou sem alinhamento frontal:
	# O Boss repele o cavaleiro com um forte recuo para trás e dano de impacto
	if hit_enemy and hit_enemy is BossMole:
		if current_speed < min_charge_speed or forward_alignment < 0.35:
			hit_cooldowns[area] = 0.45
			var bounce_away_dir = (global_position - hit_enemy.global_position).normalized()
			if bounce_away_dir == Vector2.ZERO:
				bounce_away_dir = -forward_vec
			take_damage(18.0, bounce_away_dir * 550.0, true, hit_enemy.boss_name)
			apply_camera_shake(0.55)
			AudioManager.play_sfx(AudioManager.SFX_SHIELD)
			return
		
	if current_speed < min_charge_speed:
		return
		
	# Validação direcional com margem flexível para drifts angulados
	if forward_alignment < 0.35:
		return
		
	hit_cooldowns[area] = 0.25
		
	var effective_forward_speed = maxf(0.0, velocity.dot(forward_vec))
	var excess_speed = maxf(0.0, effective_forward_speed - min_charge_speed)
	var raw_damage = base_damage + (excess_speed * damage_velocity_scale)
	
	var receiver = area as HitReceiver
	# Enviamos o dano, a direção e a velocidade atual do impacto
	var hit_data = receiver.process_hit(raw_damage + extra_damage, velocity.normalized(), current_speed)
	
	var hit_type = hit_data.get("hit_type", HitReceiver.HitType.NORMAL)
	var is_killed = hit_data.get("killed", false)
	var target_enemy = hit_data.get("target")
	
	if target_enemy:
		# Imunidade de contato transitória (0.3s) para atravessar o corpo do inimigo atingido
		recently_hit_enemies[target_enemy] = 0.3
	
	# 1. Camera Shake proporcional ao impacto
	var shake_val = clampf((current_speed / maxf(1.0, max_speed)) * 0.5 + 0.25, 0.25, 0.85)
	if hit_type == HitReceiver.HitType.SHIELD:
		shake_val = minf(1.0, shake_val + 0.25)
	apply_camera_shake(shake_val)
	
	# 2. Hit-Stop (Micro-freeze de impacto)
	var stop_time = 0.05
	if on_power_charge or is_killed:
		stop_time = 0.08
	elif hit_type == HitReceiver.HitType.SHIELD:
		stop_time = 0.06
	trigger_hit_stop(stop_time, 0.05)
	
	# 3. Emissão de partículas de impacto e flash de luz
	if is_instance_valid(impact_particles):
		impact_particles.restart()
		impact_particles.emitting = true
	if is_instance_valid(lance_light):
		lance_light.energy = 3.6
	
	# 4. Retenção de Momentum vs Ricochete
	if hit_type == HitReceiver.HitType.SHIELD:
		if on_power_charge:
			# Dash quebra a defesa com desaceleração menor
			velocity *= 0.65
		else:
			# Fora do dash, colisão com escudo empurra para trás com força
			var bounce_dir = -forward_vec
			velocity = bounce_dir * (bounce_force * 1.8)
	else:
		# Inimigos normais e pontos fracos:
		if on_power_charge or current_speed >= 280.0:
			# RÁPIDO: Matar não é um problema! Atravessa com facilidade mantendo a velocidade.
			var penalty = 0.04 if is_killed else 0.10
			velocity *= (1.0 - penalty)
		else:
			# DEVAGAR: A inércia é baixa, então o impacto contra o inimigo causa forte desaceleração
			# e um empurrão/knockback de recuo no próprio jogador!
			var speed_ratio = clampf((current_speed - min_charge_speed) / maxf(1.0, 280.0 - min_charge_speed), 0.0, 1.0)
			var slow_penalty = lerpf(0.65, 0.20, speed_ratio)
			if is_killed:
				slow_penalty *= 0.75
			
			# Reduz severamente a velocidade para frente
			velocity *= (1.0 - slow_penalty)
			
			# Recuo físico do impacto (knockback para trás vindo do inimigo)
			var recoil_force = lerpf(220.0, 50.0, speed_ratio)
			velocity += -forward_vec * recoil_force
			apply_camera_shake(0.35 * (1.0 - speed_ratio))

func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	
	# Zoom Dinâmico baseado na velocidade atual
	var effective_max = (max_speed + extra_speed) * (speed_multiplier + extra_speed_multiplier)
	if on_power_charge:
		effective_max = current_dash_speed
	var speed_ratio = clampf(velocity.length() / maxf(effective_max, 100.0), 0.0, 1.0)
	var target_zoom_val = lerpf(base_camera_zoom, min_camera_zoom, speed_ratio)
	camera.zoom = camera.zoom.lerp(Vector2(target_zoom_val, target_zoom_val), zoom_lerp_speed * delta)
	
	# Camera Shake com decaimento
	var shake_offset = Vector2.ZERO
	if camera_trauma > 0.0:
		camera_trauma = maxf(0.0, camera_trauma - camera_shake_decay * delta)
		var shake_amount = camera_trauma * camera_trauma
		shake_offset = Vector2(
			randf_range(-1.0, 1.0) * max_shake_offset * shake_amount,
			randf_range(-1.0, 1.0) * max_shake_offset * shake_amount
		)
		
	camera.offset = camera_cinematic_offset + shake_offset

func play_boss_intro_cinematic(target_world_pos: Vector2, hold_duration: float = 2.0) -> void:
	can_move = false
	velocity = Vector2.ZERO
	var target_offset = target_world_pos - global_position
	
	var tween = create_tween()
	# Pan cinematográfico suave até o Boss
	tween.tween_property(self, "camera_cinematic_offset", target_offset, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Pausa de foco no Boss para gerar hype
	tween.tween_interval(hold_duration)
	# Retorno suave da câmera para o cavaleiro
	tween.tween_property(self, "camera_cinematic_offset", Vector2.ZERO, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	can_move = true

func apply_camera_shake(amount: float) -> void:
	camera_trauma = clampf(camera_trauma + amount, 0.0, 1.0)

func trigger_hit_stop(duration: float = 0.06, time_scale: float = 0.05) -> void:
	Engine.time_scale = time_scale
	var timer = get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)

func _update_visual_effects(delta: float) -> void:
	# 1. Partículas de Drift (curvas e derrapagens)
	var right_vec = Vector2.RIGHT.rotated(heading_angle)
	var lateral_spd = abs(right_vec.dot(velocity))
	var is_drifting = lateral_spd > 75.0 and velocity.length() > 90.0
	if is_instance_valid(drift_particles):
		drift_particles.emitting = is_drifting
	
	# 2. Linhas de vento de alta velocidade
	var is_high_speed = on_power_charge or velocity.length() >= min_charge_speed * 1.15
	if is_instance_valid(speed_particles):
		speed_particles.emitting = is_high_speed
	
	# 3. Luz Reativa na Ponta da Lança
	if is_instance_valid(lance_light):
		var target_energy: float = 0.4
		var target_color: Color = Color(1.0, 0.85, 0.45)
		var target_scale: float = 1.2
		
		if on_power_charge:
			target_energy = 2.4
			target_color = Color(1.0, 0.35, 0.15)
			target_scale = 2.8
		elif velocity.length() >= min_charge_speed:
			var factor = clampf((velocity.length() - min_charge_speed) / maxf(1.0, max_speed - min_charge_speed), 0.0, 1.0)
			target_energy = lerpf(1.2, 1.8, factor)
			target_color = Color(1.0, 0.75, 0.25)
			target_scale = lerpf(1.6, 2.2, factor)
		
		lance_light.energy = lerpf(lance_light.energy, target_energy, delta * 8.0)
		lance_light.color = lance_light.color.lerp(target_color, delta * 8.0)
		lance_light.texture_scale = lerpf(lance_light.texture_scale, target_scale, delta * 8.0)

	# 4. Luz Central da Montaria (luz constante e confortável, sem oscilar com velocidade ou zoom)
	if is_instance_valid(central_light):
		var target_c_energy = 1.15
		var target_c_scale = 3.8
		central_light.energy = lerpf(central_light.energy, target_c_energy, delta * 4.0)
		central_light.texture_scale = lerpf(central_light.texture_scale, target_c_scale, delta * 4.0)


func _on_hurtbox_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
		
	# Verifica se é EnemyHitbox ou se tem a função de dano implementada
	if area is EnemyHitbox or area.has_method("get_damage_payload"):
		var payload: Dictionary = area.get_damage_payload(global_position)
		take_damage(payload["damage"]*((100-defense)/100), payload["knockback"])

func _check_overlapping_hitboxes() -> void:
	if is_invulnerable or not hurtbox_area:
		return
		
	for area in hurtbox_area.get_overlapping_areas():
		if area is EnemyHitbox or area.has_method("get_damage_payload"):
			var payload: Dictionary = area.get_damage_payload(global_position)
			take_damage(payload["damage"], payload["knockback"])
			break

func pickup_item(item: Area2D) -> void:
	var item_id = item.item_id
	if item_id/100 == 1:
		get_tree().current_scene.add_gold(item_id%100)
		$PlayerCanvas/notification.activate_notification("Collected %d coins" % (item_id%100))
		item.queue_free()
		return
	var canvas = get_tree().get_first_node_in_group("PlayerCanvas")
	if canvas and canvas.add_item_inventory(item):
		item.queue_free()
		var items_available = {
			2: "Lance",
			3: "Armor",
			4: "Cape",
			5: "Rein",
			6: "Horseshoe",
			7: "Saddle"
		}
		var lvl_val = item_id % 100
		var lvl_str = "Legend" if (lvl_val == 11) else ("Lvl %d" % lvl_val)
		$PlayerCanvas/notification.activate_notification("%s %s added to the inventory" % [items_available[item_id/100], lvl_str])

func apply_slow(factor: float = 0.5) -> void:
	active_slow_sources += 1
	speed_multiplier = factor
	# Corta a velocidade atual imediatamente para o novo teto de lentidão
	var effective_max_speed = (max_speed + extra_speed) * (speed_multiplier + extra_speed_multiplier)
	if velocity.length() > effective_max_speed:
		velocity = velocity.normalized() * effective_max_speed

func remove_slow() -> void:
	active_slow_sources = maxi(0, active_slow_sources - 1)
	if active_slow_sources == 0:
		speed_multiplier = 1.0

func die() -> void:
	can_move = false
	velocity = Vector2.ZERO
	var phase = 1
	var cur_gold = 0
	if is_instance_valid(get_tree().current_scene):
		if "current_phase" in get_tree().current_scene:
			phase = get_tree().current_scene.current_phase
		if "gold" in get_tree().current_scene:
			cur_gold = get_tree().current_scene.gold
	elif get_node_or_null("/root/GameManager"):
		phase = get_node("/root/GameManager").current_phase
		cur_gold = get_node("/root/GameManager").gold
		
	player_died.emit(last_damager_name, phase, cur_gold)
	# Oculta ou desativa enquanto a tela de morte processa
	visible = false

func respawn() -> void:
	can_move = true
	visible = true
	is_invulnerable = false
	modulate.a = 1.0
	current_health = max_health + extra_health
	velocity = Vector2.ZERO
	camera_cinematic_offset = Vector2.ZERO
	power_charge_load = 0.0
	on_power_charge = false
	health_changed.emit(current_health, max_health + extra_health)
	update_info()

func reset_to_starting_state() -> void:
	# 1. Limpa todos os slots de equipamentos no inventário
	var equip_container = get_node_or_null("PlayerCanvas/inventory/equip/equipments")
	if equip_container:
		for equip_slot in equip_container.get_children():
			if equip_slot.has_method("set_empty_slot"):
				equip_slot.set_empty_slot()
				
	# 2. Reseta o HUD de equipamentos equipados na tela
	var hud_equip = get_node_or_null("PlayerCanvas/equipment")
	if hud_equip:
		for item_name in ["lance", "armor", "cape", "rein", "horseshoe", "saddle"]:
			var node = hud_equip.get_node_or_null(item_name)
			if node:
				node.modulate = Color(1, 1, 1, 0.5)
				var lvl_lbl = node.get_node_or_null("lvl")
				if lvl_lbl:
					lvl_lbl.text = ""
					lvl_lbl.modulate = Color(1, 1, 1, 1)

	# 3. Limpa todos os slots de itens do inventário
	var inv_container = get_node_or_null("PlayerCanvas/inventory/invent/Container")
	if inv_container:
		for s in inv_container.get_children():
			if s.has_method("set_empty_slot"):
				s.set_empty_slot()

	# 4. Reseta todos os atributos adicionais para zero
	extra_damage = 0
	extra_health = 0
	defense = 0
	extra_speed = 0
	extra_steer_speed = 0
	extra_speed_multiplier = 0
	
	respawn()
	update_info()

func _gold_changed(_new_amount: int) -> void:
	update_info()
