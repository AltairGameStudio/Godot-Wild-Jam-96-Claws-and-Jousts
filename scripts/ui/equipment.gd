extends slot
class_name equipment

var id_accepted = 0
var equip_sprite = null

func set_empty_slot() -> void:
	$sprite.texture = null
	$sprite.modulate = Color.WHITE
	self.id = 0
	self.slot_value = 0

func _get_drag_data(_at_position: Vector2) -> Variant:
	if self.id == 0:
		return null
	var preview = TextureRect.new()
	preview.texture = $sprite.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if id % 100 == 11:
		preview.modulate = Color(0.65, 1.25, 0.85)
	set_drag_preview(preview)
	$sprite.visible = false
	return self

func _return_data(data: Variant) -> void:
	$sprite.texture = data.sprite

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is buy_slot:
		if id != 0 or (data.id/100 != id_accepted):
			return false
		return data.can_buy()
	if data is slot:
		if data.id/100 == id_accepted:
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.id == 0 or data.id == self.id:
		return
	var quantity = 0
	if data is buy_slot or data is equipment:
		quantity = 1
	else:
		quantity = int(data.get_node("amount").text)
	if id == 0:
		$sprite.texture = equip_sprite
		id = data.id
		if quantity == 1:
			data.set_empty_slot()
		else:
			data.get_node("amount").text = str(quantity - 1)
			data.slot_value = data._calc_slot_value(data.id, quantity - 1)
			if data.has_method("_update_visual"):
				data._update_visual()
	else:
		get_tree().call_group("player", "equipment_changed", id, false)
		if quantity == 1:
			var n_id = data.id
			data.id = id
			data.slot_value = data._calc_slot_value(data.id, 1)
			id = n_id
			if data.has_method("_update_visual"):
				data._update_visual()
		else:
			data.get_node("amount").text = str(quantity - 1)
			data.slot_value = data._calc_slot_value(data.id, quantity - 1)
			if data.has_method("_update_visual"):
				data._update_visual()
			return_to_inventory(id)
			id = data.id
	if !(data is buy_slot):
		data.get_node("sprite").visible = true
		data.get_node("amount").visible = true
	$sprite.modulate = Color(0.65, 1.25, 0.85) if (self.id % 100 == 11) else Color.WHITE
	get_tree().call_group("player", "equipment_changed", self.id, true)
	slot_value = _calc_slot_value(self.id, 1)

func return_to_inventory(new_item_id) -> bool:
	var empty = null
	for inv_slot in $"../../../invent/Container".get_children():
		if inv_slot is not slot:
			continue
		if inv_slot.id == new_item_id:
			var new_amount = int(inv_slot.get_node("amount").text)
			new_amount += 1
			inv_slot.get_node("amount").text = str(new_amount)
			inv_slot.slot_value = inv_slot._calc_slot_value(new_item_id, new_amount)
			if inv_slot.has_method("_update_visual"):
				inv_slot._update_visual()
			return true 
		elif inv_slot.id == 0 and empty == null:
			empty = inv_slot
	if not(empty == null):
		empty.get_node("sprite").texture = equip_sprite
		empty.get_node("amount").text = "1"
		empty.id = new_item_id
		empty.slot_value = empty._calc_slot_value(new_item_id, 1)
		if empty.has_method("_update_visual"):
			empty._update_visual()
		return true
	return false
