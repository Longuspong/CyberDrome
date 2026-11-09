class_name ModuleData
extends RefCounted

## Ein Modul (NEUANFANG 6g): gibt es nur im Lauf, veraendert, wie eine Waffe
## funktioniert.
##
## Module stecken im WAFFENHALTER eines DROME (DromeBuild.modules) und wirken
## auf die Waffe, die gerade darin sitzt. Tauscht man die Waffe, bleiben die
## Module im Halter -- passt die neue Waffe nicht zur Bedingung (z. B. nur
## Fernwaffen), ruhen sie, bis wieder eine passende drinsteckt.
##
## Keine Stufen: staerker werden Module nur durch Rezepte. Ein Rezept-Modul
## hat die SUMME der Wirkungen seiner Zutaten plus einen eigenen Effekt.
##
## Der Katalog steht in data/modules.json; diese Klasse haelt ihn als
## statischen Zwischenspeicher (wie Config), damit RunState, DromeBuild und
## der Kampf ohne Autoload darauf zugreifen.

const PATH := "res://data/modules.json"

## Symbole: assets/modules/<modul-id>.svg (oder data/modules.json -> icon).
## Fehlt die Datei, zeigt der Chip zwei Buchstaben (short).
const ICON_DIR := "res://assets/modules/"

const CLASS_LABEL := {"attack": "Angriff", "defense": "Abwehr", "tactic": "Taktik"}
const CONDITION_LABEL := {"ranged": "nur Fernwaffen", "melee": "nur Nahkampfwaffen"}

## Farbe je Klasse -- fuer die Modul-Kacheln (rot Angriff, blau Abwehr,
## gelb Taktik).
const CLASS_COLOR := {
	"attack": Color(1.0, 0.45, 0.4),
	"defense": Color(0.4, 0.7, 1.0),
	"tactic": Color(1.0, 0.82, 0.35),
}

var id: StringName = &""
var display_name: String = ""
## Zwei Buchstaben fuer den Chip (data/modules.json -> short).
var short: String = ""
## Pfad zum eigenen Symbol, leer = assets/modules/<id>.svg.
var icon_path: String = ""
var _icon: Texture2D
var _icon_checked: bool = false
var klass: String = "attack"
var condition: String = ""
## Alle Wirkungen zusammen -- beim Rezept-Modul Summe der Zutaten plus bonus.
var effects: Dictionary = {}
## Nur Rezept-Module: die Zutaten und der eigene Effekt.
var from: Array = []
var bonus: Dictionary = {}

static var _data: Dictionary = {}
static var _modules: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_load()
	return _data


