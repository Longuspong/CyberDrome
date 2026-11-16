# DROME-Designregeln (entschieden 16. Nov. 2026)

Neue Regeln für Aussehen, Anker, Posen, Bewegung und Effekte der DROMEs.
Grundlage ist die Design-Studie auf Claude Design („DROME Design-Studie“,
Boards 1–12, privat beim Spieler). Die Entwürfe dort sind mit dem echten
Generator gebaut, die Skripte liegen unter `docs/design/drome_entwurf/`
(README dort). Vom Spieler abgesegnet; **noch nichts davon ist im Spiel
gebaut**, Reihenfolge siehe Abschnitt 9.

Warum neu: Die heutigen Teile stammen aus der Zeit, in der DROMEs selbst
modular waren (Anker für beliebige Teile). Heute hat jedes Chassis eine
feste Rolle und eine feste Zahl von Waffenplätzen; die Waffe bleibt
tauschbar. Damit kann jedes Chassis als Ganzes gestaltet werden.

## 1. Körperarten

| Körperart | DROMEs | Kennzeichen |
|---|---|---|
| **humanoid** | Vireo, Nimbus, Molok | zwei Arme; ein Waffenarm (Molok zwei), der andere Arm zeigt die Passive |
| **nicht-humanoid** | Strix (Eule) | kein Waffenarm, eigene Halterung am Körper |

## 2. Anker und Halter

* **Vireo:** 1 Anker, **Nimbus:** 1 Anker, **Molok:** 2 Anker, **Strix:** 1 Halterung.
* Der Waffenarm ist **immer derselbe Arm** eines Chassis, bei allen
  Humanoiden auf der Kameraseite (in der Hauptansicht vorn), damit die
  Waffe immer zu sehen ist.
* Der Anker sitzt an der **Schulter**. Die Waffe bringt Ober- und
  Unterarm in ihrer Pose mit (so wie heute schon), der Rumpf trägt nur den
  festen Passiv-Arm.
* **Nahkampf = Grundattacke bis 2 Felder, Fernkampf = ab 3 Feldern**
  (entschieden 16. Nov.). Die Waffen-Tags müssen dazu neu beschriftet
  werden (Runenstab, E-Schraubenschlüssel, Mörser, Lanze -> Fernkampf;
  Bumerang, Deflektor -> Nahkampf).
* **Strix: eigene Halterung ("Lafette") auf der Schulter**, nimmt
  **ausschließlich Fernkampf** an, bis schwer. Dass Runenstab und
  Schlüssel am Strix albern aussehen, lösen wir später.
* **Halter-Symbol:** Die Form zeigt wie bisher das Gewicht (Dreieck leicht,
  Quadrat mittel, Fünfeck schwer). Im Hintergrund der Form ein
  **Fadenkreuz = nur Fernkampf**, ein **Schwert = nur Nahkampf**.

## 3. Posen der Waffe

Der Waffenarm **hängt nie gerade nach unten**.

| Waffenart | Pose | Beispiele |
|---|---|---|
| Nahkampf | Arm angewinkelt, Waffe steht **nach oben** | Plasmaklinge, Hammer, Bollwerk-Ramme |
| Fernkampf | Arm **gestreckt nach vorn**, die Waffe ersetzt die Hand | Puls-Blaster, Neon-Blaster |
| Schild | angewinkelt **vor dem Körper** | Deflektor-Schild (Molok) |
| Stab / Werkzeug | angewinkelt, Stab senkrecht | Runenstab, E-Schraubenschlüssel |

## 4. Die Passive ist sichtbar

| DROME | Passive | Zeichen am Körper |
|---|---|---|
| Vireo | Sprint | **Booster an Helm und Rücken**, der leere Arm liegt am Körper an |
| Nimbus | Echo | Passiv-Arm: **Unterarm 90° nach vorn mit Energiekugel**; dazu der **Ring hinter dem Kopf**, als Leuchtelement (Energie) |
| Molok | Präsenz | Lockfeuer auf dem Rücken |
| Strix (Eule) | Anlegen | große Linsen an der Kapuze |

## 5. Licht und Kontur

* Rümpfe heller als heute (Plattenfarbe etwa +40 %), damit sie auf dem
  Nachtschwarz und auf hellen Böden lesbar bleiben.
* **Kontur in der Signalfarbe**, direkt ins SVG gebacken (ohne Shader).
  **Je Teil eine eigene Kontur**, damit sie bei Bewegung mitgeht; alle
  Kontur-Sprites eines DROME liegen unter allen seinen Teilen (dann sieht
  man nur den Aussenrand, keine Naehte).
* Signalfarben bleiben: Vireo Cyan, Molok Orange, Nimbus Violett, Strix Grün.

