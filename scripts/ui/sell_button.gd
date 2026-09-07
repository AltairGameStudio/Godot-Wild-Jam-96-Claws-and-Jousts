extends Control

@onready var sale_zone = $"../sale_zone"

func _process(_delta: float) -> void:
	if $description.visible:
		$description.global_position = get_global_mouse_position() + Vector2(10,10)

func clear_store() -> void:
	var total = 0
	for child_slot in sale_zone.get_children():
		AudioManager.play_sfx(AudioManager.SFX_BUY)
		total += child_slot.slot_value
		child_slot.set_empty_slot()
	get_tree().current_scene.add_gold(total)
	$"../total".text = "0"

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		clear_store()
		var tween = create_tween().set_parallel(false)
		tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_mouse_entered() -> void:
	$description.visible = true

func _on_mouse_exited() -> void:
	$description.visible = false
