"""Fraktions-Skins auf den neuen Formen (Runde 4), Schraegansicht."""
import sys, pathlib
OUT = pathlib.Path(sys.argv[1]); OUT.mkdir(parents=True, exist_ok=True)
sys.argv = [sys.argv[0], str(OUT / "_tmp")]
import new_dromes as n
import v4
g = n.g

HAZARD = ('<defs><pattern id="hz" patternUnits="userSpaceOnUse" width="3.2" height="3.2" '
          'patternTransform="rotate(45)"><rect width="1.6" height="3.2" fill="#d4a017"/>'
          '<rect x="1.6" width="1.6" height="3.2" fill="#1a1a1a"/></pattern></defs>')

FR = {
    # dunkles Schwarz, helle Neon-Akzente (Rot, Orange, Weiss)
    "neon": dict(plate="#1a1820", plate_light="#34303f", plate_dark="#09080c", metal="#423c52",
                 accent="#ff2a55", glow="#ffffff", visor="#ff9a3d", outline="#000000", rim="#ff2a55"),
    # biologisch, bluehend: Laub, Rinde, Bluetenrosa, Pollen
    "solar": dict(plate="#3f7a3a", plate_light="#86c95e", plate_dark="#1d4222", metal="#8a6440",
                  accent="#ff6fae", glow="#fff27a", visor="#ffc4e2", outline="#0b1d0d", rim="#ff6fae"),
    # Maschinenrot satt und matt, Schwarz, Absperrstreifen in mattem Gelb
    "mecha": dict(plate="#a3121c", plate_light="#c4252a", plate_dark="#55070d", metal="#232325",
                  accent="url(#hz)", glow="#b8860b", visor="#c9971a", outline="#0a0a0a", rim="#8a6a12"),
    # bleibt wie gehabt
    "hacker": dict(plate="#2a1446", plate_light="#5a2e8a", plate_dark="#150826", metal="#3ad6e0",
                   accent="#ff2bd6", glow="#2ee3eb", visor="#ffe14d", outline="#06020e", rim="#ff2bd6"),
}
FORMS = {
    "vireo": v4.DESIGNS["v4_vireo_blaster"],
    "molok": v4.DESIGNS["v4_molok_hammer_schild"],
    "nimbus": v4.DESIGNS["v4_nimbus_stab"],
    "strix": v4.DESIGNS["v4_strix_lanze"],
}
for fk, cs in FR.items():
    for dk, shapes in FORMS.items():
        body = n.paint(g.render(shapes, "east"), cs)
        under = n.rim(body, cs["rim"])
        defs = HAZARD if fk == "mecha" else ""
        (OUT / f"s_{fk}_{dk}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-14 -14 156 156" width="624" height="624">'
            f'{defs}{under}{body}</svg>')
print("ok")
