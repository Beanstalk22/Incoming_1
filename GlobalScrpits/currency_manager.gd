extends Node
	# Broadcasts whenever currency is added or spent
signal currency_changed(currency_type: String, new_amount: int)

	# Dictionary allows you to easily track multiple currencies
var balances: Dictionary = {
	"credit": 0,
	"gold": 0,
	"crew points": 0
	}

func add_currency(type: String, amount: int) -> void:
# Inside currency_manager.gd
	if balances.has(type):
		balances[type] += amount
		currency_changed.emit(type, balances[type], amount) # Make sure 'amount' is here!
	else:
		push_warning("Attempted to add unknown currency: ", type)

func spend_currency(type: String, amount: int) -> bool:
	if balances.has(type) and balances[type] >= amount:
		balances[type] -= amount
		currency_changed.emit(type, balances[type])
		return true
		
	return false # Not enough funds

func get_balance(type: String) -> int:
	
		return balances.get(type, 0)
