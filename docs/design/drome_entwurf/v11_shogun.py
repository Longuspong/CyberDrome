"""Runde 11: Shogun Kage wie v9, aber mit dem gedrehten Quader (``g.O``/``g.OB``,
17. Nov. 2026): Katana, V-Hoerner und Umhang glatt statt in Stufen.

    python3 docs/design/drome_entwurf/v11_shogun.py <ausgabe-ordner>
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[3] / "tools"))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import build_sample_parts as g  # noqa: E402
import v9_shogun as v9  # noqa: E402

B, OB = g.B, g.OB

# ----------------------------------------------------------------- Katana
KATANA_GRIP = [OB((13.2, -9.0, 39.6), (13.6, 0.6, 38.2), 2.0, 2.0, "plate")]
BLADE = [
    OB((13.7, 6.0, 37.6), (17.0, 44.0, 27.0), 1.6, 2.6, "accent"),
    # weiss gluehender Kern, schaut oben aus der Klinge
    OB((13.7, 6.4, 38.1), (17.0, 43.0, 27.6), 0.6, 2.2, "glow"),
    # Spitze: kuerzer, schmaler, abgeschraegt (Kissaki)
    OB((16.9, 43.6, 27.1), (17.4, 47.6, 25.4), 1.0, 1.6, "accent", roll=-25),
]

# ------------------------------------------------- V-Hoerner (Kuwagata)
HORNS = []
for side in (1, -1):
    # Schaft nach oben aussen, dann das Ende nach aussen gebogen
    HORNS.append(OB((9.3, side * 1.6, 65.4), (9.3, side * 12.6, 81.6), 1.4, 2.6, "accent"))
    HORNS.append(OB((9.3, side * 12.0, 81.0), (9.3, side * 17.8, 83.4), 1.4, 2.4, "accent"))
ORANGE_HEAD = [s for s in v9.ORANGE_HEAD if s[4] != "accent"] + HORNS

# ------------------------------------------------------------------ Umhang
CAPE = [B((-10.0, -8.6), (-11.5, 11.5), (40.0, 55.0), "plate")]
CAPE_EDGE = []
for k, (l0, l1, length, drop) in enumerate(((6, 11, 14, 9), (1, 6, 20, 11), (-4, 1, 26, 12),
                                            (-9, -4, 31, 14), (-14, -9, 24, 10),
                                            (-19, -14, 17, 8))):
    lm = (l0 + l1) / 2.0
    start = (-9.6, lm, 52.0)
    end = (-10.0 - length, lm - 3.0, 52.0 - drop)
    # eine glatte Bahn, leicht um die eigene Achse verdreht (weht)
    CAPE.append(OB(start, end, l1 - l0, 1.4, "plate", roll=(k - 2.5) * 4.0))
    # gluehender Saum quer am Ende der Bahn
    tip = (end[0] - 0.6, end[1], end[2] - 0.2)
    CAPE_EDGE.append(g.O(tip, (1.8, l1 - l0 - 0.6, 1.2), (0, 0, 0), "glow"))
    if k % 2 == 0:                                             # Fetzen
        CAPE_EDGE.append(OB((end[0] - 0.8, l0 - 1.0, end[2] - 0.4),
                            (end[0] - 3.8, l0 - 1.6, end[2] - 1.8), 1.4, 1.0, "plate"))

BLOCKS = dict(v9.BLOCKS)
BLOCKS["orange"] = (v9.PLATFORM_ORANGE + v9.TORSO_ORANGE + v9.PAULDRON_ORANGE
                    + v9.ARMS_ORANGE + ORANGE_HEAD + v9.KATANA_ORANGE, v9.ORANGE)
BLOCKS["umhang"] = (CAPE + CAPE_EDGE, v9.CLOTH)
BLOCKS["griff"] = (KATANA_GRIP, v9.GRIP)
BLOCKS["klinge"] = (BLADE, v9.BLADE_C)

if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/shogun11")
    out.mkdir(parents=True, exist_ok=True)
    for name, (shapes, colors) in BLOCKS.items():
        faces, hulls = g.model_faces(shapes)
        (out / f"shogun_{name}.m3d").write_text(json.dumps(
            {"id": f"shogun_{name}", "colors": colors, "faces": faces,
             "hulls": hulls, "anchors": {"mount": [0, 0, 0]}},
            separators=(",", ":")))
    print("ok", out, {k: len(v[0]) for k, v in BLOCKS.items()})
