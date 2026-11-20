# UI-Symbole

82 SVGs fuer Pfeile, Kreuze, Knoepfe, Waehrungen, Schadensarten, Zustaende,
Tab-Leiste, Kampfkarte, Rollen und Modulklassen. Sie ersetzen Schriftzeichen,
die in Bungee/Chakra Petch fehlen oder nicht zum Arcade-Stil passen, und die
von Hand gezeichneten Formen in `StatIcon`, `BattleView._statuses`,
`UiKit.TabButton`, `Arcade.GearButton`, `MapView` und `ModuleChip`.

* **Format:** `width="24" height="24" viewBox="0 0 24 24"`, transparent,
  Strich 2 (Kreuze/Haken 2,6), eckige Enden und Ecken passend zu den
  abgeschraegten Arcade-Kacheln.
* **Farbe:** alles weiss (`#ffffff`). Eingefaerbt wird im Spiel ueber
  `modulate`/`self_modulate` (TextureRect) bzw. `icon_*_color` (Button) --
  so bleiben die Farben aus `UiKit`/`Arcade` die einzige Quelle.
  Halbtransparente Flaechen (Schild, Flaeche) nutzen `opacity`, Loecher
  (Panzerung, Zahnrad, Koeder) `fill-rule="evenodd"` statt Schwarz.
* **Import:** 24 px sind fuer 16-52 px Anzeige zu grob gerastert; in der
  `.import` `svg/scale=4.0` setzen (wie bei `assets/modules`).

## Stand (15. Nov. 2026)

Alle Fundstellen unten sind umgesetzt (`UiIcon`, `StatIcon`, `MapView`,
`UiKit.TabButton`, `ModuleChip`, `BattleView`). Als Text geblieben, weil die
Schriften die Zeichen haben und sie mitten im Satz stehen: × und −, Ø, →,
◆ im Titel-Laufband, Woerter und Kuerzel im Fliesstext (KW, EP, SPD, Power,
Tasche, Lager, "−1 Leben"). Die
Zeilennummern unten sind der Stand vor dem Umbau.

## Auffaelligkeiten beim Durchsuchen

* **Credits** stehen mal als `◆` (Hauptmenue, Einsatz-Kopf), mal als `¢`
  (Laden, Neu wuerfeln) -> beides `credits.svg`.
* **Platzhaltercoin** ist im Hauptmenue `⬢`, im Shop und Einsatz `◈`;
  im Shop ist `⬢` aber der **Bausatz** -> `coin.svg` und `kit.svg` trennen das.
* **Caches** sind `◆` (Shop, Beute) und `▮` (Einsatz-Kopf) -> `cache.svg`.
* `◆` ist ausserdem Aufzaehlungszeichen (Shop-Zeilen, Titel-Laufband).
* Squad-Markierung im Hangar ist der Text `>>`, im Squad-Picker `-`/`+`,
  im Hangar `−`/`+` (zwei verschiedene Minus-Zeichen).
* `·` (Mittelpunkt) als Trenner ist in beiden Schriften vorhanden und bleibt Text.

## Symbole und Fundstellen

### Pfeile & Steuerung

