# Fabrikstadt -- Entwurf (28. Nov. 2026)

Design-Sitzung zum Fabrik-Tab (Platine + Bau-Menü). Abgesegnet ist die Richtung, die Regeln
dahinter stehen in `docs/FACTORY_KONZEPT.md`, Abschnitt 14.

* Design-Canvas mit Prototyp zum Durchklicken: https://claude.ai/artifact/RdYTr9e3QabvCAVY9Q3Ct1
  (unterste Reihe „Fabrikstadt · Linien, Tiers, Bau-Menü“ ist der aktuelle Stand; die Reihen
  darüber sind ältere Runden zum Vergleich).
* `fabrikstadt.py` zeichnet Platine, Gebäude (je Typ T1-T3) und Menü-Bilder als SVG
  (`python3 fabrikstadt.py` -> Ordner `v5/`). `grundformen.py` enthält Projektion und Primitive.
* `bilder/` -- Platine im Ansehen- und Bau-Modus, Tier-Leiter aller Typen.
* `symbole/` -- neue Knopf-Symbole (Bauen = Kran, Fördern = Bohrturm, Veredeln, Herstellen,
  Strom, Logistik), 24 x 24, Strich 2, eckige Enden.

Kamera der Entwürfe: `U = 50` px je Hex-Einheit, Tiefe `F = 0.86`, Höhe `V = 0.58`
(steil von Süden, Gebäude schneiden höchstens den Rand des Feldes dahinter an).
Im Spiel wird das 3D (Grundformen wie die DROME-Teile, feste Iso-Kamera wie `Arena3D`).
