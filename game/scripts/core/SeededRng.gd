extends RefCounted
class_name SeededRng

var rng := RandomNumberGenerator.new()
var seed_value := 12345

func configure(seed: int = 12345) -> void:
	seed_value = seed
	rng.seed = seed_value

func range_i(min_value: int, max_value: int) -> int:
	return rng.randi_range(min_value, max_value)

func chance(percent: int) -> bool:
	return range_i(1, 100) <= clamp(percent, 0, 100)

func pick(items: Array, fallback = null):
	if items.is_empty():
		return fallback
	return items[range_i(0, items.size() - 1)]
