# DROME-Umsetzung: Stand und Plan (16. Nov. 2026)

Was aus den DROME-Designregeln (`docs/DROME_DESIGNREGELN.md`) schon im Spiel
ist, was noch fehlt und in welcher Reihenfolge. Die Bilder dazu liegen in der
„DROME Design-Studie“ auf Claude Design (privat beim Spieler, Boards 1–13),
die Entwurfs-Skripte unter `docs/design/drome_entwurf/`.

**Arbeitsweise:** je Schritt ein eigener Commit (oder PR), danach immer
`python3 tools/build_sample_parts.py`, `python3 tools/bake_godot_assets.py`,
bei neuen SVG-Dateien `godot --headless --path . --import`, dann
`run_tests.gd`, `smoke_ui.gd`, `build_spot.py --check` und ein Screenshot von
Hangar und Kampf (`tests/screenshot.gd`). Werte der DROMEs ändern sich in
keinem Schritt -- nur Form, Licht und Bewegung.

## Erledigt (PR #69)

- [x] Regeln abgesegnet, Entwürfe und Skripte im Repo, SPOT-Eckpunkte
- [x] Ansicht außerhalb des Kampfes bleibt **von vorn** (south)
- [x] **Licht + Kontur je Teil**: Paletten ~40 % heller; `bake_godot_assets.py`
      backt je Teil `*_rim.svg`; `DromeSprites` hängt die Kontur als Kind des
      Teils an (Konturen Ebene 0, Teile ab 1)
- [x] **Generator-Regeln**: `body_kind`; Tag `melee`/`ranged` aus der
      Reichweite (bis 2 / ab 3); Halterregel `reach`; Strix-Lafette nur
      Fernkampf; Fadenkreuz/Schwert in `SlotShape`; Modulbedingungen mit
      derselben Grenze (Bumerang zählt jetzt als Nahkampf)
- [x] **Strix als Eule** (Rumpf mit Flügelmantel und Lafette, Eulenkapuze,
      Beine mit Knie nach hinten, Kern am Rücken, Lanze und Mörser auf der
      Lafette)
- [x] Hangar: Squad-Knopf in den Kacheln wieder 38 px

## Offen -- in dieser Reihenfolge

### 1. Chassis Vireo -- erledigt (16. Nov.)
Quelle: `v4.py` (`VIREO`, `V_BOOSTER`, `V_PASSIVE_ARM`) bzw. `new_dromes.py`
(`V_BODY`, `V_LEG`).
- [x] Rumpf: V-Torso, schlanke Taille, Schultern; **großer Rücken-Booster mit
      Flügeln** und Düsen (Passive Sprint)
- [x] Kopf: Helm mit Visier, Kamm statt Antenne, **zwei Helm-Booster**
      (Kopf-Anker jetzt `z 65`)
- [x] Passiv-Arm (rechts, `-l`) liegt am Körper an -- fester Teil des Rumpfs
- [x] Waffenarm kommt weiter mit der Waffe; Anker `equip_left` an der
      Schulter (`(0, 14.5, 54)`), bis Schritt 4 hängen die alten Waffenarme
- [x] Beine schlanker, Knieschutz, spitze Füße
- Kern sitzt eine Stufe höher (`z 51`), im Sockel der neuen Brustplatte

### 2. Chassis Nimbus -- erledigt (16. Nov.)
Quelle: `v4.py` (`NIMBUS`, `N_ORB_ARM`, `N_HALO`).
- [x] Rumpf, Hut und Rad bleiben; **Orb-Arm**: Unterarm 90° nach vorn mit
      Energiekugel, Ring um die Kugel (Passive Echo) -- fester Teil des Rumpfs
- [x] **Leuchtring hinter dem Kopf** (Leuchtelement) als Teil des Kopfes
- [x] Waffenarm (rechte Hand, `+l`) kommt mit der Waffe; Anker bleibt
      `(0, 13.8, 47)`, bis Schritt 4 hängen die alten Waffenarme

### 3. Chassis Molok -- erledigt (16. Nov.)
Quelle: `v4.py` (`MOLOK`, `M_ARM`) und `v2.py` (`M_BEACON`).
- [x] Kopf tief zwischen den Schultern (Kopf-Anker `z 60.5`), Schultern
      höher, Frontpanzer mit Kernsockel
- [x] **Zwei Schulteranker** (`(0, ±19, 57)`), beide Unterarme kommen mit
      den Waffen; `equip_shoulder` bleibt Optik. Bis Schritt 4 hängen die
      alten, kleinen Waffenarme (Armmaß 1,6 kommt mit den Posen)
- [x] **Lockfeuer** auf dem Rücken zwischen den Auspuffen (Passive Präsenz)

### 4. Waffen in ihre Posen (11 Waffen × 4 Richtungen)
Quelle: `v4.py` (`arm_extended`, `arm_raised`, `blaster`, `blade`,
`hammer`, `staff`, `shield`). Regel: Der Waffenarm hängt nie gerade.
- [ ] Fernkampf gestreckt, Waffe statt Hand: Puls-Blaster, Neon-Blaster
- [ ] Nahkampf angewinkelt, Waffe nach oben, **mit Griff, Knauf,
      Parierstange**: Plasmaklinge, Hammer, Bollwerk-Ramme, Klingenbumerang
