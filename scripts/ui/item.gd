extends Area2D

# Item_id list:
# @@ -> Identificador do item
# $$ -> Level do item
# Id -> @@$$
# Identificadores:
# 00 -> Null
# 01 -> Moeda
# 02 -> Lança
# 03 -> Armadura
# 04 -> Capa
# 05 -> Rédea
# 06 -> Ferradura
# 07 -> Sela

var items = {
	1: "coin",
	2: "lance",
	3: "armor",
	4: "cape",
	5: "rein",
	6: "horseshoe",
	7: "saddle"
}
var item_value = {
	2: 5,
	3: 8,
	4: 3,
	5: 6,
	6: 4,
	7: 10
}
var item_id = 0

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func setup(id, pos: Vector2) -> void:
	item_id = id
	self.global_position = pos
	$sprite.texture = load("res://assets/sprites/items/%s.png" % items[item_id/100])
	scale = Vector2(0.75, 0.75)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		AudioManager.play_sfx(AudioManager.SFX_COIN)
		body.pickup_item(self)
		queue_free.call_deferred()
