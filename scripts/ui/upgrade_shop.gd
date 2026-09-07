extends Container

@onready var game = get_tree().current_scene
@onready var player = get_tree().current_scene.get_node("Player")

@onready var charge_time = $background/charge_time_container
@onready var engine_power = $background/engine_power_container
@onready var base_damage = $background/base_damage_container
@onready var drift_traction = $background/drift_traction_container
var upgrade_names = ["charge_time", "engine_power", "base_damage", "drift_traction"]

const TEX_CLOSE = preload("res://assets/sprites/start_main_menu/close.png")

func _ready() -> void:
	update_upgrades()
	_setup_close_button()

func update_upgrades() -> void:
	$background/charge_time_container/step_val.text = str(abs(game.upgrades["charge_time"]["val_step"])) + "s"
	$background/charge_time_container/cost.text = str(int(game.upgrades["charge_time"]["base_cost"] * (game.upgrades["charge_time"]["cost_mult"]**game.upgrades["charge_time"]["level"])))
	$background/engine_power_container/step_val.text = str(game.upgrades["engine_power"]["val_step"])
	$background/engine_power_container/cost.text = str(game.upgrades["engine_power"]["base_cost"] * (game.upgrades["engine_power"]["cost_mult"]**game.upgrades["engine_power"]["level"]))
	$background/base_damage_container/step_val.text = str(game.upgrades["base_damage"]["val_step"])
	$background/base_damage_container/cost.text = str(game.upgrades["base_damage"]["base_cost"] * (game.upgrades["base_damage"]["cost_mult"]**game.upgrades["base_damage"]["level"]))
	$background/drift_traction_container/step_val.text = str(game.upgrades["drift_traction"]["val_step"])
	$background/drift_traction_container/cost.text = str(game.upgrades["drift_traction"]["base_cost"] * (game.upgrades["drift_traction"]["cost_mult"]**game.upgrades["drift_traction"]["level"]))

func apply_upgrade(upgrade_name: String, val_step: int) -> void:
	match upgrade_name:
		"charge_time":
			player.charge_time_to_fill = maxf(0.5, player.charge_time_to_fill + val_step)
		"engine_power":
			player.engine_power += val_step
		"base_damage":
			player.base_damage += val_step
		"drift_traction":
			player.drift_traction += val_step
	player.update_info()

func buy_upgrade(upgrade_name: String) -> void:
	var upgrade_entry = game.upgrades[upgrade_name]
	var cost = upgrade_entry["base_cost"] * (upgrade_entry["cost_mult"] ** upgrade_entry["level"])
	var val_step = upgrade_entry["val_step"]
	if ((upgrade_entry["base_cost"] * (upgrade_entry["cost_mult"] ** upgrade_entry["level"])) <= game.gold):
		game.gold -= cost
		AudioManager.play_sfx(AudioManager.SFX_BUY)
		apply_upgrade(upgrade_name, val_step)
		$"../notification".activate_notification("Upgrade bought")
		game.upgrades[upgrade_name]["level"] += 1
		game.upgrades[upgrade_name]["current_val"] += game.upgrades[upgrade_name]["val_step"]
		update_upgrades()
	else:
		$"../notification".activate_notification("You don't have money for that")

func _setup_close_button() -> void:
	var close_btn = TextureButton.new()
	close_btn.texture_normal = TEX_CLOSE
	
	# === AJUSTE DE TAMANHO ===
	var button_size = Vector2(48, 48) # Altere aqui o tamanho (Largura, Altura)
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.custom_minimum_size = button_size
	
	# === AJUSTE DE POSIÇÃO ===
	var margin_right = -50.0 # Mais alto = mais para a esquerda
	var margin_top = 15.0   # Mais alto = mais para baixo
	
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = - (margin_right + button_size.x)
	close_btn.offset_right = - margin_right
	close_btn.offset_top = margin_top
	close_btn.offset_bottom = margin_top + button_size.y
	
	close_btn.pressed.connect(func():
		var canvas = get_parent()
		if canvas.has_method("close_all_menus"):
			canvas.close_all_menus()
		else:
			visible = false
			if is_instance_valid(player):
				player.can_move = true
	)
	$background.add_child(close_btn)
