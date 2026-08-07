# M0 — Bestandsaufnahme vor dem DROME-MVP

Erstes Abgabeergebnis nach §0.1 des Build-Prompts: **erst lesen, dann schreiben.**
Dieses Dokument hält fest, was im Repository tatsächlich existiert, und wo der
Build-Prompt von diesem Bestand abweicht. Es wird noch **keine** Zeile
Spiel-Code geschrieben — drei Abweichungen sind so grundlegend, dass sie vor
dem ersten Commit entschieden werden müssen (siehe §6).

Stand: Branch `claude/drome-mvp-godot-mjnlf8`, Basis `0294c8c`.

---

## 1. Die ausgefüllten Platzhalter aus §0.1

Der Prompt lässt fünf Felder offen. So sehen sie im Repo tatsächlich aus:

| Feld aus §0.1 | Realität im Repo |
|---|---|
| Repository / Branch | `/home/user/CyberDrome`, Branch `claude/drome-mvp-godot-mjnlf8` |
| Werkstatt-Szene | **existiert nicht als `.tscn`** — die Werkstatt ist `index.html` (2385 Z., JS+CSS inline) plus `main.py` (836 Z., `http.server`-REST-API) |
| Bauteil-Definitionen | **JSON je Teil und Richtung**: `parts/<set>/<part_id>_<direction>.json`, 92 Dateien für 23 Teile |
| Asset-Verzeichnis | `parts/` — 92 SVG + 92 JSON + 4 `set.json`, verteilt auf `bot1`…`bot4` |
| Terrain-Tiles | **keine.** Kein einziges Terrain-Asset im Repo |

---

## 2. Was existiert: 23 Bauteile in 4 Sets

Alle Teile liegen als SVG (`viewBox 0 0 128 128`, isometrisch, 45°) plus
Metadaten-JSON vor, jeweils in vier Richtungen (`north`/`east`/`south`/`west`).
Die Teile-IDs sind richtungsunabhängig, die Dateien nicht.

| Set | DROME | Teile |
|---|---|---|
| `bot1` | RX-Vireo // Scout | `scout_body` CHS-001, `scout_head` HED-001, `scout_feet` LEG-001, `scout_core` COR-001, `eq_pulse_blaster` EQP-001, `eq_deflector` EQP-002 |
| `bot2` | HX-Molok // Juggernaut | `jugg_body` CHS-002, `jugg_head` HED-002, `jugg_feet` LEG-002, `jugg_core` COR-002, `eq_siege_cannon` EQP-003, `eq_drone_pod` EQP-004 |
| `bot3` | AR-Nimbus // Technomant | `mage_body` CHS-003, `mage_head` HED-003, `mage_drive` LEG-003, `mage_core` COR-003, `eq_rune_staff` EQP-005, `eq_orbit_focus` EQP-006 |
| `bot4` | LR-Strix // Marksman | `strix_body` CHS-004, `strix_head` HED-004, `strix_feet` LEG-004, `strix_core` COR-004, `eq_rail_lance` EQP-007 |

### 2.1 Welche Felder ein Bauteil-JSON heute trägt

```jsonc
{
  "id": "scout_body",          // richtungsunabhängig
  "code": "CHS-001",           // stabile Kennung fürs Game Design
  "set": "bot1",
  "type": "body",              // body | head | feet | core | equipment
  "name": "Vireo Chassis",
  "direction": "north",
  "svg": "scout_body_north.svg",
  "view_box": [0, 0, 128, 128],
  "z_index": 50.0,
  "anchors":      [ {name, x, y}, … ],   // Montagepunkte
  "color_scheme": { …8 Farbrollen… },
  "tags":         ["light", "scout"],
  "slot_z":       { head: 66, feet: 36, … },   // nur body: Zeichentiefe je Slot
  "slot_rules":   { equip_left: {max_class: "medium"}, … },  // nur body
  "mount_class":  "light",     // nur equipment: light | medium | heavy
  "category":     "weapon"     // nur equipment: weapon | shield | support
}
```

### 2.2 Der zentrale Befund: **es gibt keinen einzigen Spielwert**