| Datei | Bedeutung | ersetzt | Fundstellen |
|---|---|---|---|
| `arrow_right.svg` | Pfeil rechts | → | `scripts/ui/run_screen.gd:687`<br>`scripts/ui/run_screen.gd:688`<br>`scripts/ui/run_screen.gd:689`<br>`scripts/ui/run_screen.gd:690`<br>`scripts/ui/run_screen.gd:733`<br>`scripts/ui/run_screen.gd:1501` |
| `arrow_left.svg` | Pfeil links | ← | Reserve |
| `arrow_up.svg` | Pfeil hoch | ↑ | Reserve |
| `arrow_down.svg` | Pfeil runter | ↓ | Reserve |
| `play.svg` | Start / Weiter | ▶ | `scripts/ui/battle_screen.gd:870`<br>`scripts/ui/battle_screen.gd:942`<br>`scripts/ui/battle_screen.gd:1107`<br>`scripts/ui/info_popup.gd:161`<br>`scripts/ui/main_menu.gd:62`<br>`scripts/ui/run_screen.gd:411`<br>`scripts/ui/run_screen.gd:554`<br>`scripts/ui/run_screen.gd:1447`<br>`scripts/ui/saves_screen.gd:196`<br>`scripts/ui/shop_screen.gd:389` |
| `play_left.svg` | Zurück-Blättern | ◀ | `scripts/ui/info_popup.gd:155` |
| `caret_right.svg` | Mehr zeigen | ▸ | `scripts/ui/run_screen.gd:629`<br>`scripts/ui/run_screen.gd:637`<br>`scripts/ui/run_screen.gd:639`<br>`scripts/ui/settings_screen.gd:170` |
| `caret_left.svg` | Zurück (klein) | ◂ | `scripts/ui/run_screen.gd:1349` |
| `caret_down.svg` | Weiterlesen | ▼ | `scripts/ui/story_dialog.gd:121` |
| `chevron_right.svg` | Weiter / Link | › | `scripts/ui/settings_screen.gd:108`<br>`scripts/ui/shop_screen.gd:130` |
| `chevron_left.svg` | Zurück | ‹ | Reserve |
| `chevron_down.svg` | Aufklappen | ⌄ | Reserve |
| `chevron_up.svg` | Zuklappen | ⌃ | Reserve |
| `double_chevron_right.svg` | Im Squad | >> | `scripts/ui/hangar_screen.gd:321` |
| `level_up.svg` | Aufstieg | ▲ | `scripts/ui/run_screen.gd:1501` |
| `skip.svg` | Überspringen | ⏩ | `scripts/ui/story_dialog.gd:73` |
| `fast_forward.svg` | Tempo | » | `scripts/ui/battle_screen.gd:879`<br>`scripts/ui/battle_screen.gd:930` |
| `pause.svg` | Pause | ❚❚ | `scripts/ui/battle_screen.gd:882`<br>`scripts/ui/battle_screen.gd:942` |
| `reroll.svg` | Neu würfeln | ↻ | `scripts/ui/run_screen.gd:517` |
| `close.svg` | Schließen | ✕ | `scripts/ui/info_popup.gd:176` |
| `check.svg` | Erledigt / Sieg | ✓ | `scripts/ui/run_screen.gd:1331`<br>`scripts/ui/run_screen.gd:1402` |
| `cross.svg` | Niederlage | ✕ | `scripts/ui/run_screen.gd:1402` |
| `plus.svg` | Aufnehmen | + | `scripts/ui/hangar_screen.gd:260`<br>`scripts/ui/squad_picker.gd:132` |
| `minus.svg` | Herausnehmen | − | `scripts/ui/battle_screen.gd:269`<br>`scripts/ui/battle_screen.gd:973`<br>`scripts/ui/hangar_screen.gd:260`<br>`scripts/ui/run_screen.gd:627`<br>`scripts/ui/run_screen.gd:1402`<br>`scripts/ui/squad_picker.gd:132` |
| `times.svg` | Anzahl / Faktor | × | `autoload/game_state.gd:527`<br>`scripts/core/run_state.gd:1115`<br>`scripts/ui/battle_screen.gd:980`<br>`scripts/ui/run_screen.gd:703`<br>`scripts/ui/run_screen.gd:1416`<br>`scripts/ui/shop_screen.gd:234`<br>`scripts/ui/shop_screen.gd:369`<br>`scripts/ui/title_screen.gd:41` |
| `log.svg` | Protokoll | ☰ | `scripts/ui/battle_screen.gd:884` |
| `camera_follow.svg` | Kamera folgt | ◎ | `scripts/ui/battle_screen.gd:466`<br>`scripts/ui/battle_screen.gd:885` |
| `camera_free.svg` | Kamera frei | ○ | `scripts/ui/battle_screen.gd:466` |
| `bullet_square.svg` | Aufzählung | ■ | `scripts/ui/main_menu.gd:146`<br>`scripts/ui/run_screen.gd:1399` |
| `location.svg` | Gebiet | ◉ | `scripts/ui/main_menu.gd:46` |
| `average.svg` | Durchschnitt | Ø | `scripts/ui/main_menu.gd:182`<br>`scripts/ui/saves_screen.gd:186` |
| `unknown.svg` | Unbekannt / Chaos | ? | `scripts/ui/map_view.gd:124`<br>`scripts/ui/run_screen.gd:361` |
| `settings.svg` | Optionen | ⚙ | `scripts/ui/arcade.gd:520` |

### Währung & Beute

