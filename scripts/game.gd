extends Node
## Global game state, autoloaded as "Game".
## Money, crew, upgrades, seasons (prestige), settings and save/load.
## Gameplay nodes read derived stats (hand size, cell value, ...) from here.

signal changed
signal settings_changed
signal overlord_says(text: String, duration: float)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1
## Screen pixels per wheat cell. Every sprite pixel is one cell.
const CELL := 4.0
const SEASON_COUNT := 7
const CURSORS: Array = ["hand", "dot", "arrow", "triangle", "square", "hexagon"]

var money: float = 0.0
var season: int = 0                 # 0-based
var season_earned: float = 0.0
var signal_pts: int = 0             # prestige currency
var aliens: Dictionary = {}         # id -> count
var upgrades: Dictionary = {}       # id -> level (reset each season)
var signal_upgrades: Dictionary = {} # id -> level (forever)
var won: bool = false
var intro_done: bool = false
var goal_announced: bool = false
var stats: Dictionary = {"circles": 0, "perfect": 0, "cows": 0, "golden": 0, "spins": 0, "jackpots": 0, "earned": 0.0, "best": 0.0, "harvests": 0}

# Settings (kept even when you start a new game).
var crt_amount: float = 0.55
var sfx_volume: float = 0.8
var music_volume: float = 0.55
var cursor: String = "hand"
var fullscreen: bool = false
var screen_shake: bool = true

# Combo
var combo: int = 0
var combo_left: float = 0.0

# Money/sec estimate
var _recent: Array = []   # [time, amount]


func _ready() -> void:
	randomize()
	load_settings()
	new_season(true)


func _process(delta: float) -> void:
	if combo_left > 0.0:
		combo_left -= delta
		if combo_left <= 0.0:
			combo = 0


# ---------------------------------------------------------------- levels

func count(id: String) -> int:
	return int(aliens.get(id, 0))


func lvl(id: String) -> int:
	return int(upgrades.get(id, 0))


func sig(id: String) -> int:
	return int(signal_upgrades.get(id, 0))


func alien_cost(id: String) -> float:
	return Defs.cost(Defs.find(Defs.ALIENS, id), count(id))


func upgrade_cost(id: String) -> float:
	return Defs.cost(Defs.find(Defs.UPGRADES, id), lvl(id))


func signal_cost(id: String) -> int:
	return int(round(Defs.cost(Defs.find(Defs.SIGNAL, id), sig(id))))


func is_maxed(def: Dictionary, level: int) -> bool:
	return int(def.get("max", -1)) >= 0 and level >= int(def["max"])


## Aliens unlock one at a time: the next type shows once you own the previous.
func alien_unlocked(id: String) -> bool:
	for i in Defs.ALIENS.size():
		if Defs.ALIENS[i]["id"] == id:
			return i == 0 or count(Defs.ALIENS[i - 1]["id"]) > 0 or count(id) > 0
	return false


func buy_alien(id: String) -> bool:
	var price := alien_cost(id)
	if money < price:
		return false
	money -= price
	aliens[id] = count(id) + 1
	changed.emit()
	return true


func buy_upgrade(id: String) -> bool:
	var def := Defs.find(Defs.UPGRADES, id)
	if is_maxed(def, lvl(id)) or money < upgrade_cost(id):
		return false
	money -= upgrade_cost(id)
	upgrades[id] = lvl(id) + 1
	changed.emit()
	return true


func buy_signal(id: String) -> bool:
	var def := Defs.find(Defs.SIGNAL, id)
	if is_maxed(def, sig(id)) or signal_pts < signal_cost(id):
		return false
	signal_pts -= signal_cost(id)
	signal_upgrades[id] = sig(id) + 1
	changed.emit()
	return true


# ---------------------------------------------------------------- formulas

## Brush radius in cells.
func hand_radius() -> float:
	return 1.3 + 0.75 * (lvl("hand") + sig("quick"))


func global_mult() -> float:
	return (1.0 + 0.5 * sig("boost"))


## Money per wheat stalk inside a circle.
func cell_value() -> float:
	return 0.12 * pow(1.35, lvl("fertilizer")) * global_mult()


func shape_bonus_scale() -> float:
	return 1.0 + 0.25 * lvl("geometry")


func circle_life() -> float:
	return 14.0 + 4.0 * lvl("memory")


## Money per stalk per second while a circle is on show.
func tourist_rate() -> float:
	return 0.01 * lvl("tourists") * cell_value()


func combo_window() -> float:
	return 3.0 + 0.6 * lvl("combo")


func combo_mult() -> float:
	return 1.0 + combo * (0.15 + 0.1 * lvl("combo"))


func alien_speed() -> float:
	return 1.0 + 0.2 * lvl("boots")


func golden_max() -> int:
	return 3 + 2 * lvl("golden") + 2 * sig("lucky")


func cow_count() -> int:
	return 1 + lvl("magnet")


## Chance that reel 3 copies reel 1 (on top of normal odds).
func slot_luck() -> float:
	return 0.015 * lvl("antenna") + 0.02 * sig("lucky")


