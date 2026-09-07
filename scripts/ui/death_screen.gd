class_name DeathScreen
extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var panel: Panel = $Overlay/Panel
@onready var title_label: Label = $Overlay/Panel/Content/Title
@onready var level_label: Label = $Overlay/Panel/Content/LevelLabel
@onready var gold_label: Label = $Overlay/Panel/Content/GoldLabel
@onready var killer_label: Label = $Overlay/Panel/Content/KillerLabel
@onready var return_button: Button = $Overlay/Panel/Content/ReturnButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)

func show_death_screen(killer_name: String, final_level: int, gold_collected: int) -> void:
	if level_label:
		level_label.text = "Level Reached: %d" % final_level
	if gold_label:
		gold_label.text = "Total Gold: %d" % gold_collected
	if killer_label:
		killer_label.text = "Slain by: %s" % killer_name
		
	visible = true
	get_tree().paused = true
	
	if is_instance_valid(overlay):
		overlay.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_return_button_pressed() -> void:
	get_tree().paused = false
	visible = false
	
	# Retorna à cidade e limpa o estado da run
	if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.has_method("end_run_failure"):
		get_tree().current_scene.end_run_failure()
	elif get_node_or_null("/root/GameManager"):
		get_node("/root/GameManager").end_run_failure()
	else:
		get_tree().change_scene_to_file("res://scenes/town/town.tscn")
