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

const CLASS_LABEL := {"attack": "Angriff", "defense": "Abwehr", "tactic": "Taktik",
	"bios": "Matrix-BIOS"}
const CONDITION_LABEL := {"ranged": "nur Fernwaffen", "melee": "nur Nahkampfwaffen"}

## Farbe je Klasse -- fuer die Modul-Kacheln (rot Angriff, blau Abwehr,
## gelb Taktik).
const CLASS_COLOR := {
	"attack": Color(1.0, 0.45, 0.4),
	"defense": Color(0.4, 0.7, 1.0),
	"tactic": Color(1.0, 0.82, 0.35),
	"bios": Color(0.78, 0.55, 1.0),
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
## Eigene Faehigkeit des Moduls (modules.json -> gadgets), leer = keine.
var gadget: StringName = &"" 
var bonus: Dictionary = {}

## Matrix-BIOS (MODULE_KONZEPT.md 6). Ein BIOS-Gegenstand hat ``bios_kind``
## "chassis" (fuer ``bios_chassis``) oder "recipe" (verwandelt ``bios_recipe``
## in ``bios_result``); er steckt nie in einem Halter.
var bios_kind: String = ""
var bios_chassis: StringName = &""
var bios_recipe: StringName = &""
var bios_result: StringName = &""
var bios_text: String = ""
## Ergebnis eines Rezept-BIOS (Taktgeber ...): ``from`` ist dann das
## Grundrezept, die Wirkung dessen Summe plus ``bonus``.
var is_bios_result: bool = false

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
	var items: Dictionary = _data.get("bios", {})
	for key in items:
		var meta: Dictionary = items[key]
		var item := _from_meta(StringName(key), meta)
		item.klass = "bios"
		item.bios_kind = str(meta.get("kind", ""))
		item.bios_chassis = StringName(str(meta.get("chassis", "")))
		item.bios_recipe = StringName(str(meta.get("recipe", "")))
		item.bios_result = StringName(str(meta.get("result", "")))
		item.bios_text = str(meta.get("text", ""))
		_modules[item.id] = item
	var results: Dictionary = _data.get("bios_recipes", {})
	for key in results:
		var meta: Dictionary = results[key]
		var origin: ModuleData = _modules.get(StringName(str(meta.get("base", ""))))
		var module := _from_meta(StringName(key), meta)
		module.is_bios_result = true
		module.bonus = meta.get("bonus", {})
		if origin != null:
			module.from = [origin.id]
			module.effects = add_effects(origin.effects, module.bonus)
			if not meta.has("condition"):
				module.condition = origin.condition
			if module.gadget == &"":
				module.gadget = origin.gadget
		else:
			module.effects = module.bonus.duplicate()
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
	module.gadget = StringName(str(meta.get("gadget", "")))
	return module


## Die Faehigkeit, die ein Modul mitbringt (modules.json -> gadgets).
static func gadget_action(action_id: StringName) -> ActionData:
	var metas: Dictionary = data().get("gadgets", {})
	if action_id == &"" or not metas.has(str(action_id)):
		return null
	var meta: Dictionary = (metas[str(action_id)] as Dictionary).duplicate()
	meta["id"] = str(action_id)
	return ActionData.from_meta(meta, str(meta.get("display_name", action_id)))


static func reload() -> void:
	_data = {}
	_load()


## Wirkungen, die nicht stapeln: es zaehlt der groesste Wert (Querschlaeger-
## Anteil, Dauer der Markierung, Spruenge, Gabelung, Umwandlung in Energie).
const MAX_KEYS := ["ricochet_share", "mark", "chain_jumps", "ability_fork",
	"kinetic_to_energy", "takt_count", "decoy", "shield_break_burst",
	"retaliation_max", "bonus_vs_unshielded"]
## Wirkungen, bei denen der kleinste Wert zaehlt (Bollwerk: frueher laden;
## Revolverheld: Feldschuss haeufiger als beim Gunslinger).
const MIN_KEYS := ["shield_delay", "field_shot_every", "knockback_every"]


## Zahlen addieren sich, Schalter (true) bleiben an. Ausnahmen: MAX_KEYS und
## MIN_KEYS (zwei Bollwerke im Molok laden nicht spaeter als eins).
static func add_effects(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for key in b:
		var value = b[key]
		if value is bool:
			out[key] = bool(out.get(key, false)) or value
		elif not out.has(key):
			out[key] = float(value)
		elif MAX_KEYS.has(key):
			out[key] = maxf(float(out[key]), float(value))
		elif MIN_KEYS.has(key):
			out[key] = minf(float(out[key]), float(value))
		else:
			out[key] = float(out[key]) + float(value)
	return out


## Feste Zahl einer Modul-Regel (modules.json -> rules).
static func rule(key: String, fallback: float) -> float:
	return float((data().get("rules", {}) as Dictionary).get(key, fallback))


## Alle Module, aus denen dieses besteht -- es selbst eingeschlossen (seit
## 9. Nov. 2026 keine Rezeptketten mehr, die Aufloesung bleibt trotzdem).
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


## Die BIOS-Gegenstaende, in der Reihenfolge der Datei.
static func bios_items() -> Array:
	var out: Array = []
	for key in data().get("bios", {}):
		out.append(_modules[StringName(key)])
	return out


## Die Ergebnisse der Rezept-BIOS (Taktgeber ...).
static func bios_results() -> Array:
	var out: Array = []
	for key in data().get("bios_recipes", {}):
		out.append(_modules[StringName(key)])
	return out


func is_bios_item() -> bool:
	return bios_kind != ""


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
## Mit Chassis-BIOS einer mehr -- beim Molok nur im gewaehlten Halter
## (``slot`` leer = der erste bzw. einzige Halter).
static func slots_for(build: DromeBuild, slot: String = "") -> int:
	var base := int(data().get("slots", 3))
	if build != null:
		var own := int(build.stats().get("module_slots", 0))
		if own > 0:
			base = own
		if build.chassis_bios:
			var chosen := build.bios_slot
			var asked := slot if slot != "" else (build.equip_slots()[0] if not build.equip_slots().is_empty() else "")
			if chosen == "" or chosen == asked:
				base += 1
	return base


static func sell_value(module: ModuleData) -> int:
	if module == null:
		return 0
	var values: Dictionary = data().get("sell_value", {})
	if module.is_bios_item() or module.is_bios_result:
		return int(values.get("bios", 8))
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
	if is_bios_item() and which.is_empty():
		if bios_text != "":
			lines.append(bios_text)
		var result := get_module(bios_result)
		var recipe := get_module(bios_recipe)
		if result != null and recipe != null:
			lines.append("macht aus %s den %s: %s" % [recipe.display_name, result.display_name,
				", ".join(result.effect_lines(result.bonus))])
		return lines
	if which.is_empty() and gadget != &"":
		var action := gadget_action(gadget)
		if action != null:
			lines.append("Faehigkeit %s (%s)" % [action.display_name, action.trigger_text()])
	for key in source:
		var line := effect_text(str(key), source[key])
		if line != "":
			lines.append(line)
	return lines


## Nur der eigene Effekt eines Rezepts.
## Ein Rezept mit eigener Faehigkeit (Orbit-Fokus, Hologramm) nennt sie hier.
func bonus_lines() -> Array[String]:
	var lines: Array[String] = []
	if gadget != &"":
		var action := gadget_action(gadget)
		if action != null:
			lines.append("Faehigkeit %s (%s)" % [action.display_name, action.trigger_text()])
	if not bonus.is_empty():
		lines.append_array(effect_lines(bonus))
	return lines


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
			return "%d %% Chance je Angriff auf einen Zusatztreffer" % _pct(v)
		"ricochet_share":
			return "Zusatztreffer mit %d %% Schaden" % _pct(v)
		"def":
			return "+%d Panzerung" % int(v)
		"shield":
			return "+%d Schild" % int(v)
		"thorns":
			return "Angreifer nehmen %d Schaden je Treffer" % int(v)
		"thorns_melee":
			return "Nahkampf-Angreifer %d mehr" % int(v)
		"ability_power":
			return "Faehigkeit +%d %% Wirkung" % _pct(v)
		"mark":
			return "Faehigkeit markiert ihr Ziel %s s (+%d %% Schaden von allen)" \
				% [_seconds(v), _pct(rule("mark_damage_taken", 0.1))]
		"kinetic_to_energy":
			return "solange der Schild steht: %d %% des kinetischen Schadens wird Energie" % _pct(v)
		"takt_count":
			return "Treffer-Takt: jeder Angriff zaehlt %s" % _seconds(v)
		"bonus_vs_marked":
			return "+%d %% Schaden gegen markierte Ziele" % _pct(v)
		"armor_to_damage":
			return "Angriffe +%d %% der eigenen Panzerung als Schaden" % _pct(v)
		"post_ability_power":
			return "nach der Faehigkeit: naechste %d Angriffe +%d %% Schaden" \
				% [int(rule("overload_attacks", 3)), _pct(v)]
		"thorns_true":
			return "Stacheln gehen am Schild vorbei und koennen Zusatztreffer ausloesen" if value else ""
		"ability_fork":
			return "Faehigkeit trifft dazu ein zweites Ziel mit %d %% Wirkung" % _pct(v)
		"chain_jumps":
			return "Zusatztreffer springen weiter (bis %d), bevorzugt auf Markierte" % int(v)
		"ability_armor_aura":
			return "Faehigkeit: alle in Rw %d +%d Panzerung fuer %s s" \
				% [int(rule("aura_range", 2)), int(v), _seconds(rule("aura_seconds", 4.0))]
		"shield_break_burst":
			return "bricht der Schild: %d Energieschaden an alle in Rw %d, kurz betaeubt" \
				% [int(v), int(rule("burst_range", 2))]
		"decoy":
			return "Koeder lenkt die Nachbarn %s s ab" % _seconds(v)
		"mark_on_hit_taken":
			return "wer den Traeger trifft, wird markiert" if value else ""
		"field_shot_marked":
			return "Feldschuss bevorzugt markierte Gegner" if value else ""
		"retaliation_max":
			return "Vergeltung bis %dx" % int(v)
		"berserk":
			return "volle Vergeltung trifft dazu alle Gegner daneben" if value else ""
		"mark_hunt":
			return "stirbt ein Markierter, springt die Markierung weiter" if value else ""
		"gravity":
			return "das Wurzeln trifft dazu den naechsten Gegner am Ziel" if value else ""
		"root":
			return "Faehigkeit wurzelt ihr Ziel %s s (greift an, bewegt sich nicht)" % _seconds(v)
		"knockback_every":
			return "jeder %d. Angriff stoesst das Ziel 1 Feld zurueck" % int(v)
		"bonus_vs_unshielded":
			return "+%d %% Schaden gegen Gegner ohne Schild" % _pct(v)
		"takt_cut":
			return "Faehigkeit %d Angriff frueher" % int(v)
		"takt_time":
			return "Zeit-Takt %d %% kuerzer" % _pct(v)
		"status_time":
			return "Statuseffekte %d %% laenger" % _pct(v)
		"taunt":
			return "Faehigkeit lockt ihr Ziel %s s auf den Traeger" % _seconds(1.0 + v)
		"field_shot_every":
			return "jeder %d. Angriff trifft dazu einen Gegner irgendwo auf dem Feld" % int(v)
		"shield_delay":
			return "Schild laedt schon nach %s s Ruhe" % _seconds(v)
		"ready_after_ability":
			return "nach der Faehigkeit sofort wieder geladen" if value else ""
		"retaliation":
			return "Vergeltung: jeder Treffer am Traeger laedt den naechsten Angriff um %d %% auf (bis 3x, Nahkampf doppelt)" % _pct(v)
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
	if is_bios_item():
		return "Matrix-BIOS · %s" % ("Chassis" if bios_kind == "chassis" else "Rezept")
	var parts: Array[String] = ["BIOS-Rezept" if is_bios_result else "Modul", class_label()]
	if condition != "":
		parts.append(CONDITION_LABEL.get(condition, condition))
	return " · ".join(parts)


func _to_string() -> String:
	return "ModuleData(%s)" % id
