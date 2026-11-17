"""Runde 12: Hexfeld -- drei Feldgroessen zum Vergleich (Designfrage, 17. Nov. 2026).

Nutzt die Platten aus v10_hexboden.py. Je Option ein Plan (plan_A/B/C.json)
mit Platten, Hindernissen (punktsymmetrisch) und Beispiel-DROMEs; gerendert
im Handy-Hochformat mit godot/render_hexfeld.gd:

    python3 docs/design/drome_entwurf/v12_hexfeld.py <ordner>
    xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \\
        res://docs/design/drome_entwurf/godot/render_hexfeld.gd <ordner>/bild <ordner>

  A  Sechseck Radius 5      91 Felder
  B  Hochkant 9 x 13       117 Felder
  C  Hochkant 9 x 17       153 Felder (Zonenabstand etwa wie heute auf 20 x 20)

Die Iso-Kamera staucht das Feld in der Tiefe auf 0,71 -- ein Feld wirkt nur
hochkant, wenn es deutlich mehr Reihen als Spalten hat.
"""
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import v10_hexboden as v10  # noqa: E402

R = v10.R
SORTS = ("beton", "beton_b", "beton", "gitter", "beton", "fuge")


def fl(q, r):
    return v10.axial_to_fl(q, r)


def hex_dist(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return max(abs(dq), abs(dr), abs(dq + dr))


def rect_cells(cols, rows):
    """Hochkant-Rechteck (Zeilen versetzt), mittig um (0, 0); axiale (q, r)."""
    cells = []
    for row in range(rows):
        for col in range(cols):
            r = row - rows // 2
            q = col - cols // 2 - (r - (r & 1)) // 2
            cells.append((q, r, col, row))
    return cells


def hexagon_cells(radius):
    cells = []
    for q in range(-radius, radius + 1):
        for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
            cells.append((q, r, None, r + radius))
    return cells


def plan(cells, rows, zone_rows=3, zone_cols=7, obstacles=()):
    tiles, zones = [], {"spieler": [], "gegner": []}
    cols_of_row = {}
    for q, r, col, row in cells:
        cols_of_row.setdefault(row, []).append((q, r))
    for q, r, col, row in cells:
        kind = SORTS[(q * 7 + r * 3) % 6]
        line = sorted(cols_of_row[row], key=lambda c: fl(*c)[1])
        idx = line.index((q, r))
        mid_ok = abs(idx - (len(line) - 1) / 2) <= (zone_cols - 1) / 2
        if row >= rows - zone_rows and mid_ok:
            kind = "zone_spieler"; zones["spieler"].append((q, r))
        elif row < zone_rows and mid_ok:
            kind = "zone_gegner"; zones["gegner"].append((q, r))
        tiles.append({"q": q, "r": r, "kind": kind, "fl": fl(q, r)})
    obs = []
    for q, r, kind in obstacles:                    # punktsymmetrisch
        for s in (1, -1):
            obs.append({"q": s * q, "r": s * r, "kind": kind, "fl": fl(s * q, s * r)})
    blocked = {(o["q"], o["r"]) for o in obs}
    tiles = [t for t in tiles if (t["q"], t["r"]) not in blocked] + \
        [{**o, "kind": "beton"} for o in obs]
    front = min(hex_dist(a, b) for a in zones["spieler"] for b in zones["gegner"])
    back = max(hex_dist(a, b) for a in zones["spieler"] for b in zones["gegner"])
    return tiles, obs, zones, front, back


def dromes(zones):
    """Spieler 3 (unten), Gegner 2 DROMEs + 2 Sentinels-Platzhalter (oben)."""
    def pick(zone, n, toward):
        zone = sorted(zone, key=lambda c: (abs(fl(*c)[1]), -toward * fl(*c)[0]))
        return zone[:n]
    sp = sorted(zones["spieler"], key=lambda c: fl(*c)[1])
    ge = sorted(zones["gegner"], key=lambda c: fl(*c)[1])
    mid_s = [c for c in sp if c[1] == max(x[1] for x in sp) - 1]
    mid_g = [c for c in ge if c[1] == min(x[1] for x in ge) + 1]
    ps = [mid_s[1], mid_s[len(mid_s) // 2], mid_s[-2]]
    gs = [mid_g[0], mid_g[len(mid_g) // 3], mid_g[2 * len(mid_g) // 3], mid_g[-1]]
    out = []
    for (q, r), (ch, wp) in zip(ps, [("scout_body", "eq_pulse_blaster"), ("jugg_body", "eq_hammer"),
                                     ("mage_body", "eq_rune_staff")]):
        out.append({"chassis": ch, "weapon": wp, "fl": fl(q, r), "yaw": 180.0})
    for (q, r), (ch, wp) in zip(gs, [("strix_body", "eq_rail_lance"), ("jugg_body", "eq_bulwark_ram"),
                                     ("scout_body", "eq_plasma_blade"), ("mage_body", "eq_drone_pod")]):
        out.append({"chassis": ch, "weapon": wp, "fl": fl(q, r), "yaw": 0.0})
    return out


OPTIONS = {
    "A": (hexagon_cells(5), 11, ((-2, 1, "pfeiler"), (3, -1, "kisten"))),
    "B": (rect_cells(9, 13), 13, ((-2, 1, "pfeiler"), (2, 2, "kisten"), (-4, 3, "kisten"))),
    "C": (rect_cells(9, 17), 17, ((-2, 1, "pfeiler"), (2, 2, "kisten"), (-4, 4, "kisten"),
                                  (3, -3, "pfeiler"))),
}

if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/hexfeld")
    out.mkdir(parents=True, exist_ok=True)
    for name, shapes in {**v10.TILES, **v10.OBSTACLES}.items():
        faces, hulls = v10.g.model_faces(shapes)
        (out / f"hex_{name}.m3d").write_text(json.dumps(
            {"id": name, "colors": v10.COLORS[name], "faces": faces, "hulls": hulls,
             "anchors": {"mount": [0, 0, 0]}}, separators=(",", ":")))
    for key, (cells, rows, obstacles) in OPTIONS.items():
        tiles, obs, zones, front, back = plan(cells, rows, obstacles=obstacles)
        (out / f"plan_{key}.json").write_text(json.dumps(
            {"tiles": tiles, "obstacles": obs, "dromes": dromes(zones)}))
        print(f"{key}: {len(cells)} Felder, Zonen {len(zones['spieler'])} Felder, "
              f"Abstand der Zonen {front}..{back} Hexschritte")
