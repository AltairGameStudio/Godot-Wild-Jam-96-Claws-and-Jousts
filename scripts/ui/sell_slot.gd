extends slot
class_name sell_slot

@onready var total_label = $"../../total"

var lvl_value_multiplier = 2

func set_empty_slot() -> void:
	item_removed_from_store()
	$sprite.texture = null
	$amount.text = ""
	id = 0
	slot_value = 0

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is buy_slot:
		return false
	return super(_at_position, data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data == self:
		return
	if data.id == self.id:
		item_removed_from_store()
	super(_at_position, data)
	new_item_on_store()

func new_item_on_store() -> void:
	var tot_tmp = int(total_label.text)
	tot_tmp += slot_value
	total_label.text = str(tot_tmp)
	
func item_removed_from_store() -> void:
	var tot_tmp = int(total_label.text)
	tot_tmp -= slot_value
	total_label.text = str(tot_tmp)
