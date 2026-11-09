class_name ActionData
extends RefCounted

## Eine Aktion, die ein Bauteil gewaehrt. Passive Teile gewaehren keine.
##
## Schaden ist deterministisch: kein Trefferwurf, kein Krit, keine Ausweich-
## chance. Derselbe Seed ergibt denselben Kampf.

## ANGRIFF ist das, was eine Waffe in ihrem Takt tut; FAEHIGKEIT alles, was
## darueber hinausgeht und nach seinem Ausloeser kommt (trigger_*).
enum Category { ATTACK, ABILITY }

## AOE_AROUND_TARGET trifft den vollen Ring (Chebyshev-Radius, „8 angrenzende
## Felder" bei Radius 1). AOE_CROSS trifft nur ORTHOGONAL (Ziel + die geraden
## Nachbarn) -- die Kreuzform des Runenstabs („4 angrenzende Felder orthogonal").
##
## DASH ist die einzige BEWEGUNGS-Aktion: sie zielt auf ein LEERES Feld und
## versetzt den Handelnden selbst dorthin -- gerade Linie, ``range_tiles`` weit,
## nicht durch andere DROMEs (der Hologramm-Boost). Kein Ziel, kein Schaden.
enum Targeting { SINGLE, AOE_AROUND_TARGET, AOE_CROSS, DASH }

const CATEGORY_NAMES := {"attack": Category.ATTACK, "ability": Category.ABILITY}
const CATEGORY_LABEL := {Category.ATTACK: "Angriff", Category.ABILITY: "Faehigkeit"}
const TARGETING_NAMES := {
	"single": Targeting.SINGLE,
	"aoe_around_target": Targeting.AOE_AROUND_TARGET,
	"aoe_cross": Targeting.AOE_CROSS,
	"dash": Targeting.DASH,
}


var id: StringName
var display_name: String
var category: Category = Category.ATTACK

## Wo diese Aktion herkommt. Rein fuer die Anzeige: der Spieler soll im Kampf
## sehen, welches Bauteil ihm diese Zeile gibt.
var source_part_name: String = ""
var source_part_code: String = ""

## Anteil des Schadens, der ENERGIESCHADEN ist (0.0 = ganz physisch, 1.0 = ganz
## Energie, 0.5 = halb/halb wie der Puls-Blaster). Energie knackt Schilde,
## Physisch prallt an ihnen ab -- siehe §11 und ActionResolver.resolve_damage().
var energy_fraction: float = 0.0
var targeting: Targeting = Targeting.SINGLE
var range_tiles: int = 1
var aoe_radius: int = 0

## Schaden je Treffer (vor ATK, Schild und Panzerung).
var power: int = 0

## positiv = wegstossen, negativ = heranziehen
var push_tiles: int = 0

## Echtzeit (Nov. 2026): Sekunden zwischen zwei Angriffen dieser Waffe. Nur
## fuer Angriffe; jede Waffe laedt fuer sich nach.
var interval: float = 2.0

## Wann eine Faehigkeit von selbst ausloest. Faehigkeiten werden nicht mehr
## gezogen, sie kommen nach einer festen Regel:
##
##   attacks   jeder ``trigger_every``-te Angriff der Waffe ``trigger_weapon``
##             IST die Faehigkeit (sie ersetzt diesen Angriff).
##   time      alle ``trigger_every`` Sekunden, sobald ein Ziel in Reichweite ist.
##   adjacent  wenn ein Gegner direkt danebensteht, hoechstens alle
##             ``trigger_every`` Sekunden.
## Schadensfaktor am SCHILD (Schildbrecher des Neon-Blasters: 2.0). Auf die
## Integritaet wirkt er nicht.
var shield_mult: float = 1.0

## Treffer je Ausloesen. Mehr als einer verteilt sich auf bis zu so viele
## Gegner in Reichweite, der Rest geht wieder aufs Ziel (Doppelschuss).
var shots: int = 1

## Flaeche: zieht die Gegner im Radius zuerst zum Zielfeld heran (Vortex).
var gather: bool = false

## Sekunden zwischen Ausloesen und Schaden. Der Sog wirkt sofort, die
## Schockwelle danach (ActionResolver.advance).
var delay: float = 0.0

## Statuseffekt auf jeden Getroffenen, z. B. {"id": "slow", "seconds": 2.5,
## "move_mult": 0.6}. Leer = keiner.
var status: Dictionary = {}
## Unterstuetzung (7. Nov. 2026, Deflektor und Drohnen-Pod): ``heal`` repariert
## Integritaet, ``shield_gain`` gibt Schild (bis Maximum + shield_gain). Wen:
## ``support`` = "self" (der Traeger) oder "ally" (der Verbuendete mit dem
## geringsten Anteil Integritaet in Reichweite, auch der Traeger). Ein Angriff
## mit ``heal`` heilt einen verletzten Verbuendeten und schiesst sonst mit
## ``power`` auf Gegner.
var heal: int = 0
var shield_gain: int = 0
var support: String = ""

var trigger_kind: String = ""
var trigger_every: float = 0.0
var trigger_weapon: StringName = &""

