class_name HitReceiver
extends Area2D

enum HitType { NORMAL, WEAKSPOT, SHIELD }

@export var hit_type: HitType = HitType.NORMAL
@export var damage_multiplier: float = 1.0
@export var momentum_penalty: float = 0.25

# Adicionado o parâmetro impact_speed ao sinal
signal hit_received(damage: float, direction: Vector2, hit_type: HitType, impact_speed: float)

# Adicionado impact_speed como parâmetro da função
func process_hit(incoming_damage: float, hit_direction: Vector2, impact_speed: float = 0.0) -> Dictionary:
	var final_damage = incoming_damage * damage_multiplier
	hit_received.emit(final_damage, hit_direction, hit_type, impact_speed)
	
	var enemy_entity = owner if owner else (get_parent().get_parent() if get_parent() else null)
	var is_killed = false
	if is_instance_valid(enemy_entity) and "current_health" in enemy_entity:
		is_killed = (enemy_entity.current_health <= 0.0)
	
	return {
		"damage_dealt": final_damage,
		"hit_type": hit_type,
		"momentum_penalty": momentum_penalty,
		"killed": is_killed,
		"target": enemy_entity
	}

