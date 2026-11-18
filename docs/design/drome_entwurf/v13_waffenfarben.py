"""Runde 13: Waffenfarben -- drei Vorschlaege (Designfrage, 18. Nov. 2026).

Wunsch des Spielers: individuelle Farben je Waffe. Klassische Metallwaffen
aus Metall, gern glaenzend; Schienen-Lanze mehr Energie; Runenstab Metall
und Strom gemischt. Nur Optik -- nichts davon steht in WEAPON_COLORS, bis der
Spieler waehlt (auch gemischt je Waffe).

    python3 docs/design/drome_entwurf/v13_waffenfarben.py <ordner>
    xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \\
        res://docs/design/drome_entwurf/godot/render_waffenfarben.gd <ordner>/bild <ordner>

Je Waffe vier Kategoriefarben wie in WEAPON_COLORS (hull, mech, neon, line),
dazu zwei Vorschlags-Schalter:

  energie  die Leuchtteile leuchten im Spiel (wie der Neon-Blaster)
  glanz    Glanzkante ueber Panzer und Metall, 0..1 (nur Entwurf: braucht
           einen Zusatz im Shader drome_face, falls gewaehlt)

  A  Waffenstahl  dunkler, bläulicher Stahl, satiniert; Energie in Cyan/Violett
  B  Chrom        helles poliertes Metall, starker Glanz; Energie weiss-blau
  C  Werkstatt    Stahl mit Messing und Kupfer; Lanze gelb, Stab Tesla-blau
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import build_sample_parts as gen  # noqa: E402

NEON_BLASTER = dict(gen.NEON_EQUIPMENT, energie=True, glanz=0.0)


def w(hull, mech, neon, line="#07090d", energie=False, glanz=0.0):
    return {"hull": hull, "mech": mech, "neon": neon, "line": line,
            "energie": energie, "glanz": glanz}


SETS = {
    "A": {
        "name": "Waffenstahl",
        "text": "Dunkler, bläulicher Stahl mit seidigem Glanz. Metallwaffen "
                "bleiben Metall mit kleinen Signalfarben; Klinge, Schild, Stab "
                "und Lanze tragen Energie.",
        "weapons": {
            "eq_pulse_blaster": w("#3b4250", "#8a93a3", "#2de2e6", glanz=0.35),
            "eq_neon_blaster": NEON_BLASTER,
            "eq_plasma_blade": w("#2a2f3a", "#9aa3b3", "#ff5a3d", energie=True, glanz=0.35),
            "eq_boomerang": w("#46505f", "#b8c0cc", "#ffb000", glanz=0.4),
            "eq_deflector": w("#39404c", "#8a93a3", "#5ad1ff", energie=True, glanz=0.3),
            "eq_hammer": w("#4a4e56", "#a0a6b0", "#ff8a3d", glanz=0.4),
            "eq_bulwark_ram": w("#3f444c", "#979ca6", "#ffd447", glanz=0.4),
            "eq_drone_pod": w("#55504a", "#b0a89a", "#ffd447", glanz=0.35),
            "eq_rune_staff": w("#3a3550", "#a59ac8", "#b06bff", energie=True, glanz=0.35),
            "eq_rail_lance": w("#1d2430", "#6f7d92", "#3df2ff", energie=True, glanz=0.3),
            "eq_mortar": w("#3d4636", "#8e9688", "#ff6a2a", glanz=0.3),
        },
    },
    "B": {
        "name": "Chrom",
        "text": "Helles, poliertes Metall mit starker Glanzkante. Energie "
                "weiß-blau und grell -- wirkt hochwertig, aber hell auf dem "
                "dunklen Boden.",
        "weapons": {
            "eq_pulse_blaster": w("#7a8494", "#d6dde6", "#2de2e6", "#0a0d12", glanz=0.7),
            "eq_neon_blaster": NEON_BLASTER,
            "eq_plasma_blade": w("#6a7282", "#d6dde6", "#ff2bd6", "#0a0d12", energie=True, glanz=0.7),
            "eq_boomerang": w("#808a9a", "#e2e8ef", "#2de2e6", "#0a0d12", glanz=0.75),
            "eq_deflector": w("#727c8c", "#d0d8e2", "#7cf9ff", "#0a0d12", energie=True, glanz=0.6),
            "eq_hammer": w("#7a7f88", "#dadfe6", "#ff8a3d", "#0a0d12", glanz=0.75),
            "eq_bulwark_ram": w("#727780", "#d0d5dc", "#ffd447", "#0a0d12", glanz=0.75),
            "eq_drone_pod": w("#86827a", "#e0dbd0", "#ffd447", "#0a0d12", glanz=0.7),
            "eq_rune_staff": w("#5b4a8a", "#d8ccff", "#e0b3ff", "#0a0d12", energie=True, glanz=0.6),
            "eq_rail_lance": w("#2a3b52", "#cfe6ff", "#7cf9ff", "#0a0d12", energie=True, glanz=0.6),
            "eq_mortar": w("#6e7566", "#d2d8cc", "#ff5a3d", "#0a0d12", glanz=0.6),
        },
    },
    "C": {
        "name": "Werkstatt",
        "text": "Stahl mit Messing- und Kupferbeschlägen, warm und "
                "handgemacht. Runenstab als Tesla-Spule (Kupfer + blauer "
                "Strom), Lanze mit gelber Energie.",
        "weapons": {
            "eq_pulse_blaster": w("#4b4f57", "#c9a45c", "#2de2e6", glanz=0.45),
            "eq_neon_blaster": NEON_BLASTER,
            "eq_plasma_blade": w("#3e3a36", "#c9a45c", "#ff7a2d", energie=True, glanz=0.45),
            "eq_boomerang": w("#4b4f57", "#c87a4f", "#ffd447", glanz=0.5),
            "eq_deflector": w("#4a4840", "#c9a45c", "#7cf9ff", energie=True, glanz=0.4),
            "eq_hammer": w("#5a4a40", "#c87a4f", "#ffb057", glanz=0.5),
            "eq_bulwark_ram": w("#4e4a44", "#c9a45c", "#ff8a3d", glanz=0.5),
            "eq_drone_pod": w("#5a5048", "#d6b46a", "#ffd447", glanz=0.45),
            "eq_rune_staff": w("#3a2f2a", "#d0844f", "#7cf9ff", energie=True, glanz=0.45),
            "eq_rail_lance": w("#1b1f27", "#c9a45c", "#ffe066", energie=True, glanz=0.4),
            "eq_mortar": w("#4e5240", "#c9a45c", "#ff6a2a", glanz=0.4),
        },
    },
}

# Heute (zum Vergleich): die Bausatzfarben aus WEAPON_COLORS.
TODAY = {pid: dict(colors, energie=pid == "eq_neon_blaster", glanz=0.0)
         for pid, colors in gen.WEAPON_COLORS.items()}


def main(out: pathlib.Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    sets = {"0": {"name": "Heute", "text": "Die Bausatzfarben von heute.",
                  "weapons": TODAY}, **SETS}
    plan = {}
    for key, spec in sets.items():
        weapons = {}
        for pid, c in spec["weapons"].items():
            weapons[pid] = {"colors": gen.resolve_roles(c, "equipment"),
                            "energie": c["energie"], "glanz": c["glanz"],
                            "basis": {k: c[k] for k in ("hull", "mech", "neon", "line")}}
        plan[key] = {"name": spec["name"], "text": spec["text"], "weapons": weapons}
    (out / "waffenfarben.json").write_text(json.dumps(plan, ensure_ascii=False, indent=1),
                                           encoding="utf-8")
    print(f"{len(plan)} Saetze nach {out / 'waffenfarben.json'}")


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/waffenfarben"))
