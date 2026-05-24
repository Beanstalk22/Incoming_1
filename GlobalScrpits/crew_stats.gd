extends Resource
class_name CrewStats

@export_category("Skill Points")
@export var available_points: int = 5

@export_category("Crew Levels")
@export var agility_level: int = 0    # Increases walk/sprint speed
@export var repair_level: int = 0     # Increases wrench repair output
@export var handling_level: int = 0   # Decreases weapon sway/recoil (example for future)

# Multipliers/Increments per level
const SPEED_BONUS_PER_LEVEL: float = 0.5
const REPAIR_BONUS_PER_LEVEL: int = 5

# Upgrade functions to call from your UI
func upgrade_agility() -> bool:
	if available_points > 0:
		agility_level += 1
		available_points -= 1
		return true
	return false

func upgrade_repair() -> bool:
	if available_points > 0:
		repair_level += 1
		available_points -= 1
		return true
	return false

# Getter functions for the player script to calculate final stats
func get_speed_bonus() -> float:
	return agility_level * SPEED_BONUS_PER_LEVEL

func get_repair_bonus() -> int:
	return repair_level * REPAIR_BONUS_PER_LEVEL
