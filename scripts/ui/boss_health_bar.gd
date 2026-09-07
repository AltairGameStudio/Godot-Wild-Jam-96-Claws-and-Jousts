class_name BossHealthBar
extends Control

@onready var container: VBoxContainer = $Container
@onready var boss_name_label: Label = $Container/BossNameLabel
@onready var health_bar: ProgressBar = $Container/ProgressBar

var health_tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0

func setup_boss(boss_node: Node2D) -> void:
	if not is_instance_valid(boss_node):
		return
		
	if "boss_name" in boss_node:
		boss_name_label.text = boss_node.boss_name
		
	if "max_health" in boss_node and "current_health" in boss_node:
		health_bar.max_value = boss_node.max_health
		health_bar.value = boss_node.current_health
		
	if boss_node.has_signal("health_changed"):
		if not boss_node.health_changed.is_connected(_on_boss_health_changed):
			boss_node.health_changed.connect(_on_boss_health_changed)
			
	if boss_node.has_signal("boss_defeated"):
		if not boss_node.boss_defeated.is_connected(_on_boss_defeated):
			boss_node.boss_defeated.connect(_on_boss_defeated)
			
	# Fade-in suave de aparição
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_boss_health_changed(current_hp: float, _max_hp: float) -> void:
	if health_tween and health_tween.is_valid():
		health_tween.kill()
		
	health_tween = create_tween()
	health_tween.tween_property(health_bar, "value", current_hp, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_boss_defeated() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