## Modul Koedersender: die Faehigkeit lockt ihr Ziel so viele Sekunden auf
## den Traeger. 0 = nicht.
var taunt_seconds: float = 0.0

## Module (MODULE_KONZEPT.md), als Kopie gesetzt (with_modules):
## Ueberspannung -- solange der Schild des Traegers steht, wird dieser Anteil
## des kinetischen Schadens zu Energie (ActionResolver.apply_damage).
var kinetic_to_energy: float = 0.0
## Zielsucher: Angriffe gegen markierte Gegner +Anteil Schaden.
var bonus_vs_marked: float = 0.0
## Rammbock: Angriffe +Anteil der eigenen Panzerung als Schaden, ohne Power
## (Unit.raw_damage).
var armor_to_damage: float = 0.0

## Faehigkeitsschaden als Anteil des Waffenschadens (8. Nov. 2026). power ist
## daraus schon berechnet; der Anteil bleibt fuer die Anzeige.
var damage_pct: float = 0.0
var base_action: StringName = &""


static func from_meta(meta: Dictionary, owner_name: String = "",
		owner_code: String = "") -> ActionData:
	var action := ActionData.new()
	action.id = StringName(meta.get("id", ""))
	action.display_name = meta.get("display_name", owner_name)
	action.source_part_name = owner_name
	action.source_part_code = owner_code
	action.category = CATEGORY_NAMES.get(meta.get("category", "attack"), Category.ATTACK)
	action.targeting = TARGETING_NAMES.get(meta.get("targeting", "single"), Targeting.SINGLE)
	action.range_tiles = meta.get("range_tiles", 1)
	action.aoe_radius = meta.get("aoe_radius", 0)
	action.power = meta.get("power", 0)
	action.push_tiles = meta.get("push_tiles", 0)
	action.energy_fraction = float(meta.get("energy_fraction", 0.0))
	action.interval = float(meta.get("interval", 2.0))
	action.gather = bool(meta.get("gather", false))
	action.shots = maxi(1, int(meta.get("shots", 1)))
	action.shield_mult = float(meta.get("shield_mult", 1.0))
	action.delay = float(meta.get("delay", 0.0))
	action.heal = int(meta.get("heal", 0))
	action.shield_gain = int(meta.get("shield_gain", 0))
	action.support = str(meta.get("support", ""))
	action.damage_pct = float(meta.get("damage_pct", 0.0))
	action.base_action = StringName(str(meta.get("base_action", "")))
	var status_meta = meta.get("status")
	if status_meta is Dictionary:
		action.status = status_meta
	var trigger = meta.get("trigger")
	if trigger is Dictionary:
		action.trigger_kind = str(trigger.get("kind", ""))
		action.trigger_every = float(trigger.get("every", 0.0))
		action.trigger_weapon = StringName(str(trigger.get("weapon", "")))
	return action


## Eine eigene Kopie -- die Aktionen der PartDB teilen sich alle DROMEs mit
## diesem Teil, Module duerfen sie deshalb nie direkt aendern.
func copy() -> ActionData:
	var out := ActionData.new()
	for property in get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = get(property["name"])
			out.set(property["name"], value.duplicate(true) if value is Dictionary else value)
	return out


## Die Aktion mit den Wirkungen der Module eines Halters (ModuleData).
## Ohne Wirkung die Aktion selbst, sonst eine Kopie.
##
## Angriffstempo, Schaden, Reichweite, Zielsucher und Rammbock wirken nur
## auf Angriffe; Takt, Wirkung (Verstaerker) und Locken nur auf
## Faehigkeiten; Statusdauer und Ueberspannung auf beides.
func with_modules(fx: Dictionary) -> ActionData:
	if fx.is_empty():
		return self
	var out := copy()
	if is_attack():
		var speed := float(fx.get("attack_speed", 0.0))
		if speed > 0.0:
			out.interval = interval / (1.0 + speed)
		var more := float(fx.get("attack_power", 0.0))
		if more > 0.0 and power > 0:
			out.power = int(round(float(power) * (1.0 + more)))
		out.range_tiles += int(fx.get("range", 0))
		out.bonus_vs_marked = float(fx.get("bonus_vs_marked", 0.0))
		out.armor_to_damage = float(fx.get("armor_to_damage", 0.0))
	else:
		# Treffer-Takt: Taktchip zaehlt jeden Angriff mehr (Unit.takt_step),
		# hier aendert sich nur der Zeit-Takt.
		var faster := float(fx.get("takt_time", 0.0))
		if trigger_kind == "time" and faster > 0.0:
			out.trigger_every = trigger_every * maxf(0.2, 1.0 - faster)
		# Koedersender: ein Exemplar 2 s, jedes weitere +1 s.
		var taunt := float(fx.get("taunt", 0.0))
		out.taunt_seconds = 1.0 + taunt if taunt > 0.0 else 0.0
		# Verstaerker: Faehigkeit +Anteil Wirkung.
		var stronger := float(fx.get("ability_power", 0.0))
		if stronger > 0.0:
			out.power = int(round(float(power) * (1.0 + stronger)))
			out.heal = int(round(float(heal) * (1.0 + stronger)))
			out.shield_gain = int(round(float(shield_gain) * (1.0 + stronger)))
	out.kinetic_to_energy = float(fx.get("kinetic_to_energy", 0.0))
	var longer := float(fx.get("status_time", 0.0))
	if longer > 0.0 and status.has("seconds"):
		out.status["seconds"] = float(status["seconds"]) * (1.0 + longer)
	return out