| Datei | Bedeutung | ersetzt | Fundstellen |
|---|---|---|---|
| `credits.svg` | Credits (Einsatz) | ◆ / ¢ | `scripts/ui/main_menu.gd:193`<br>`scripts/ui/run_screen.gd:204`<br>`scripts/ui/run_screen.gd:517`<br>`scripts/ui/run_screen.gd:621`<br>`scripts/ui/run_screen.gd:834`<br>`scripts/ui/run_screen.gd:926`<br>`scripts/ui/run_screen.gd:937` |
| `coin.svg` | Platzhaltercoin | ◈ / ⬢ | `scripts/ui/main_menu.gd:194`<br>`scripts/ui/run_screen.gd:634`<br>`scripts/ui/run_screen.gd:705`<br>`scripts/ui/shop_screen.gd:63` |
| `kit.svg` | Bausatz | ⬢ | `scripts/ui/shop_screen.gd:64`<br>`scripts/ui/shop_screen.gd:116`<br>`scripts/ui/shop_screen.gd:241`<br>`scripts/ui/shop_screen.gd:274`<br>`scripts/ui/shop_screen.gd:284` |
| `material.svg` | Material | ✦ | `scripts/ui/shop_screen.gd:67` |
| `cache.svg` | Lootcache | ◆ / ▮ | `scripts/ui/run_screen.gd:208`<br>`scripts/ui/run_screen.gd:634`<br>`scripts/ui/run_screen.gd:703`<br>`scripts/ui/shop_screen.gd:72` |
| `loot.svg` | Beute | ▸ | `scripts/ui/run_screen.gd:629` |
| `life.svg` | Leben | −1 Leben | `autoload/game_state.gd:474`<br>`scripts/core/run_state.gd:1047`<br>`scripts/ui/battle_screen.gd:974`<br>`scripts/ui/battle_screen.gd:975`<br>`scripts/ui/battle_screen.gd:1092`<br>`scripts/ui/run_screen.gd:202`<br>`scripts/ui/run_screen.gd:203`<br>`scripts/ui/run_screen.gd:311`<br>`scripts/ui/run_screen.gd:316`<br>`scripts/ui/run_screen.gd:627`<br>`scripts/ui/run_screen.gd:1378`<br>`scripts/ui/run_screen.gd:1402` |
| `xp.svg` | Erfahrung (EP) | EP | `scripts/ui/hangar_screen.gd:493`<br>`scripts/ui/hangar_screen.gd:516`<br>`scripts/ui/run_screen.gd:732`<br>`scripts/ui/run_screen.gd:1502` |
| `bag.svg` | Tasche | Tasche | `scripts/ui/run_screen.gd:425`<br>`scripts/ui/run_screen.gd:639`<br>`scripts/ui/run_screen.gd:688`<br>`scripts/ui/run_screen.gd:751` |
| `storage.svg` | Lager | Lager | `scripts/ui/run_screen.gd:687` |
| `recipe.svg` | Rezeptbuch | ◂ Rezeptbuch | `scripts/core/run_state.gd:1496`<br>`scripts/ui/run_screen.gd:577`<br>`scripts/ui/run_screen.gd:1271`<br>`scripts/ui/run_screen.gd:1349` |
| `bios.svg` | Matrix-BIOS | BIOS | `scripts/core/module_data.gd:26`<br>`scripts/core/module_data.gd:489`<br>`scripts/core/run_state.gd:1038`<br>`scripts/ui/run_screen.gd:760` |

### Schadensarten & Werte

| Datei | Bedeutung | ersetzt | Fundstellen |
|---|---|---|---|
| `kinetic.svg` | Kinetischer Schaden | Schwert | `scripts/ui/stat_icon.gd:75` |
| `energy.svg` | Energieschaden | Kugel | `scripts/ui/stat_icon.gd:83` |
| `virus.svg` | Virusschaden | VIRUS −10 % | `scripts/ui/battle_screen.gd:269`<br>`scripts/ui/battle_screen.gd:272` |
| `attack.svg` | Angriff | Fadenkreuz | `scripts/ui/stat_icon.gd:97` |
| `ability.svg` | Fähigkeit | Blitz | `scripts/ui/stat_icon.gd:102` |
| `speed.svg` | Angriffstempo | Doppelpfeil | `scripts/ui/stat_icon.gd:87` |
| `range.svg` | Reichweite | Pfeil mit Fuß | `scripts/ui/stat_icon.gd:92` |
| `time.svg` | Takt nach Zeit | Uhr | `scripts/ui/stat_icon.gd:107` |
| `hits.svg` | Takt nach Angriffen | Zahnrad | `scripts/ui/stat_icon.gd:111` |
| `adjacent.svg` | Gegner daneben | zwei Punkte | `scripts/ui/stat_icon.gd:118` |
| `heal.svg` | Reparatur | Kreuz | `scripts/ui/stat_icon.gd:121` |
| `shield.svg` | Schild | Schildform | `scripts/ui/stat_icon.gd:124` |
| `def.svg` | Panzerung | Platte | `scripts/ui/stat_icon.gd:124` |
| `weight.svg` | Gewicht | Gewichtsklotz | `scripts/ui/stat_icon.gd:139` |
| `hp.svg` | Integrität | Herz | `scripts/ui/stat_icon.gd:134` |
| `area.svg` | Flächenwirkung | Ringe | `scripts/ui/stat_icon.gd:144` |
| `power.svg` | Power | Power | `scripts/ui/run_screen.gd:471`<br>`scripts/ui/shop_screen.gd:491` |
| `move_speed.svg` | Speed (Bewegung) | SPD | `scripts/ui/run_screen.gd:471`<br>`scripts/ui/shop_screen.gd:491`<br>`scripts/ui/squad_tiles.gd:48` |
| `power_score.svg` | Kampfwert | KW | `scripts/ui/hangar_screen.gd:494`<br>`scripts/ui/run_screen.gd:276`<br>`scripts/ui/run_screen.gd:393`<br>`scripts/ui/run_screen.gd:395`<br>`scripts/ui/run_screen.gd:471`<br>`scripts/ui/run_screen.gd:545`<br>`scripts/ui/run_screen.gd:1073`<br>`scripts/ui/squad_picker.gd:73`<br>`scripts/ui/squad_picker.gd:105`<br>`scripts/ui/stat_bar.gd:20` |