static func _load() -> void:
	_modules.clear()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("ModuleData: %s nicht lesbar" % PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("ModuleData: %s ist kein JSON-Objekt" % PATH)
		return
	_data = parsed
	var base: Dictionary = _data.get("modules", {})
	for key in base:
		_modules[StringName(key)] = _from_meta(StringName(key), base[key])
	var recipes: Dictionary = _data.get("recipes", {})
	for key in recipes:
		var meta: Dictionary = recipes[key]
		var module := _from_meta(StringName(key), meta)
		module.effects = {}
		for ingredient in meta.get("from", []):
			module.from.append(StringName(ingredient))
			var part: ModuleData = _modules.get(StringName(ingredient))
			if part != null:
				module.effects = add_effects(module.effects, part.effects)
		module.bonus = meta.get("bonus", {})
		module.effects = add_effects(module.effects, module.bonus)
		_modules[module.id] = module


static func _from_meta(key: StringName, meta: Dictionary) -> ModuleData:
	var module := ModuleData.new()
	module.id = key
	module.display_name = str(meta.get("name", key))
	module.short = str(meta.get("short", ""))
	module.icon_path = str(meta.get("icon", ""))
	module.klass = str(meta.get("class", "attack"))
	module.condition = str(meta.get("condition", ""))
	module.effects = meta.get("effects", {}).duplicate()
	return module


static func reload() -> void:
	_data = {}
	_load()


## Zahlen addieren sich, Schalter (true) bleiben an.
static func add_effects(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for key in b:
		var value = b[key]
		if value is bool:
			out[key] = bool(out.get(key, false)) or value
		else:
			out[key] = float(out.get(key, 0.0)) + float(value)
	return out


## Alle Module, aus denen dieses besteht -- es selbst eingeschlossen, Rezepte
## als Zutat aufgeloest (Taktgeber -> Taktchip -> Zeiger, Schaltkreis).
func parts() -> Array:
	var out: Array = [id]
	for ingredient in from:
		var module := get_module(ingredient)
		if module != null:
			out.append_array(module.parts())
	return out


static func get_module(module_id) -> ModuleData:
	if module_id == null:
		return null
	data()
	return _modules.get(StringName(str(module_id)))


## Ist diese Kennung ein Modul (und kein Bauteil)? Lager und Belohnungen
## mischen beides.
static func is_module(item_id) -> bool:
	return get_module(item_id) != null


## Die Grundmodule (ohne Rezepte), in der Reihenfolge der Datei.
static func base_modules() -> Array:
	var out: Array = []
	for key in data().get("modules", {}):
		out.append(_modules[StringName(key)])
	return out


## Die Rezept-Module, in der Reihenfolge der Datei.
static func recipes() -> Array:
	var out: Array = []
	for key in data().get("recipes", {}):
		out.append(_modules[StringName(key)])
	return out


## Das Symbol des Moduls, null wenn es keins gibt (dann Buchstaben).
func icon() -> Texture2D:
	if not _icon_checked:
		_icon_checked = true
		var path := icon_path if icon_path != "" else ICON_DIR + str(id) + ".svg"
		if ResourceLoader.exists(path):
			_icon = load(path) as Texture2D
	return _icon


func is_recipe() -> bool:
	return not from.is_empty()


## Wie viele Module ein Halter dieses DROME fasst: 3, Molok 2 (6g).
## Modulplaetze je Waffenhalter: ein Wert des DROME (Chassis, 8. Nov. 2026).
## Fehlt er (alte Daten), gilt modules.json -> slots.
static func slots_for(build: DromeBuild) -> int:
	if build != null:
		var own := int(build.stats().get("module_slots", 0))
		if own > 0:
			return own
	return int(data().get("slots", 3))


static func sell_value(module: ModuleData) -> int:
	if module == null:
		return 0
	var values: Dictionary = data().get("sell_value", {})
	return int(values.get("recipe" if module.is_recipe() else "base", 2))


## Warum das Modul an dieser Waffe ruht -- leer, wenn es wirkt.
func blocker(part: PartData) -> String:
	if part == null:
		return "keine Waffe im Halter"
	if condition == "":
		return ""
	var reach := attack_range(part)
	if reach <= 0:
		return "die Waffe greift nicht an"
	if condition == "ranged" and reach < 2:
		return CONDITION_LABEL["ranged"]
	if condition == "melee" and reach > 1:
		return CONDITION_LABEL["melee"]
	return ""


func fits(part: PartData) -> bool:
	return blocker(part) == ""


## Reichweite des Angriffs einer Waffe -- 0, wenn sie keinen hat.
static func attack_range(part: PartData) -> int:
	if part == null:
		return 0
	for action in part.actions:
		if action.is_attack():
			return action.range_tiles
	return 0


func class_label() -> String:
	return CLASS_LABEL.get(klass, klass)


func color() -> Color:
	return CLASS_COLOR.get(klass, Color.WHITE)


## Zwei Buchstaben fuer die Kachel: "SF" fuer Schnellfeuer.
func short_name() -> String:
	if short != "":
		return short
	var words := display_name.replace("-", " ").split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	return display_name.substr(0, 2).to_upper()


## Was das Modul tut, eine Zeile je Wirkung.
func effect_lines(which: Dictionary = {}) -> Array[String]:
	var source := effects if which.is_empty() else which
	var lines: Array[String] = []
	for key in source:
		var line := effect_text(str(key), source[key])
		if line != "":
			lines.append(line)
	return lines


## Nur der eigene Effekt eines Rezepts.
func bonus_lines() -> Array[String]:
	return effect_lines(bonus) if not bonus.is_empty() else [] as Array[String]


static func effect_text(key: String, value) -> String:
	var v := float(value) if not value is bool else 0.0
	match key:
		"attack_speed":
			return "+%d %% Angriffstempo" % _pct(v)
		"attack_power":
			return "+%d %% Schaden der Angriffe" % _pct(v)
		"range":
			return "+%d Reichweite" % int(v)
		"ricochet_chance":
			return "%d %% Chance: Querschlaeger aufs selbe Ziel" % _pct(v)
		"ricochet_share":
			return "Querschlaeger mit %d %% Schaden" % _pct(v)
		"def":
			return "+%d Panzerung" % int(v)
		"shield":
			return "+%d Schild" % int(v)
		"thorns":
			return "Nahkampf-Angreifer nehmen %d Schaden je Treffer" % int(v)
		"takt_cut":
			return "Faehigkeit %d Angriff frueher" % int(v)
		"takt_time":
			return "Zeit-Takt %d %% kuerzer" % _pct(v)
		"status_time":
			return "Statuseffekte %d %% laenger" % _pct(v)
		"taunt":
			return "Faehigkeit lockt ihr Ziel %s s auf den Traeger" % _seconds(v)
		"field_shot_every":
			return "jeder %d. Angriff trifft dazu einen Gegner irgendwo auf dem Feld" % int(v)
		"shield_delay":
			return "Schild laedt schon nach %s s Ruhe" % _seconds(v)
		"ready_after_ability":
			return "nach der Faehigkeit sofort wieder geladen" if value else ""
		"retaliation":
			return "Vergeltung: jeder Nahkampftreffer am Traeger laedt den naechsten Angriff um %d %% auf (bis 3x)" % _pct(v)
		"shackle":
			return "Fesselkette: Faehigkeit zieht bis zu %d Gegner (Rw 3) heran und betaeubt sie 1 s" % int(v)
		"cleave":
			return "Rundumschlag: trifft dazu alle Gegner direkt neben dem Traeger mit %d %% Schaden" % _pct(v)
	return ""


static func _pct(value: float) -> int:
	return int(round(value * 100.0))


static func _seconds(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return ("%.1f" % value).replace(".", ",")


## Kurzer Klartext fuer Belohnung und Lager: "Angriff · nur Fernwaffen".
func headline() -> String:
	var parts: Array[String] = ["Modul", class_label()]
	if condition != "":
		parts.append(CONDITION_LABEL.get(condition, condition))
	return " · ".join(parts)


func _to_string() -> String:
	return "ModuleData(%s)" % id