func season_goal() -> float:
	return 4000.0 * pow(14.0, season)


func season_name() -> String:
	if season < Defs.SEASONS.size():
		return Defs.SEASONS[season]
	return "Season %d" % (season + 1)


func goal_reached() -> bool:
	return season_earned >= season_goal()


func signal_gain() -> int:
	if not goal_reached():
		return 0
	return int(floor(3.0 * sqrt(season_earned / season_goal()) * (1.0 + 0.5 * season)))


# ---------------------------------------------------------------- money

## Call this a lot: every circle, every tourist tick.
func earn(amount: float) -> void:
	if amount <= 0.0:
		return
	money += amount
	season_earned += amount
	stats["earned"] = float(stats["earned"]) + amount
	_recent.append([Time.get_ticks_msec(), amount])
	if goal_reached() and not goal_announced:
		goal_announced = true
		say(Quips.pick(Quips.GOAL), 7.0)
	changed.emit()


func spend(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	changed.emit()
	return true


func per_second() -> float:
	var now := Time.get_ticks_msec()
	while not _recent.is_empty() and now - int(_recent[0][0]) > 15000:
		_recent.pop_front()
	var sum := 0.0
	for r in _recent:
		sum += float(r[1])
	return sum / 15.0


## Called when a circle locks. Returns the combo multiplier for it.
func bump_combo() -> float:
	if combo_left > 0.0:
		combo = mini(combo + 1, 25)
	else:
		combo = 0
	combo_left = combo_window()
	return combo_mult()


func say(text: String, duration := 5.0) -> void:
	overlord_says.emit(text, duration)


# ---------------------------------------------------------------- seasons

func new_season(first := false) -> void:
	money = 25.0 * pow(5.0, sig("seed")) if sig("seed") > 0 else 0.0
	season_earned = 0.0
	aliens = {}
	upgrades = {}
	goal_announced = false
	combo = 0
	combo_left = 0.0
	if sig("crew") > 0:
		aliens["greeblet"] = 2 * sig("crew")
	if not first:
		changed.emit()


## Harvest: bank Signal, move to the next season.
func harvest() -> void:
	signal_pts += signal_gain()
	stats["harvests"] = int(stats["harvests"]) + 1
	season += 1
	if season >= SEASON_COUNT:
		won = true
	new_season()


func wipe() -> void:
	signal_pts = 0
	signal_upgrades = {}
	season = 0
	won = false
	intro_done = false
	stats = {"circles": 0, "perfect": 0, "cows": 0, "golden": 0, "spins": 0, "jackpots": 0, "earned": 0.0, "best": 0.0, "harvests": 0}
	new_season()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------- save/load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"season": season,
		"season_earned": season_earned,
		"signal": signal_pts,
		"aliens": aliens,
		"upgrades": upgrades,
		"signal_upgrades": signal_upgrades,
		"won": won,
		"intro_done": intro_done,
		"goal_announced": goal_announced,
		"stats": stats,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	money = float(d.get("money", 0.0))
	season = int(d.get("season", 0))
	season_earned = float(d.get("season_earned", 0.0))
	signal_pts = int(d.get("signal", 0))
	aliens = _ints(d.get("aliens", {}))
	upgrades = _ints(d.get("upgrades", {}))
	signal_upgrades = _ints(d.get("signal_upgrades", {}))
	won = bool(d.get("won", false))
	intro_done = bool(d.get("intro_done", false))
	goal_announced = bool(d.get("goal_announced", false))
	var s: Variant = d.get("stats", {})
	if typeof(s) == TYPE_DICTIONARY:
		for k in s:
			stats[k] = s[k]
	changed.emit()
	return true


func _ints(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for k in v:
			out[str(k)] = int(v[k])
	return out


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"crt": crt_amount, "sfx": sfx_volume, "music": music_volume,
			"cursor": cursor, "fullscreen": fullscreen, "shake": screen_shake,
		}))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			var d: Dictionary = parsed
			crt_amount = clampf(float(d.get("crt", crt_amount)), 0.0, 1.0)
			sfx_volume = clampf(float(d.get("sfx", sfx_volume)), 0.0, 1.0)
			music_volume = clampf(float(d.get("music", music_volume)), 0.0, 1.0)
			cursor = str(d.get("cursor", cursor))
			if not cursor in CURSORS:
				cursor = "hand"
			fullscreen = bool(d.get("fullscreen", false))
			screen_shake = bool(d.get("shake", true))
	apply_settings()


func apply_settings() -> void:
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


static func fmt(n: float) -> String:
	if n < 1000.0:
		if n < 10.0 and n != floor(n):
			return "%.2f" % n
		if n < 100.0 and n != floor(n):
			return "%.1f" % n
		return str(int(n))
	var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"]
	var i := -1
	while n >= 1000.0 and i < suffixes.size() - 1:
		n /= 1000.0
		i += 1
	return "%.2f%s" % [n, suffixes[i]]
