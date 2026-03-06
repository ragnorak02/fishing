extends Node

signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress(quest_id: String, current: int, target: int)

var active_quests: Dictionary = {}   # quest_id -> QuestData
var completed_quests: Array = []

# Quest definitions
const QUESTS := {
	"catch_5_sardines": {
		"title": "Sardine Run",
		"description": "Catch 5 sardines for Old Tanaka's market stall.",
		"type": "catch_species",
		"target_species": "sardine",
		"target_count": 5,
		"reward_gold": 75,
		"giver": "Old Tanaka",
	},
	"catch_3_rare": {
		"title": "The Big Catch",
		"description": "Catch 3 rare or legendary fish to prove your skill.",
		"type": "catch_rarity",
		"target_rarity": 2,  # RARE or above
		"target_count": 3,
		"reward_gold": 200,
		"giver": "Captain Higa",
	},
	"earn_500_gold": {
		"title": "Gold Rush",
		"description": "Earn 500 gold from selling fish.",
		"type": "earn_gold",
		"target_count": 500,
		"reward_gold": 150,
		"giver": "Old Tanaka",
	},
	"discover_5_species": {
		"title": "Marine Biologist",
		"description": "Discover 5 different fish species.",
		"type": "discover_species",
		"target_count": 5,
		"reward_gold": 100,
		"giver": "Harbor Master",
	},
	"catch_bluefin": {
		"title": "The Bluefin Challenge",
		"description": "Catch a Bluefin Tuna from the deep waters.",
		"type": "catch_species",
		"target_species": "bluefin_tuna",
		"target_count": 1,
		"reward_gold": 300,
		"giver": "Old Tanaka",
	},
	"explore_abyss": {
		"title": "Into the Abyss",
		"description": "Dive into the abyss biome and catch 3 fish.",
		"type": "catch_in_biome",
		"target_biome": "abyss",
		"target_count": 3,
		"reward_gold": 250,
		"giver": "Harbor Master",
	},
	"weather_fisher": {
		"title": "Storm Chaser",
		"description": "Catch a fish during a storm.",
		"type": "catch_in_weather",
		"target_weather": 3,  # STORM
		"target_count": 1,
		"reward_gold": 200,
		"giver": "Captain Higa",
	},
	"catch_boss": {
		"title": "Legend of the Deep",
		"description": "Defeat the Leviathan King boss fish.",
		"type": "catch_species",
		"target_species": "leviathan_king",
		"target_count": 1,
		"reward_gold": 500,
		"giver": "Harbor Master",
	},
	"discover_10_species": {
		"title": "Ocean Scholar",
		"description": "Discover 10 different fish species.",
		"type": "discover_species",
		"target_count": 10,
		"reward_gold": 250,
		"giver": "Harbor Master",
	},
	"night_fisher": {
		"title": "Midnight Fisher",
		"description": "Catch 3 fish at night.",
		"type": "catch_at_time",
		"target_time": 4,  # NIGHT
		"target_count": 3,
		"reward_gold": 175,
		"giver": "Captain Higa",
	},
}

func accept_quest(quest_id: String) -> bool:
	if quest_id in active_quests or quest_id in completed_quests:
		return false
	if quest_id not in QUESTS:
		return false
	active_quests[quest_id] = {"progress": 0}
	quest_accepted.emit(quest_id)
	return true

func get_available_quests(giver_name: String) -> Array:
	var available: Array = []
	for quest_id in QUESTS:
		if quest_id in active_quests or quest_id in completed_quests:
			continue
		if QUESTS[quest_id]["giver"] == giver_name:
			available.append(quest_id)
	return available

func get_active_quests_for(giver_name: String) -> Array:
	var quests: Array = []
	for quest_id in active_quests:
		if QUESTS[quest_id]["giver"] == giver_name:
			quests.append(quest_id)
	return quests

func get_quest_info(quest_id: String) -> Dictionary:
	if quest_id in QUESTS:
		var info: Dictionary = QUESTS[quest_id].duplicate()
		if quest_id in active_quests:
			info["progress"] = active_quests[quest_id]["progress"]
			info["status"] = "active"
		elif quest_id in completed_quests:
			info["status"] = "completed"
		else:
			info["status"] = "available"
		return info
	return {}

func notify_catch(species_id: String, weight: float) -> void:
	var species := FishDatabase.get_species(species_id)
	if species == null:
		return
	for quest_id in active_quests.keys():
		var quest: Dictionary = QUESTS[quest_id]
		var progress: int = active_quests[quest_id]["progress"]
		var advanced := false
		match quest["type"]:
			"catch_species":
				if species_id == quest["target_species"]:
					advanced = true
			"catch_rarity":
				if species.rarity >= quest["target_rarity"]:
					advanced = true
			"catch_in_biome":
				if quest["target_biome"] == GameManager.current_dive_biome:
					advanced = true
			"catch_in_weather":
				var ws = get_node_or_null("/root/WeatherSystem")
				if ws and ws.current_weather == quest["target_weather"]:
					advanced = true
			"catch_at_time":
				if TimeManager.current_time == quest["target_time"]:
					advanced = true
		if advanced:
			progress += 1
			active_quests[quest_id]["progress"] = progress
			quest_progress.emit(quest_id, progress, quest["target_count"])
			if progress >= quest["target_count"]:
				_complete_quest(quest_id)

func notify_gold_earned(amount: int) -> void:
	for quest_id in active_quests.keys():
		var quest: Dictionary = QUESTS[quest_id]
		if quest["type"] == "earn_gold":
			active_quests[quest_id]["progress"] += amount
			var progress: int = active_quests[quest_id]["progress"]
			quest_progress.emit(quest_id, progress, quest["target_count"])
			if progress >= quest["target_count"]:
				_complete_quest(quest_id)

func notify_discovery(species_id: String) -> void:
	var count := SaveManager.get_discovery_count()
	for quest_id in active_quests.keys():
		var quest: Dictionary = QUESTS[quest_id]
		if quest["type"] == "discover_species":
			active_quests[quest_id]["progress"] = count
			quest_progress.emit(quest_id, count, quest["target_count"])
			if count >= quest["target_count"]:
				_complete_quest(quest_id)

func _complete_quest(quest_id: String) -> void:
	if quest_id not in active_quests:
		return
	var quest: Dictionary = QUESTS[quest_id]
	Inventory.gold += quest["reward_gold"]
	Inventory.gold_changed.emit(Inventory.gold)
	completed_quests.append(quest_id)
	active_quests.erase(quest_id)
	quest_completed.emit(quest_id)

func get_save_state() -> Dictionary:
	return {
		"active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate(),
	}

func load_save_state(data: Dictionary) -> void:
	active_quests = data.get("active_quests", {})
	completed_quests = data.get("completed_quests", [])
