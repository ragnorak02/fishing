extends Node

func vehicle(msg: String) -> void:
	if DebugFlags.DEBUG_VEHICLE: print("[Vehicle] %s" % msg)

func fish(msg: String) -> void:
	if DebugFlags.DEBUG_FISH: print("[Fish] %s" % msg)

func economy(msg: String) -> void:
	if DebugFlags.DEBUG_ECONOMY: print("[Economy] %s" % msg)

func upgrades(msg: String) -> void:
	if DebugFlags.DEBUG_UPGRADES: print("[Upgrades] %s" % msg)

func achievements(msg: String) -> void:
	if DebugFlags.DEBUG_ACHIEVEMENTS: print("[Achievements] %s" % msg)

func warn(category: String, msg: String) -> void:
	push_warning("[%s] %s" % [category, msg])

func err(category: String, msg: String) -> void:
	push_error("[%s] %s" % [category, msg])
