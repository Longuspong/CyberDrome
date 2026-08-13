class_name TurnState
extends RefCounted

## Die Budgets des aktiven Zuges.
##
## Sie sind frei mischbar und die Bewegung ist beliebig aufteilbar:
##
##     2 Felder gehen -> angreifen -> 1 Feld gehen -> Faehigkeit -> gehen
##
## Der Zug endet NUR durch "Zug beenden", nie automatisch -- auch dann nicht,
## wenn alle Budgets aufgebraucht sind. Der Button wird dann nur hervorgehoben.

var unit: Unit

var move_points: int = 0
var attack_actions: int = 0
var ability_actions: int = 0

## Solange in diesem Zug noch keine Aktion ausgefuehrt wurde, kann Bewegung
## zurueckgenommen werden. Nach der ersten Aktion ist der Zug committed --
## sonst liesse sich ein Angriff ausprobieren und die Bewegung danach
## zurechtruecken.
var committed: bool = false

## Ausgangszustand fuer das Zuruecknehmen.
var start_tile: Vector2i
var start_move_points: int = 0


static func begin(for_unit: Unit) -> TurnState:
	var state := TurnState.new()
	state.unit = for_unit
	state.move_points = for_unit.stat("mov")
	state.attack_actions = 1
	state.ability_actions = 1
	state.start_tile = for_unit.tile
	state.start_move_points = state.move_points
	return state


func can_move() -> bool:
	return move_points > 0


func spend_movement(cost: int) -> void:
	move_points = maxi(0, move_points - cost)


func can_use(action: ActionData) -> bool:
	return actions_left(action.category) > 0


## Wie viel von diesem Budget noch da ist. Die Aktionsleiste schreibt die Zahl
## ueber die Gruppe -- "Angriff (0)" sagt in einem Blick, was "Angriff
## verbraucht" erst nach dem Hovern verraet.
func actions_left(category: ActionData.Category) -> int:
	return attack_actions if category == ActionData.Category.ATTACK \
		else ability_actions


## Warum geht diese Aktion nicht? Leerer String = sie geht.
## Der Aktionsring zeigt diesen Text als Grund am ausgegrauten Eintrag.
func blocker_for(action: ActionData) -> String:
	if not can_use(action):
		return "Angriff verbraucht" if action.category == ActionData.Category.ATTACK \
			else "Faehigkeit verbraucht"
	# Die Abklingzeit steht VOR der Energie. Im Modus ``abklingzeit`` kostet die
	# Aktion gar nichts, und "Energie: 70/0" waere als Sperrgrund Unsinn; im
	# Modus ``beides`` ist die Wartezeit die Sperre, die der Spieler nicht durch
	# Nachladen aufloesen kann -- also die, die er zuerst lesen muss.
	if unit != null and unit.cooldown_left(action) > 0:
		return "Abklingzeit: noch %d Zug/Zuege" % unit.cooldown_left(action)
	if unit != null and unit.en < action.en_cost_now():
		return "Energie: %d/%d" % [unit.en, action.en_cost_now()]
	return ""


func consume(action: ActionData) -> void:
	if action.category == ActionData.Category.ATTACK:
		attack_actions = maxi(0, attack_actions - 1)
	else:
		ability_actions = maxi(0, ability_actions - 1)
	# Die Abklingzeit beginnt hier und nicht im ActionResolver: sie gehoert zum
	# BUDGET des Zuges und nicht zur Wirkung der Aktion. Der Resolver wendet
	# Schaden an, auch ohne dass jemand am Zug ist (Aderlass) -- eine Wartezeit
	# haette dort keinen Zug, in dem sie ablaufen koennte.
	if unit != null:
		unit.start_cooldown(action)
	committed = true


func can_undo_movement() -> bool:
	return not committed and unit != null and unit.tile != start_tile


func budgets_spent() -> bool:
	return move_points <= 0 and attack_actions <= 0 and ability_actions <= 0


func _to_string() -> String:
	return "TurnState(%s mp=%d atk=%d abl=%d%s)" % [
		unit.unit_id if unit else "-", move_points, attack_actions,
		ability_actions, " committed" if committed else ""]
