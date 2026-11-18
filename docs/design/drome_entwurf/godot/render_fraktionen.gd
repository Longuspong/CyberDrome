## Blicktest Fraktions-Paletten (18. Nov. 2026): Zeilen = ohne Fraktion,
## Neon, Solar, Mecha, Hipstar; Spalten = Vireo, Molok, Nimbus, Strix.
##   xvfb-run -a godot --path . --script res://docs/design/drome_entwurf/godot/render_main.gd -- \
##       res://docs/design/drome_entwurf/godot/render_fraktionen.gd /tmp/out/fraktionen [FACING]
extends RefCounted

const PX := 256
const ROWS := ["", "neon", "solar", "mecha", "hipstar"]
const COLS := [[&"scout_body", &"eq_plasma_blade"], [&"jugg_body", &"eq_hammer"],
	[&"mage_body", &"eq_rune_staff"], [&"strix_body", &"eq_rail_lance"]]

func build(root: Window, facing_arg: String) -> Array:
	var facing := facing_arg if facing_arg != "-" else "deg300"
	var out := SubViewport.new()
	out.size = Vector2i(PX * COLS.size(), PX * ROWS.size())
	out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color("#120d24"); bg.size = Vector2(out.size)
	out.add_child(bg)
	root.add_child(out)
	for r in ROWS.size():
		for c in COLS.size():
			var b := DromeBuild.create("X", {})
			b.apply_chassis(COLS[c][0])
			b.slots[PartDB.get_part(COLS[c][0]).equip_slots()[0]] = COLS[c][1]
			b.faction = ROWS[r]
			var rig := Node2D.new()
			rig.position = Vector2(c * PX, r * PX)
			rig.scale = Vector2.ONE * PX / 128.0
			out.add_child(rig)
			DromeSprites.assemble(rig, b, facing, PX)
	return [out]
