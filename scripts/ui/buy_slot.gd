extends slot
class_name buy_slot

var item_cost = 0
var item_lvl = 1
var item_type = 0

func _ready() -> void:
	item_type = int(name)
	item_cost = item_value[item_type]
	slot_value = int(item_cost*0.5)
	id = 100*item_type+item_lvl
	$cost.text = str(item_cost)

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(60, 60)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item_lvl == 11:
		preview.modulate = Color(0.65, 1.25, 0.85)
	set_drag_preview(preview)
	return self

func set_empty_slot():
	get_tree().current_scene.gold -= item_cost

func _notification(_what):
	return
	
func can_buy() -> bool:
	if item_cost <= get_tree().current_scene.gold:
		return true
	return false

func _is_legend_unlocked() -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm and (gm.boss_defeated_once or gm.current_phase > gm.BOSS_PHASE):
		return true
	if is_instance_valid(get_tree().current_scene) and "current_phase" in get_tree().current_scene:
		var cur_p = get_tree().current_scene.current_phase
		var b_p = 1
		if gm:
			b_p = gm.BOSS_PHASE
		if cur_p > b_p:
			return true
	return false

func on_lvl_up() -> void:
	var max_lvl = 11 if _is_legend_unlocked() else 10
	if item_lvl >= max_lvl:
		return
	item_lvl += 1
	id += 1
	if item_lvl == 11:
		item_cost = (item_value[item_type] * 10) * 2
		$sprite.modulate = Color(0.65, 1.25, 0.85)
	else:
		item_cost = item_value[item_type] * item_lvl
		$sprite.modulate = Color.WHITE
	slot_value = int(item_cost * 0.5)
	$cost.text = str(item_cost)

func on_lvl_down() -> void:
	if item_lvl <= 1:
		return
	item_lvl -= 1
	id -= 1
	if item_lvl == 11:
		item_cost = (item_value[item_type] * 10) * 2
		$sprite.modulate = Color(0.65, 1.25, 0.85)
	else:
		item_cost = item_value[item_type] * item_lvl
		$sprite.modulate = Color.WHITE
	slot_value = int(item_cost * 0.5)
	$cost.text = str(item_cost)
