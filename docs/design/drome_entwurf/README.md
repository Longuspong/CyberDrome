# DROME-Entwürfe (Claude Design, 15./16. Nov. 2026)

Skripte, mit denen die Bilder der „DROME Design-Studie“ gebaut wurden. Sie
nutzen den echten Generator (`tools/build_sample_parts.py`: Quader `B`,
Scheiben `D`, Drehkörper `L`, `render`) und schreiben SVGs in einen Ordner
nach Wahl. **Nur Entwurf** -- nichts davon landet in `parts/`; die Regeln
dazu stehen in `docs/DROME_DESIGNREGELN.md`.

```bash
python3 docs/design/drome_entwurf/v4.py /tmp/drome_v4      # Posen (Runde 4)
python3 docs/design/drome_entwurf/v5.py /tmp/drome_anim    # Ebenen für Bewegung
python3 docs/design/drome_entwurf/v6.py /tmp/drome_v6      # übrige Waffen, Lafette, Linsen
python3 docs/design/drome_entwurf/v7.py /tmp/drome_v7      # 4b: Arme am Chassis, zwei Haltungen
python3 docs/design/drome_entwurf/v8_shogun.py /tmp/shogun # Boss Shogun Kage als 3D-Modelle (.m3d)
python3 docs/design/drome_entwurf/skins.py /tmp/drome_skin # Fraktions-Skins
```

| Datei | Inhalt |
|---|---|
| `new_dromes.py` | Runde 2: Paletten (heller), Kontur in Signalfarbe (`rim`), Vireo/Molok/Nimbus neu, Strix A „Eule“ und B „Reiher“, Hilfen `shift`/`mirror`/`sym` |
| `v2.py` | Runde 3: ein Anker (Molok zwei), Passive am freien Arm, Lockfeuer, Anker leer |
| `v4.py` | Runde 4: Posen -- die Waffe bringt den Arm mit (`arm_extended`, `arm_raised`), Waffenköpfe Blaster/Klinge/Hammer/Stab/Schild, Eule mit Lafette; Griffe mit Knauf, Parierstange, Griffwicklung |
| `v5.py` | Runde 5: DROMEs in Ebenen (Beine, Rumpf, Kopf, Waffe, Passive) samt **Kontur je Teil** für die Bewegung |
| `v6.py` | Runde 6 (Boards 14–16): Neon-Blaster, Bumerang (wurfbereit), Ramme (stößt vor), E-Schlüssel (senkrecht) an Vireo/Nimbus/Molok, Deflektor an Vireo/Nimbus; Puls-/Neon-Blaster auf der Strix-Lafette; Eule mit größeren Linsen |
| `v7.py` | Runde 7 (Schritt 4b, 17. Nov.): Arm gehört zum Chassis, zwei Haltungen (halten / zielen; Vireo gestreckt, Molok aus der Hüfte), Handenden Faust / Manschette / Hand im Vergleich, Passiv-Arm mit Hand, Strix-Lafette nur mit Runen-Kugel bzw. Schlüsselkopf |
| `v8_shogun.py` | Runde 8 (17. Nov.): Boss Shogun Kage, nur Optik -- Kabuto mit Maedate, Menpo, Sode, Kusazuri, Katana, Umhang; schreibt drei 3D-Modelle (Rüstung, Gold, Katana), gerendert mit `DromeModel` (Leinwand-Seite „Shogun Kage (3D)“). Drehkörper-Profile laufen wie überall von unten nach oben |
| `skins.py` | Fraktions-Paletten auf den neuen Formen (Mechas mit Absperrstreifen als SVG-Muster) |

Hinweis: `new_dromes.py` und `v2.py` schreiben schon beim Import in den
übergebenen Ordner -- es sind Entwurfs-Skripte, keine Bibliothek.