## 6. Bewegung

Bewegt werden die einzelnen Teile im Spiel (Rumpf, Kopf, Antrieb, Kern,
Waffe sind schon getrennte Sprites) -- im Code, ohne zusätzliche Bilder.

* **Idle:** Rumpf und Kopf atmen (1–2 px), Leuchtteile pulsieren; die
  Passive bewegt sich mit (Vireo-Booster flackert, Nimbus-Kugel schwebt,
  Molok-Lockfeuer dreht, Strix-Linsen blinzeln).
* **Laufen:** Wippen, Beine im Wechsel; Nimbus kippt auf dem Rad nach vorn,
  die Eule hüpft.
* **Angriff nach Waffenart:** Nahkampf holt aus und schlägt aus der
  Pose; Fernkampf mit Rückstoß und Mündungsblitz am `muzzle`-Anker; Schild
  stößt kurz nach vorn.

## 7. Fähigkeiten lesbar machen

Heute sind **alle** Fähigkeiten schlecht zu lesen. Jede Fähigkeit beantwortet
drei Fragen:

* **Wo?** -- eine Marke am Boden in Iso-Perspektive (Ring, Linie, Kegel),
  kurz bevor sie wirkt.
* **Wer?** -- in der Signalfarbe des Auslösers.
* **Was?** -- eine eigene Form je Fähigkeit (Vortex: Runen drehen nach
  innen, Pfeile für den Sog, Zeichen "verlangsamt" am Ziel).

Zuerst der Runenstab-Vortex, dann alle übrigen nach demselben Muster.

## 8. Fraktions-Paletten (Entwurf, Board 4)

| Fraktion | Platte / Metall | Akzent / Glühen | Kontur |
|---|---|---|---|
| Neon Ninja's | fast schwarz `#1a1820` / `#423c52` | Neonrot `#ff2a55`, Orange `#ff9a3d`, Weiß | Neonrot |
| Solar Sentients | Laubgrün `#3f7a3a` / Rinde `#8a6440` | Blütenrosa `#ff6fae`, Pollengelb `#fff27a` | Rosa |
| Mega Mechas | sattes Maschinenrot `#a3121c` / Schwarz `#232325` | **matt**: gelb-schwarze Absperrstreifen `#d4a017`, kaum Glühen (`#b8860b`) | gedecktes Gelb `#8a6a12` |
| Hipstar Hackers | Violett `#2a1446` / Cyan `#3ad6e0` | Magenta `#ff2bd6`, Cyan `#2ee3eb` | Magenta |

Die Streifen der Mechas sind im Entwurf ein SVG-Muster; ob Godot es sauber
zeichnet, ist offen (sonst als Geometrie).

## 9. Reihenfolge

1. Regeln (dieses Blatt) und Entwürfe auf Claude Design -- **erledigt**
   (Formen, Posen, Griffe, Bewegung, Vortex, Fraktions-Skins).
2. Offen auf Claude Design: Eule ausarbeiten, restliche Waffen in Pose
   (Neon-Blaster, Bumerang, Ramme, E-Schraubenschlüssel, Deflektor an
   Vireo/Nimbus), die übrigen 10 Fähigkeiten animieren.
3. Entschieden (16. Nov.): Hangar, Kacheln, Shop und Startseite zeigen
   die DROMEs weiter **von vorn** (south). Die Posen müssen also auch von
   vorn lesbar bleiben (Ellbogen nach außen, Klinge über den Kopf).
4. Ins Repo, je ein PR: **Licht + Kontur (gebaut 16. Nov.: Paletten im
   Generator heller, `tools/bake_godot_assets.py` backt je Teil ein
   `*_rim.svg`, `DromeSprites` legt sie als Kind des Teils auf Ebene 0)**;
   **Regeln im Generator (gebaut 16. Nov.: `body_kind` am Chassis,
   Tag `melee`/`ranged` aus der Reichweite der Grundattacke, Halterregel
   `reach` -- Strix-Lafette `ranged`; `PartData.accepts`/`reach_kind`,
   `SlotRules.slot_reach`, Fadenkreuz/Schwert in `SlotShape`; die
   Modulbedingungen nutzen dieselbe Grenze ab 3 Feldern)**; Chassis (**Strix als Eule gebaut 16. Nov.**: Rumpf mit Flügelmantel
   und Lafette, Eulenkapuze, Beine mit Knie nach hinten, Kern am Rücken,
   Lanze und Mörser auf der Lafette; Vireo, Nimbus, Molok offen); Waffen in ihre
   Posen; Bewegung im Teile-Rig (`unit.gd`); Effekte je Fähigkeit.
