extends Node

# Sinais para atualização reativa de UI
signal gold_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)

# Economia e Meta-Progressão (Persistente)
var gold: int = 0

# Níveis e valores dos upgrades permanentes
var upgrades: Dictionary = {
	"charge_time": {"level": 1, "base_cost": 50, "cost_mult": 1.5, "val_step": -0.5, "current_val": 8.0},
	"engine_power": {"level": 1, "base_cost": 75, "cost_mult": 1.6, "val_step": 30.0, "current_val": 150.0},
	"base_damage": {"level": 1, "base_cost": 60, "cost_mult": 1.5, "val_step": 10.0, "current_val": 30.0},
	"drift_traction": {"level": 1, "base_cost": 100, "cost_mult": 1.8, "val_step": 0.03, "current_val": 0.85}
}

# Dados da Expedição Atual (Transitórios)
var current_run_loot: Array[Dictionary] = []
var run_timer: float = 0.0
var is_in_run: bool = false

# Caminhos das Cenas
const ARENA_SCENE_PATH = "res://scenes/arena/arena.tscn"
const TOWN_SCENE_PATH = "res://scenes/town/town.tscn"
var player_scene = preload("res://scenes/entities/player.tscn")

var current_phase: int = 1
var boss_defeated_once: bool = false
const BOSS_PHASE: int = 10 # Fase do Boss (Fase 10)

var current_scene: Node

func _ready() -> void:
	# Instancia o Menu de Pause global
	var pause_script = load("res://scripts/ui/pause_menu.gd")
	if pause_script:
		var pause_instance = CanvasLayer.new()
		pause_instance.set_script(pause_script)
		add_child(pause_instance)
		
	change_world(TOWN_SCENE_PATH)
	
func _process(delta: float) -> void:
	if is_in_run:
		run_timer += delta

func change_world(scene_path: String) -> void:
	if current_scene:
		current_scene.queue_free()
	
	Engine.time_scale = 1.0
	current_scene = load(scene_path).instantiate()
	$World.add_child(current_scene)
	
	var spawn = current_scene.get_node_or_null("PlayerSpawn")
	if spawn and has_node("Player"):
		var target_pos = spawn.global_position
		# Se for nível do boss (ex: BOSS_PHASE configurado na Arena), spawna 400px mais para baixo
		var is_boss_level = ("BOSS_PHASE" in current_scene and current_phase == current_scene.BOSS_PHASE) \
			or ("is_boss_battle" in current_scene and current_scene.is_boss_battle)
		if is_boss_level:
			target_pos.y += 400.0
			
		$Player.global_position = target_pos
		$Player.velocity = Vector2.ZERO
		$Player.can_move = true
		if $Player.has_method("cancel_dash"):
			$Player.cancel_dash()

# Inicia a expedição limpando os dados da run anterior
func start_run() -> void:
	current_run_loot.clear()
	run_timer = 0.0
	is_in_run = true
	change_world(ARENA_SCENE_PATH)

# Retorno com sucesso (ex: passou pelo portal de extração)
func end_run_success() -> void:
	await get_tree().create_timer(3.0).timeout
	print("Passou de fase")
	is_in_run = false
	var total_earned = 0
	
	for item in current_run_loot:
		var freshness_mult = clampf(1.0 - (run_timer / 300.0), 0.2, 1.0)
		total_earned += int(item.get("base_value", 10) * freshness_mult)
	
	add_gold(total_earned)
	current_run_loot.clear.call_deferred()
	
	# Avança para a próxima fase
	current_phase += 1
	change_world(TOWN_SCENE_PATH)

# Retorno por morte (perde os itens da run atual e reseta tudo para o início)
func end_run_failure() -> void:
	is_in_run = false
	current_run_loot.clear.call_deferred()
	
	# Reseta a fase ao morrer
	current_phase = 1
	boss_defeated_once = false
	gold = 0
	gold_changed.emit(20)
	
	# Reseta o player para a configuração inicial completa (sem equipamentos, sem itens, vida cheia)
	if has_node("Player") and $Player.has_method("reset_to_starting_state"):
		$Player.reset_to_starting_state()
	elif has_node("Player") and $Player.has_method("respawn"):
		$Player.respawn()
		
	upgrades["charge_time"]["current_val"] = 8.0
	upgrades["engine_power"]["current_val"] = 150.0
	upgrades["base_damage"]["current_val"] = 30.0
	upgrades["drift_traction"]["current_val"] = 0.85
	change_world(TOWN_SCENE_PATH)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func get_upgrade_cost(upgrade_id: String) -> int:
	if not upgrades.has(upgrade_id):
		return 999999
	var data = upgrades[upgrade_id]
	return int(data["base_cost"] * pow(data["cost_mult"], data["level"] - 1))

func buy_upgrade(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		return false
		
	var cost = get_upgrade_cost(upgrade_id)
	if gold < cost:
		return false
		
	gold -= cost
	gold_changed.emit(gold)
	
	var data = upgrades[upgrade_id]
	data["level"] += 1
	data["current_val"] += data["val_step"]
	
	upgrade_purchased.emit(upgrade_id, data["level"])
	return true

func reset_game_to_menu() -> void:
	is_in_run = false
	current_run_loot.clear()
	run_timer = 0.0
	current_phase = 1
	boss_defeated_once = false
	gold = 20
	
	upgrades = {
		"charge_time": {"level": 1, "base_cost": 50, "cost_mult": 1.5, "val_step": -0.5, "current_val": 8.0},
		"engine_power": {"level": 1, "base_cost": 75, "cost_mult": 1.6, "val_step": 40.0, "current_val": 150.0},
		"base_damage": {"level": 1, "base_cost": 60, "cost_mult": 1.5, "val_step": 10.0, "current_val": 30.0},
		"drift_traction": {"level": 1, "base_cost": 100, "cost_mult": 1.8, "val_step": 0.03, "current_val": 0.85}
	}
	
	if get_node_or_null("/root/AudioManager"):
		AudioManager.play_main_menu_theme()
		
	get_tree().change_scene_to_file("res://weball/main_menu.tscn")
