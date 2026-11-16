class_name Defs
extends RefCounted
## All shop data in one place. Prices: base * growth^level.
## Balance knobs live here and in game.gd (formulas).

const ALIENS: Array = [
	{"id": "greeblet", "name": "Greeblet", "icon": "greeblet", "base": 20.0, "growth": 1.15,
		"desc": "Small, keen, slightly sticky. Walks little circles in the wheat."},
	{"id": "spinner", "name": "Spinner", "icon": "spinner", "base": 260.0, "growth": 1.15,
		"desc": "Spins big rings. Gets dizzy. Does it anyway."},
	{"id": "tracer", "name": "Tracer", "icon": "tracer", "base": 2200.0, "growth": 1.16,
		"desc": "An artist. Copies your last crop circle somewhere else, or draws stars and polygons."},
	{"id": "glowie", "name": "Glowie", "icon": "glowie", "base": 14000.0, "growth": 1.18,
		"desc": "Wanders around glowing. Circles near a Glowie pay +100% per Glowie."},
	{"id": "saucer", "name": "Saucer", "icon": "saucer", "base": 110000.0, "growth": 1.2,
		"desc": "Hovers in and beams a huge, perfect crop circle straight down."},
]

const UPGRADES: Array = [
	{"id": "hand", "name": "Bigger Hand", "icon": "hand", "base": 50.0, "growth": 4.0, "max": 6,
		"desc": "Your stomping hand gets wider."},
	{"id": "fertilizer", "name": "Premium Wheat", "icon": "fertilizer", "base": 80.0, "growth": 1.9, "max": -1,
		"desc": "+35% money for every stalk inside a circle."},
	{"id": "boots", "name": "Rocket Boots", "icon": "boots", "base": 140.0, "growth": 2.0, "max": 15,
		"desc": "Aliens walk 20% faster."},
	{"id": "memory", "name": "Long Exposure", "icon": "memory", "base": 220.0, "growth": 2.0, "max": 10,
		"desc": "Crop circles last 4 seconds longer before the wheat grows back."},
	{"id": "geometry", "name": "Sacred Geometry", "icon": "geometry", "base": 400.0, "growth": 2.4, "max": 10,
		"desc": "Round, Perfect and Bullseye bonuses are 25% bigger."},
	{"id": "tourists", "name": "Tourist Bus", "icon": "tourists", "base": 600.0, "growth": 2.2, "max": -1,
		"desc": "Tourists pay to look at your circles. Every circle earns money each second while it lasts."},
	{"id": "combo", "name": "Chain Reaction", "icon": "combo", "base": 900.0, "growth": 2.5, "max": 8,
		"desc": "Longer combo window and +10% more per combo step."},
	{"id": "golden", "name": "Golden Seeds", "icon": "golden", "base": 1200.0, "growth": 2.3, "max": 10,
		"desc": "More golden wheat appears. Circle it for a fat bonus."},
	{"id": "magnet", "name": "Cow Magnet", "icon": "magnet", "base": 2500.0, "growth": 3.0, "max": 6,
		"desc": "One more cow wanders the field. Circle a cow to abduct it: x2 money."},
	{"id": "antenna", "name": "Lucky Antenna", "icon": "antenna", "base": 3500.0, "growth": 3.0, "max": 8,
		"desc": "Better odds on the Mothership Slot."},
]

## Bought with Signal (earned at harvest). Never reset.
const SIGNAL: Array = [
	{"id": "boost", "name": "Signal Booster", "icon": "signal", "base": 1.0, "growth": 1.6, "max": -1,
		"desc": "+50% money from everything. Stacks."},
	{"id": "seed", "name": "Seed Money", "icon": "coin", "base": 2.0, "growth": 2.0, "max": 10,
		"desc": "Start each season with more money."},
	{"id": "crew", "name": "Veteran Crew", "icon": "crew", "base": 3.0, "growth": 2.0, "max": 10,
		"desc": "Start each season with 2 free Greeblets per level."},
	{"id": "quick", "name": "Long Arms", "icon": "hand", "base": 4.0, "growth": 3.0, "max": 4,
		"desc": "Your hand starts one size bigger."},
	{"id": "lucky", "name": "Lucky Frequency", "icon": "lucky", "base": 5.0, "growth": 2.5, "max": 5,
		"desc": "Better slot odds and more golden wheat, forever."},
]

const SEASONS: Array = [
	"Spring", "Summer", "Late Summer", "Harvest Moon", "Autumn", "First Frost", "The Last Field",
]


static func find(list: Array, id: String) -> Dictionary:
	for d in list:
		if d["id"] == id:
			return d
	return {}


static func cost(def: Dictionary, lvl: int) -> float:
	return float(def["base"]) * pow(float(def["growth"]), lvl)