Die 92 Bauteil-JSONs enthalten ausschließlich **Darstellungs- und
Montagedaten**: Ankerpunkte, Zeichenreihenfolge, Farbrollen, Silhouetten-Tags.

Gesucht und **nicht gefunden**: `hp`, `en`, `spd`, `mov`, `atk`, `def`,
`weight`, `power_draw`, `range`, `damage` — weder in den Teil-JSONs noch in
`main.py` oder `index.html`.

Daraus folgen zwei Dinge:

1. **Sämtliche Stats aus §3 sind Neuland.** Es gibt keine bestehende Skala, an
   die sie angepasst werden müssten. Der Vorbehalt aus §3 („die Werte des Repos
   gelten") läuft damit ins Leere — die Zahlen des Prompts können unverändert
   als Startwerte übernommen werden.
2. **Die vorhandene „Werkstatt" ist kein Loadout-Builder, sondern ein
   Asset-Werkzeug.** Sie setzt Teile grafisch zusammen, verschiebt Anker und
   exportiert SVG. Sie kennt keine Builds im Spielsinn, keine Validierung,
   keinen Statblock. Der Abgleich nach §4.1 fällt entsprechend aus (§4).

### 2.3 Wo Stats hingehören — und warum das eine Falle ist

`tools/build_sample_parts.py` **erzeugt die Bauteil-JSONs neu** (Z. 1702,
`json.dumps(meta)` schreibt die Datei vollständig). Erhalten bleiben nur die
Felder, die der Generator explizit kennt (`slot_z`, `slot_rules`,
`mount_class`, `category`, `slots`).

> **Konsequenz:** Stats, die von Hand in `parts/<set>/*.json` geschrieben
> werden, sind beim nächsten Generatorlauf weg. Wer Stats in dieses Format
> legt, muss den Generator mitziehen — sonst entsteht genau der stille
> Datenverlust, der später niemandem zuzuordnen ist.

Hinzu kommt: Stats sind **richtungsunabhängig**, die JSONs sind es nicht. Ein
`hp: 60` müsste in vier Dateien identisch stehen — vier Gelegenheiten, dass
sie auseinanderlaufen.

---

## 3. Der Slot-Konflikt

Das ist die schwerwiegendste Abweichung zwischen Prompt und Bestand.

| | Build-Prompt §2.2 | Repository |
|---|---|---|
| Slots | 6 **feste**: CHASSIS, CORE, DRIVE, WEAPON, UTILITY, MODULE | 4 feste + **1–3 variable** |
| Namen | Chassis / Kern / Antrieb / Waffe / Utility / Modul | `body` / `core` / `head` / `feet` + `equip_*` |
| Kopf | **existiert nicht** | `head` — eigener Bauteiltyp, 4 Teile vorhanden |
| Ausrüstung | 3 getrennte Slots mit fester Bedeutung | `equipment` als **ein** Typ; wie viele Slots, sagen die `equip_*`-Anker des Chassis |
| Was wo hineindarf | implizit über den Slot | explizit über `mount_class`/`category` gegen `slot_rules` |

Konkret pro Chassis:

| Chassis | Ausrüstungsslots | Regeln |
|---|---|---|
| `scout_body` | `equip_left`, `equip_right` | je bis `medium` |
| `jugg_body` | `equip_left`, `equip_right`, `equip_shoulder` | links/rechts bis `heavy`; Schulter nur `light` **und** nur `category: support` |
| `mage_body` | `equip_left`, `equip_right` | je bis `medium` |
| `strix_body` | `equip_center` | bis `heavy` — **nur ein einziger Slot** |

Das Repo hat diese Regel bewusst gesetzt und dokumentiert sie an drei Stellen
(`README.md`, `docs/GAME_DESIGN.md` §3, `docs/GODOT_INTEGRATION.md`):

> „Wie viele Ausruestungsslots eine DROME hat, ergibt sich allein daraus, wie
> viele `equip_*`-Anker ihr Koerper besitzt – ohne Sonderfall im Code."

**Nach §0.1 Regel 2 gewinnt der Bestand.** Das ist aber keine Kleinigkeit,
sondern ändert §2.2, §2.4, §3 und §10 des Prompts spürbar:

* Es gibt einen **Kopf-Slot**, für den der Prompt keine Stats vorsieht.
* „Mindestens eine Waffe belegt" (§2.4) heißt: mindestens ein Ausrüstungsteil
  mit `category == "weapon"` — nicht „Slot WEAPON belegt".
* Der **Strix kann gar kein Utility und kein Modul tragen** — ein Slot, ein
  Teil. Der §3-Katalog mit je einem Utility- *und* Modul-Slot ist auf diesem
  Chassis nicht baubar.
* Der Gegner-Generator (§10) muss Slots **pro Chassis** würfeln, nicht gegen
  eine feste Sechserliste.

---

## 4. Abgleich der Werkstatt nach §4.1

Der Prompt erwartet eine Werkstatt, die bereits Builds im Spielsinn baut.
Die vorhandene baut **Bots im Grafiksinn**. Der Abgleich fällt deshalb
deutlich magerer aus als §4.1 annimmt:

| Funktion aus §4.1 | Status im Repo |
|---|---|
| Slot-Auswahl | **vorhanden**, aber nach dem Repo-Slotmodell (§3), nicht nach dem des Prompts |
| Bauteil-Assets und DROME-Vorschau | **vorhanden und sehr ausgereift** — 4 Richtungen, Ankermontage, Feinjustierung, Anker-Editor, Palettensystem |
| Live-Statblock | **fehlt** (es gibt keine Stats) |
| Delta-Anzeige beim Hovern | **fehlt** |
| Balken Gewicht/Kapazität, Energie/Output | **fehlt** |
| Squad-Leiste für `SQUAD_SIZE` DROMEs | **fehlt** — die Werkstatt kennt immer genau *einen* Bot |
| Persistenz `user://squad.json` | **fehlt** — es gibt Build-Export nach `builds/<name>.svg` + `.json`, aber keinen Squad |
| Button „Chaos-Virus starten" | fehlt (erwartet) |
| Slotregel-Prüfung `mount_class` vs. `slot_rules` | **vorhanden** — mehr, als der Prompt verlangt |

Was §4.3 schützt („nicht umbauen"), ist damit im Wesentlichen der
**Asset-Teil**: Vorschau, Anker, Paletten, Export. Der bleibt unangetastet.

---

## 5. Fehlende Assets (Meldung statt Ersatz, §0.1 Regel 4)

Für den Kampf ab §5 existiert **kein einziges** Asset. Nach Regel 4 wird das
gemeldet, nicht selbst gemalt:

### 5.1 Terrain — 15 Tiles fehlen vollständig

Fünf Klassen × drei Regionen (§3b):

| Klasse | Sektor City | Grünzone | Anlage 7 |
|---|---|---|---|
| `NORMAL` | Asphalt | Wiese | Gitterrost |
| `STEP` | Bordstein-Podest | Wurzelsockel | Wartungsbühne |
| `BLOCK` | Betonpfeiler | Felsblock | Reaktorsäule |
| `DRIFT` | Ölfilm | Schlammrinne | Magnetschiene |
| `HAZE` | Dampfschwaden | Hohes Gras | Störfeld |

Anmerkung zur Machbarkeit: das Repo bringt in `tools/build_sample_parts.py`
einen vollständigen isometrischen Renderer mit (Quader `B`, Scheibe `D`,
Rotationskörper `L`), der Beleuchtung und Sichtbarkeit selbst ableitet.
Terrain-Tiles ließen sich damit **im vorhandenen Stil und mit dem vorhandenen
Werkzeug** erzeugen, statt sie zu improvisieren. Das ist eine Entscheidung des
Auftraggebers, keine des Auftragnehmers (§6, Frage 3).

### 5.2 Kampf-UI — Overlays und Marker fehlen

* Bewegungsreichweite (blaue Feldmarkierung)
* Angriffsreichweite (rot) und ungültige Ziele (grau)
* Pfadvorschau: durchgezogenes Laufsegment, gestricheltes Gleitsegment, Endmarker
* DRIFT-Richtungsmarkierung: Pfeil (gerichtet) bzw. Schlierenmuster (ungerichtet)
* HAZE-Halbtransparenz-Overlay
* Auswahl-/Aktiv-Marker unter der Einheit
* TICK-Queue-Portraits (die Werkstatt kann SVG exportieren — Portraits wären
  ableitbar, siehe `docs/GODOT_INTEGRATION.md` Pipeline B)

### 5.3 Nicht fehlend

Die DROMEs im Kampf brauchen **keine** neuen Assets: nach §5.5 werden sie aus
denselben Bauteil-SVGs zusammengesetzt wie in der Werkstatt-Vorschau. Die
Bauanleitung dafür steht bereits in `docs/GODOT_INTEGRATION.md` (Pipeline A:
`Node2D` + `Sprite2D` je Teil, `z_index` aus `slot_z`, alle Teile auf `(0,0)`,
`centered = false`).

---

## 6. Was vor dem ersten Commit entschieden werden muss

Drei Punkte, an denen der Prompt eine Voraussetzung annimmt, die im Repo nicht
zutrifft. Sie sind dem Auftraggeber vorgelegt.

### Frage 1 — Es gibt kein Godot-Projekt

Der Prompt setzt in §0.1 voraus, die Werkstatt liege als Godot-Szene vor. Das
ist nicht der Fall, und das Repo sagt das an zwei Stellen selbst:

> `README.md`: „Aktueller Stand: **SVG-Werkstatt** (Schritt 1). Noch kein Godot-Projekt."
>
> `docs/GODOT_INTEGRATION.md`: „Es gibt noch kein Godot-Projekt im Repo."

Damit kollidiert §4 („Werkstatt wird nicht neu gebaut") mit der Engine-Vorgabe:
eine Werkstatt *in Godot* wäre zwangsläufig ein Neubau. Zu klären ist, ob das
Godot-Projekt neu angelegt wird (und die HTML-Werkstatt als Asset-Werkzeug
weiterlebt) oder ob der MVP im vorhandenen Web-Stack entsteht.

**Nebenbefund:** in dieser Umgebung ist **kein Godot-Binary installiert**.
GDScript kann geschrieben, aber nicht ausgeführt werden. Die Testnachweise aus
§5.4 (200 Karten × 6 Antriebe) und den Meilensteinen M2/M3 wären damit nicht
belegbar — es sei denn, die reine Logikschicht wird so geschnitten, dass sie
außerhalb der Engine läuft (was §11 ohnehin verlangt).

### Frage 2 — Slotmodell

Siehe §3. Nach §0.1 Regel 2 gewinnt der Bestand; die Auswirkung auf §2.2/§2.4/§3
ist aber groß genug, dass sie bestätigt gehört.

### Frage 3 — Terrain-Assets

Nach §0.1 Regel 4 werden fehlende Assets gemeldet, nicht ersetzt; für die
Entwicklung ist ein magentafarbenes Fehlfeld erlaubt. Da das Repo einen eigenen
Iso-Renderer besitzt, gibt es hier eine dritte Möglichkeit (Tiles mit dem
vorhandenen Werkzeug erzeugen), die der Auftraggeber freigeben muss.

---

## 7. Beobachtungen am Bestand (§4.3: notieren, nicht ändern)

Nichts davon ist ein Mangel, und nichts davon wird angefasst:

1. `index.html` trägt Frontend, Stil und Logik in einer Datei (2385 Z.). Für ein
   Werkzeug ohne Build-Schritt ist das eine bewusste und tragfähige Entscheidung.
2. `FIXED_SLOTS` (Z. 617) und `TYPE_ORDER` (Z. 526) definieren die Slotreihenfolge
   an zwei Stellen. Beim Anbinden nicht als dritte Quelle danebenstellen.
3. `mage_drive` ist vom Typ `feet`, heißt aber `drive` — die einzige Stelle, an
   der Datei-ID und Typ auseinandergehen. Für einen Loader ohne Bedeutung,
   für eine Suche nach „alle Antriebe" eine Stolperstelle.
4. Der Generator kennt eine feste Liste zu erhaltender Metadaten-Felder
   (Z. 1693–1700). Jedes neue Feld muss dort eingetragen werden (§2.3).
