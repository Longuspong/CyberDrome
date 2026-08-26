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
##
## ### Das Aktions-Modell (GAME_DESIGN §13)
##
## ANGRIFF: jede Waffe bringt einen Angriffs-Aktionspunkt mit. Zwei Waffen sind
## zwei Angriffe -- ``attack_actions`` ist die Zahl der Waffen, ein gemeinsamer
## Vorrat. Zwei gleiche Blaster heissen: dieselbe Puls-Salve zweimal.
##
## FAEHIGKEIT: kein fester Deckel. Jede Faehigkeit im Loadout ist EINMAL PRO ZUG
## ziehbar; wie viele man in einem Zug zieht, entscheidet allein, was man
## bezahlen kann. Die zwei Bremsen sitzen ausserhalb dieses Budgets:
##
##   * die ENERGIE (``en_cost``) fuer energetische Faehigkeiten -- alles
##     rausballern geht, dann ist der Tank leer und braucht ein paar Zuege;
##   * die ABKLINGZEIT (``cooldown_turns``) fuer mechanische -- das Sperrfeuer
##     der Kanone zieht keinen Strom, dafuer geht es nur alle paar Zuege.
##
## Das "einmal pro Zug je Faehigkeit" fuehrt ``used_abilities`` als Menge -- es
## haengt NICHT an der Abklingzeit, damit es in jedem Bremsmodus gilt und auch
## eine stromlose Faehigkeit ohne echte Abklingzeit nicht zweimal im selben Zug
## kommt.

var unit: Unit

var move_points: int = 0

## Ein gemeinsamer Vorrat: so viele Angriffe wie Waffen. Jeder Angriff zieht
## einen ab, egal von welcher Waffe.
var attack_actions: int = 0

## Welche Faehigkeiten in DIESEM Zug schon liefen -- action_id -> true. Eine
## Faehigkeit darin ist fuer den Rest des Zuges verbraucht.
var used_abilities: Dictionary = {}

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
	# Ein Angriff je Waffe (GAME_DESIGN §13). Ohne Waffe null -- die
	# Aktionsleiste bleibt dann leer, und das ist die Entscheidung des Aufbaus.
	state.attack_actions = for_unit.build.attack_budget() if for_unit.build != null else 0
	state.used_abilities = {}
	state.start_tile = for_unit.tile
	state.start_move_points = state.move_points
	return state


func can_move() -> bool:
	return move_points > 0


func spend_movement(cost: int) -> void:
	move_points = maxi(0, move_points - cost)


## Reicht das reine BUDGET fuer diese Aktion? Energie und Abklingzeit prueft
## blocker_for() zusaetzlich -- hier geht es nur um "Angriff noch frei" bzw.
## "Faehigkeit in diesem Zug noch nicht gezogen".
func can_use(action: ActionData) -> bool:
	if action.category == ActionData.Category.ATTACK:
		return attack_actions > 0
	return not used_abilities.has(action.id)


## Wie viel von diesem Budget noch da ist. Die Aktionsleiste schreibt die Zahl
## ueber die Gruppe. Beim Angriff ist es der Vorrat, bei der Faehigkeit die Zahl
## der eigenen Faehigkeiten, die in diesem Zug noch nicht gezogen sind.
func actions_left(category: ActionData.Category) -> int:
	if category == ActionData.Category.ATTACK:
		return attack_actions
	var total := unit.actions_of(ActionData.Category.ABILITY).size() if unit != null else 0
	return maxi(0, total - used_abilities.size())


## Warum geht diese Aktion nicht? Leerer String = sie geht.
## Der Aktionsring zeigt diesen Text als Grund am ausgegrauten Eintrag.
func blocker_for(action: ActionData) -> String:
	if not can_use(action):
		return "Angriff verbraucht" if action.category == ActionData.Category.ATTACK \
			else "Faehigkeit in diesem Zug schon genutzt"
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
		used_abilities[action.id] = true
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
	return move_points <= 0 and attack_actions <= 0 \
		and actions_left(ActionData.Category.ABILITY) <= 0


func _to_string() -> String:
	return "TurnState(%s mp=%d atk=%d abl_used=%d%s)" % [
		unit.unit_id if unit else "-", move_points, attack_actions,
		used_abilities.size(), " committed" if committed else ""]
