extends SceneTree

## Blicktest fuer die Projektion. Kein Testlauf -- ein Bild.
##
##     godot --headless --script res://tests/visual_check.gd
##     -> /tmp/drome_visual.png
##
## Legt die fuenf Terrainklassen nebeneinander und stellt einen Vireo darauf.
## Was hier auffaellt, faellt in keinem Unit-Test auf: ob Kachelschritt und
## Bauteil-Projektion dieselbe Raute meinen. Stimmen sie nicht ueberein, steht
## der Bot neben seinem Feld statt darauf, und zwar um einen Betrag, den man
## erst bei 20x20 Feldern als Fehler erkennt.
##
## An diesem Bild sind auch die Hoehen von STEP und BLOCK nachgezogen worden:
## eine Stufe muss als erhoeht lesbar sein, ein Betonpfeiler muss einen DROME
## ueberragen. Beides sieht man nur so.

const W := 76.0   # Bodenraute
const H := 54.0
const TW := 128   # Bildgroesse eines Teils/Tiles
const ORIGIN := Vector2(64, 96)   # Mittelpunkt der Raute im Bild

func _initialize():
    var canvas := Image.create(900, 620, false, Image.FORMAT_RGBA8)
    canvas.fill(Color(0.05, 0.06, 0.09, 1))
    var base := Vector2(430, 120)

    var tiles := {
        "normal": "res://assets/terrain/city/asphalt.svg",
        "step":   "res://assets/terrain/city/kerb.svg",
        "block":  "res://assets/terrain/city/pillar.svg",
        "drift":  "res://assets/terrain/city/oilfilm.svg",
        "haze":   "res://assets/terrain/city/steam.svg",
    }
    var layout := {
        Vector2i(0,0): "normal", Vector2i(1,0): "normal", Vector2i(2,0): "step",
        Vector2i(0,1): "drift",  Vector2i(1,1): "normal", Vector2i(2,1): "step",
        Vector2i(0,2): "normal", Vector2i(1,2): "haze",   Vector2i(2,2): "block",
        Vector2i(0,3): "normal", Vector2i(1,3): "normal", Vector2i(2,3): "normal",
    }
    # Hintere Reihen zuerst -- Y-Sortierung von Hand.
    var keys := layout.keys()
    keys.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
    for cell in keys:
        _blit(canvas, load(tiles[layout[cell]]).get_image(), base, cell)

    # Ein Vireo auf Feld (1,1), aus denselben Teilen wie in der Werkstatt.
    for part in ["scout_feet", "scout_body", "scout_core", "scout_head",
                 "eq_pulse_blaster"]:
        var path := "res://assets/parts/bot1/%s_south.svg" % part
        if ResourceLoader.exists(path):
            _blit(canvas, load(path).get_image(), base, Vector2i(1, 1))

    canvas.save_png("/tmp/drome_visual.png")
    print("geschrieben")
    quit(0)

func _blit(canvas: Image, src: Image, base: Vector2, cell: Vector2i) -> void:
    src.convert(Image.FORMAT_RGBA8)
    var screen := base + Vector2((cell.x - cell.y) * W * 0.5,
                                 (cell.x + cell.y) * H * 0.5)
    var at := screen - ORIGIN
    canvas.blend_rect(src, Rect2i(0, 0, TW, TW), Vector2i(at))