## Der Takt (die Ausloesevoraussetzung) in Klartext -- fuer Teil-Info und Kacheln.
func trigger_text() -> String:
	match trigger_kind:
		"attacks":
			return "jeder %d. Angriff" % int(trigger_every)
		"time":
			return "alle %s s" % _seconds(trigger_every)
		"adjacent":
			return "wenn ein Gegner direkt daneben steht (hoechstens alle %s s)" \
				% _seconds(trigger_every)
	return ""


## Der Statuseffekt in Klartext: "verlangsamt 40 % fuer 2,5 s".
func status_text() -> String:
	if status.is_empty():
		return ""
	var seconds := _seconds(float(status.get("seconds", 0.0)))
	match str(status.get("id", "")):
		"slow":
			var cut := int(round((1.0 - float(status.get("move_mult", 1.0))) * 100.0))
			return "verlangsamt um %d %% fuer %s s" % [cut, seconds]
		"stun":
			return "betaeubt fuer %s s" % seconds
		"vulnerable":
			var more := int(round((float(status.get("damage_taken_mult", 1.0)) - 1.0) * 100.0))
			return "verwundbar: nimmt %d %% mehr Schaden fuer %s s" % [more, seconds]
	return "%s fuer %s s" % [str(status.get("id", "Effekt")), seconds]


static func _seconds(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return ("%.1f" % value).replace(".", ",")


func is_attack() -> bool:
	return category == Category.ATTACK


## Eine Bewegungs-Aktion (Dash): sie versetzt den Handelnden selbst, statt ein
## Ziel zu treffen. Der Resolver behandelt sie deshalb in einem eigenen Zweig,
## und die Schadensvorschau meldet fuer sie 0.
func is_move() -> bool:
	return targeting == Targeting.DASH


func category_label() -> String:
	return CATEGORY_LABEL.get(category, "Aktion")


## Was diese Aktion tut, wenn sie KEINE Wirkungsmenge hat -- Stossen, Ziehen. Steht dort, wo sonst die Schadenszahl steht: "0 Schaden" waere
## richtig gerechnet und trotzdem eine Falschauskunft ueber die Aktion.
func effect_summary() -> String:
	var parts: Array[String] = []
	if is_move():
		parts.append("Boost %d gerade" % range_tiles)
	if gather:
		parts.append("zieht zusammen")
	if push_tiles > 0:
		parts.append("stoesst %d" % push_tiles)
	elif push_tiles < 0:
		parts.append("zieht %d heran" % absi(push_tiles))
	if heal > 0:
		parts.append("repariert %d" % heal)
	if shield_gain > 0:
		parts.append("+%d Schild" % shield_gain)
	return " · ".join(parts) if not parts.is_empty() else "ohne Schaden"


## Kurzform fuer eine Zeile: "Angriff · Rw 4".
func headline() -> String:
	var parts: Array[String] = [category_label(), "Rw %d" % range_tiles]
	return " · ".join(parts)


## Was diese Aktion tut, vollstaendig und in Klartext.
##
## Die EINE Beschreibung -- Tooltips lesen hier.
func description_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s · Reichweite %d" % [category_label(), range_tiles])
	if is_move():
		lines.append("Boost: bis %d Felder gerade" % range_tiles)
	if power > 0:
		lines.append("Staerke %d" % power)
	if shots > 1:
		lines.append("%d Treffer auf bis zu %d Gegner" % [shots, shots])
	if shield_mult > 1.0:
		lines.append("%d %% Schaden am Schild" % int(round(shield_mult * 100.0)))
	if aoe_radius > 0:
		lines.append("Flaeche: Radius %d um das Ziel" % aoe_radius)
	if gather:
		lines.append("zieht die Gegner im Radius zum Ziel heran")
	if delay > 0.0:
		lines.append("Schaden nach %s s" % _seconds(delay))
	if not status.is_empty():
		lines.append(status_text())
	if push_tiles > 0:
		lines.append("stoesst %d Feld(er) zurueck" % push_tiles)
	elif push_tiles < 0:
		lines.append("zieht %d Feld(er) heran" % absi(push_tiles))
	if heal > 0:
		lines.append("repariert %d beim Verletztesten" % heal)
	if shield_gain > 0:
		lines.append("+%d Schild %s" % [shield_gain,
			"fuer sich" if support == "self" else "fuer den Verletztesten"])
	if source_part_name != "":
		lines.append("aus: %s%s" % [source_part_name,
			" (%s)" % source_part_code if source_part_code != "" else ""])
	return lines


func _to_string() -> String:
	return "ActionData(%s)" % id
