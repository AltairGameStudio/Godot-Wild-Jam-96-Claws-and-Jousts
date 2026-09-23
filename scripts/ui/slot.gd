class_name slot
extends Control

var id = 0
var description = null
var item = {
	1: "Coin",
	2: "Lance",
	3: "Armor",
	4: "Cape",
	5: "Rein",
	6: "Horseshoe",
	7: "Saddle"
}
var item_description = {
	1: "%d",
	2: "Increase the damage in (%d)",
	3: "Decrease in (%d) percents the received damage",
	4: "Increase max health in (%d)",
	5: "Increases steer speed in (%.1f).",
	6: "Increases the speed multiplier in (%.1f).",
	7: "Increases the max speed in (%d)."
}
var item_value = {
	2: 5,
	3: 8,
	4: 3,
	5: 6,
	6: 4,
	7: 10
}
var slot_value = 0

func _ready() -> void:
	pass

func set_empty_slot() -> void:
	$sprite.texture = null
	$sprite.modulate = Color.WHITE
	$amount.text = ""
	id = 0
	slot_value = 0

func _update_visual() -> void:
	if id % 100 == 11:
		$sprite.modulate = Color(0.65, 1.25, 0.85)
	else:
		$sprite.modulate = Color.WHITE

func _calc_slot_value(item_id: int, quantity: int) -> int:
	var lvl = item_id % 100
	var it = item_id / 100
	if not item_value.has(it):
		return 0
	var mult = 20 if (lvl == 11) else lvl
	return int(((mult * item_value[it]) * 0.5) * quantity)

func _process(_delta: float) -> void:
	if $description.visible:
		$description.global_position = get_global_mouse_position() + Vector2(10,10)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if self.id == 0:
		return null
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(60, 60)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if id % 100 == 11:
		preview.modulate = Color(0.65, 1.25, 0.85)
	set_drag_preview(preview)
	$sprite.visible = false
	$amount.visible = false
	$description.visible = false
	return self

func _return_data(data: Variant) -> void:
	$sprite.texture = data.sprite
	$amount.text = data.amount
	_update_visual()

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if self is buy_slot:
			return
		$sprite.visible = true
		_update_visual()
		if !(self is equipment) and $amount:
			$amount.visible = true

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is equipment:
		if self.id == 0:
			return true
		elif data.id != self.id:
			return false
	if data is buy_slot:
		if (id != 0 and id != data.id):
			return false
		return data.can_buy()
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0:
		return
	if data == self:
		$sprite.visible = true
		_update_visual()
		if !(self is equipment):
			$amount.visible = true
		return
	if data is buy_slot:
		if id == 0:
			$sprite.texture = data.get_node("sprite").texture
			$amount.text = "1"
			id = data.id
		else:
			$amount.text = str(int($amount.text) + 1)
		slot_value = _calc_slot_value(id, int($amount.text))
		data.set_empty_slot()
		_update_visual()
		get_tree().call_group("player", "update_info")
	elif data is equipment and self.id == 0:
		get_tree().call_group("player", "equipment_changed", data.id, false)
		$amount.text = "1"
		$sprite.texture = data.equip_sprite
		id = data.id
		data.set_empty_slot()
		slot_value = _calc_slot_value(id, 1)
		_update_visual()
	elif self.id == data.id: # Se o id for o mesmo soma as quantidades
		var quantity = int($amount.text)
		if data is equipment:
			quantity += 1
			get_tree().call_group("player", "equipment_changed", data.id, false)
		else:
			quantity += int(data.get_node("amount").text)
		$amount.text = str(quantity)
		slot_value = _calc_slot_value(id, quantity)
		data.set_empty_slot()
		_update_visual()
	else: # Se o sprite for diferente troca os dados de lugar
		if data is sell_slot:
			data.item_removed_from_store()
		var sprite = data.get_node("sprite").texture
		var text = data.get_node("amount").text
		var n_id = data.id
		var n_val = data.slot_value
		data.get_node("sprite").texture = $sprite.texture
		data.get_node("amount").text = $amount.text
		data.id = id
		data.slot_value = slot_value
		if data.has_method("_update_visual"):
			data._update_visual()
		$sprite.texture = sprite
		$amount.text = text
		id = n_id
		slot_value = n_val
		_update_visual()

func _on_mouse_entered() -> void:
	if id == 0 or get_viewport().gui_is_dragging(): return
	var it = id/100
	var lvl = id%100 
	var is_legend = (lvl == 11)
	var buff = {
		1: lvl*5,
		2: 50 if is_legend else lvl*2,
		3: 50 if is_legend else lvl*3,
		4: 250 if is_legend else lvl*10,
		5: 4.0 if is_legend else lvl/5.0,
		6: 2.0 if is_legend else lvl/10.0,
		7: 1000 if is_legend else lvl*50
	}
	var lvl_str = "Legend" if is_legend else str(lvl)
	$description/label.text = "Item: %s\nLevel: %s\n%s\nSell value: %d" % [item[it], lvl_str, item_description[it] % buff[it], slot_value]
	if is_legend:
		$description/label.modulate = Color(0.65, 1.25, 0.85)
	else:
		$description/label.modulate = Color.WHITE
	$description.visible = true

func _on_mouse_exited() -> void:
	$description.visible = false