### Zustände im Kampf

| Datei | Bedeutung | ersetzt | Fundstellen |
|---|---|---|---|
| `stun.svg` | Betäubt | gelber Stern | `scripts/ui/battle_view.gd:460` |
| `slow.svg` | Verlangsamt | Pfeil runter | `scripts/ui/battle_view.gd:465` |
| `vulnerable.svg` | Verwundbar | Riss | `scripts/ui/battle_view.gd:468` |
| `rush.svg` | Sprint | Pfeil vor | `scripts/ui/battle_view.gd:471` |
| `lured.svg` | Angelockt (Köder) | ! im Kreis | `scripts/ui/battle_view.gd:445` |

### Leiste, Karte, Rollen, Modulklassen

| Datei | Bedeutung | ersetzt | Fundstellen |
|---|---|---|---|
| `tab_play.svg` | Tab Spielen | Dreieck | `scripts/ui/ui_kit.gd:284` |
| `tab_hangar.svg` | Tab Hangar | Halle | `scripts/ui/ui_kit.gd:284` |
| `tab_shop.svg` | Tab Shop | Sechseck-Coin | `scripts/ui/ui_kit.gd:284` |
| `tier_light.svg` | Karte: Leicht | L | `scripts/ui/map_view.gd:19` |
| `tier_normal.svg` | Karte: Normal | N | `scripts/ui/map_view.gd:19` |
| `tier_elite.svg` | Karte: Elite | E | `scripts/ui/map_view.gd:19` |
| `role_vanguard.svg` | Vorhut · Tank | Vorhut | `scripts/ui/hangar_screen.gd:170` |
| `role_skirmisher.svg` | Plänkler · Nahkampf | Plänkler | `scripts/ui/hangar_screen.gd:170` |
| `role_controller.svg` | Kontrolle | Kontrolle | `scripts/ui/hangar_screen.gd:170` |
| `role_sniper.svg` | Scharfschütze | Scharfschütze | `scripts/ui/hangar_screen.gd:170` |
| `class_attack.svg` | Modulklasse Angriff | Spitze | `scripts/ui/module_chip.gd:58` |
| `class_defense.svg` | Modulklasse Abwehr | Bogen | `scripts/ui/module_chip.gd:58` |
| `class_tactic.svg` | Modulklasse Taktik | Punkt | `scripts/ui/module_chip.gd:58` |

### Charger und Energy Phases (20. Nov. 2026)

| Datei | Bedeutung | ersetzt | Fundstellen |
|---|---|---|---|
| `phase_fire.svg` | Phase Feuer | Flamme | `scripts/ui/phase_gem.gd` |
| `phase_cryo.svg` | Phase Cryo | Schneeflocke | `scripts/ui/phase_gem.gd` |
| `phase_volt.svg` | Phase Volt | Blitz | `scripts/ui/phase_gem.gd` |
| `phase_terra.svg` | Phase Terra | Blatt | `scripts/ui/phase_gem.gd` |
| `phase_virus.svg` | Phase Virus | Totenkopf mit X-Auge | `scripts/ui/phase_gem.gd` |
| `phase_chaos.svg` | Phase Chaos | Wirbel | `scripts/ui/phase_gem.gd` |
| `hammer.svg` | Charger bauen | Hammer | `scripts/ui/charger_crafter.gd` |
| `charger.svg` | Charger / Rohling | Hex mit Blitz | `scripts/ui/charger_crafter.gd` |