- [ ] Stab/Werkzeug senkrecht mit Griffwicklung: Runenstab,
      E-Schraubenschlüssel
- [ ] Schild angewinkelt vor dem Körper: Deflektor
- [ ] **Lafetten-Variante** für Fernkampfwaffen am Strix (ohne Arm, auf der
      Schulter liegend) -- Vorschlag: der Generator schreibt für jede
      Fernwaffe einen zweiten Satz `*_lafette_*.svg`, `DromeSprites` wählt
      nach `body_kind`
- [ ] Größe am Molok -- entschieden (16. Nov.): dieselbe Waffe, nur größer
      gebaut über ein Armmaß je Chassis (`arm_scale`, Molok 1,6); kein
      eigener schwerer Satz
- [ ] Silhouetten-Prüfung (`check_silhouettes`) für die neuen Formen grün

### 5. Bewegung im Teile-Rig (`scripts/battle/unit.gd`, `DromeSprites`)
Entwurf: Board 11, `v5.py` (Ebenen und Drehpunkte).
- [ ] **Idle**: Rumpf/Kopf atmen 1–2 px, Leuchtteile pulsieren, Passive
      bewegt sich mit (Booster flackert, Kugel schwebt, Lockfeuer pulsiert,
      Linsen blinzeln)
- [ ] **Laufen**: Wippen; Nimbus kippt nach vorn, Eule hüpft. Beine im
      Wechsel brauchen getrennte Bein-Sprites -- Vorschlag: `feet` in
      `feet_left`/`feet_right` teilen, erst wenn das Wippen allein nicht reicht
- [ ] **Angriff** nach Waffenart: Nahkampf dreht die Waffe um den
      Schulteranker (ausholen, zuschlagen), Fernkampf Rückstoß + Mündungsblitz
      am `muzzle`-Anker, Schild stößt vor; ersetzt den heutigen Ruck des
      ganzen DROME (`play_attack`)
- [ ] Kontur geht schon mit (Kind des Teils) -- nur prüfen

### 6. Fähigkeiten lesbar (`scripts/ui/battle_view.gd`)
Entwurf: Board 12 (Vortex animiert, Tabelle für alle). Muster: **Wo**
(Bodenmarke in Iso-Perspektive), **Wer** (Signalfarbe), **Was** (eigene Form).
- [ ] **Vortex** zuerst: gestrichelter Iso-Ring während der 0,6 s
      Verzögerung, Runen drehen nach innen, Sog-Pfeile, Treffer, danach
      „verlangsamt“ (Ring am Fuß, Pfeile über dem Kopf, 2,5 s)
- [ ] Sperrfeuer, Präzisionsschuss, Betäubungsschlag, Rammstoß,
      Aufschlitzen, Wirbelwurf, Doppelschuss, Schildbrecher, Schildladung,
      Schildfeld -- je nach Tabelle auf Board 12
- [ ] Gegnerische Fähigkeiten: dieselben Formen, Ring mit rotem Außenrand

### 7. Fraktions-Paletten im Spiel
Quelle: `skins.py`. Neon fast schwarz mit grellem Neon, Solar
biologisch-blühend, Mechas sattes Rot matt mit Absperrstreifen, Hipstar
bleibt.
- [ ] Paletten für Fraktions-DROMEs und Sentinels übernehmen
- [ ] Absperrstreifen: prüfen, ob Godot das SVG-Muster zeichnet, sonst als
      Geometrie

### 8. Auf Claude Design noch offen (vor den passenden Schritten)
- [x] Eule: Linsen größer (Board 16, `v6.py` `LENS_BIG`: Ø 6,8 statt 4,6,
      Lichtpunkt, Gesichtsplatte breiter) -- freigegeben 16. Nov.
- [x] Restliche Waffen in Pose (Boards 14/15, `v6.py`): Neon-Blaster
      gestreckt, Bumerang wurfbereit, Ramme stößt vor, E-Schlüssel senkrecht,
      Deflektor an Vireo/Nimbus, Molok mit Armmaß 1,6; Puls- und Neon-Blaster
      auf der Lafette (Mörser, Lanze wie im Spiel) -- freigegeben 16. Nov.
- [ ] Die übrigen 10 Fähigkeiten als Animation

## Offene Fragen an den Spieler

1. Runenstab und E-Schraubenschlüssel am Strix sehen albern aus -- später
   eigene Lafetten-Form? (Spieler: „kümmern wir uns später drum“)
2. ~~Molok-Waffen~~ -- entschieden 16. Nov.: dieselbe Waffe mit Armmaß 1,6
   (Board 14), kein zweiter Satz.
3. Beine für die Laufanimation trennen (mehr Teile) oder nur Wippen?
4. ~~Bumerang als Nahkampf~~ -- entschieden 16. Nov.: bleibt Nahkampf, Pose
   angewinkelt und wurfbereit (Board 14).
