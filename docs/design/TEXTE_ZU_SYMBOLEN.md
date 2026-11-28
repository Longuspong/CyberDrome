# Texte, die ein Symbol sein koennten (28. Nov. 2026)

Durchgang ueber alle Bildschirme. Vorschlaege, noch nicht umgesetzt -- erst
absegnen. "Da" = das SVG liegt schon in `assets/ui_icons/`, "neu" = muesste
gezeichnet werden. Prioritaet: **A** viel Platz/Klarheit gewonnen, **B** nett,
**C** Geschmackssache.

## Waehrungen und Bestaende

| Wo | Heute | Vorschlag | SVG | Prio |
|---|---|---|---|---|
| Home, Geldkarte | `PLATZHALTERCOIN` ueber `◎ 200` | nur `◎ 200` | coin (da) | A |
| Home, im Einsatz | `CREDITS` ueber `◆ 10` | nur `◆ 10` | credits (da) | A |
| Shop, Bestandskarte | Coin-Bild, `200`, darunter `Platzhaltercoin` | Name weglassen, Bild reicht | coin (da) | B |
| Inventar, Kopfleiste | `◎ 200 Platzhaltercoin`, `▣ 15 Caches` | nur Symbol + Zahl | coin, cache (da) | A |
| Inventar, Lootcaches | Kopf `15 UNGEOEFFNET` (doppelt zur Kopfleiste) | weglassen oder `▣ 15` | cache (da) | B |
| Shop, Cache-Karte | Etikett `IM LAGER ×5` | `▤ ×5` | storage (da) | A |
| Einsatz, Zwischenstopp | `LAGER 0 / 8` | `▤ 0/8` | storage (da) | B |

## Einsatz und Kampfkarte

| Wo | Heute | Vorschlag | SVG | Prio |
|---|---|---|---|---|
| Kampfkarte, Kopf | Beschriftung `LEBEN CREDITS CACHES VERSTAERKUNG` ueber den Symbolen | nur Symbole + Zahl (wie im Zwischenstopp schon) | life, credits, cache (da), Verstaerkung = Balken (gezeichnet) | A |
| Kampfvorschau | Etikett `BEUTE` vor der Beute-Zeile | Beute-Symbol | loot (da) | B |
| Kampfvorschau | `Kampfwert: du 241 · Gegner 169 · ueberlegen` | `⚡241 : 169` + Pfeil hoch/runter in Gruen/Rot | power_score, arrow_up/down (da) | A |
| Kampfvorschau | Chips `NORMAL` / `ELITE` / `LEICHT` | Stufen-Symbol im Chip | tier_light/normal/elite (da) | B |
| Kampfvorschau | `KAMPF 1 · 3 GEGEN 3` | `3 × 3` mit DROME-Symbol | tab_dromes, times (da) | C |
| Zwischenstopp | Schrott-Feld `SCHROTT / hierher ziehen / = verkaufen` | Muelleimer + `→ ◆` | scrap, credits (da) | A |
| Einsatz-Ende | `Niederlage · −1 Leben` | zerbrochenes Herz `−1` | neu (life_lost) | B |

## Kampf

| Wo | Heute | Vorschlag | SVG | Prio |
|---|---|---|---|---|
| Kopf | `VIRUS IN 30 S` / `VIRUS −10 %` | Virus-Symbol + `30 s` | virus (da) | A |
| Kopf | `GEGNER 3/3` | Totenkopf/Ziel-Symbol + `3/3` | neu (enemy) | B |
| Leiste | Knoepfe `PROTOKOLL`, `KAMERA` (Symbol + Text) | nur Symbol | log, camera_* (da) | B |
| Ergebnis | `−1 LEBEN` | wie oben, Herz | neu | B |
| Ergebnis | Zellen `Abschuesse` | Fadenkreuz + Zahl | neu (kills) | C |

## DROMEs-Tab

| Wo | Heute | Vorschlag | SVG | Prio |
|---|---|---|---|---|
| Liste | gelber Text `WAFFENPLATZ FREI` / `CHARGER-PLATZ FREI` | gelber Punkt/Plus am Bild, Halter- bzw. Charger-Symbol | plus, charger (da) | A |
| Liste | Rolle `Plaenkler · Nahkampf` neben dem Rollen-Symbol | Rolle nur als Symbol, `Nahkampf` als Reichweiten-Symbol | role_*, range (da) | C |
| Uebersicht | `Level 2 / 5`, `Kampfwert 241` | Level-Pips + `⚡241` | level_up, power_score (da) | B |
| Level-Karte | `LEVEL 1 KOSTET` + `Plasma 0 / 40` | Waren-Symbol + `0/40` | Waren-Farben/Kuerzel aus der Fabrik | B |
| Level-Karte | `Hoechstlevel erreicht.` | Haken / volle Pips | check (da) | C |
| Uebersicht | Knopf `VERWERTEN` | Schrott-Symbol + Text (Text bleibt, ist destruktiv) | scrap (da) | C |
| Waffe | Kachel-Untertitel `FREI` / `EINGESETZT` bei Chargern | Haken / Kettenglied | check (da), neu (link) | B |

## Fabrik

| Wo | Heute | Vorschlag | SVG | Prio |
|---|---|---|---|---|
| Platine, Kopf | `TIER 1 · STROM 0/4 · TAKT 1` | `T1 · ⚡0/4 · ⟳1` | energy (da), Takt neu | A |
| Werkbank, DROME-Kacheln | `0/5 Teile` | Fuenf Kaestchen (Pips) | gezeichnet | B |
| Werkbank, Zutaten | `Upgrade-Chip 0/18 -- Chipfabrik (ab Tier 2)` | `0/18` + Kuerzel-Badge `CHP` + Schloss `T2` | Gebaeude-Kuerzel (da), Schloss neu | B |
| Charger-Crafter | Energy-Phases-Reihe: Edelstein **und** `FEUER` darunter | nur Edelstein + Zahl | phase_* (da) | A |
| Inventar | Phase-Kacheln `FEUER ×6` (Symbol + Name) | nur Symbol + `×6` | phase_* (da) | A |

## Optionen, Spielstaende, Popups

| Wo | Heute | Vorschlag | SVG | Prio |
|---|---|---|---|---|
| Optionen | `AN` / `AUS` neben jedem Schalter | weglassen, der Schalter zeigt es | -- | B |
| Optionen | Schriftgroesse `A NORMAL / A GROSS / A SEHR GROSS` | nur drei unterschiedlich grosse `A` | -- | C |
| Optionen, Spielstaende | schraeges Etikett `SETUP` / `SAVE SELECT` (Englisch, doppelt zum Titel) | weglassen oder Zahnrad/Diskette | settings (da) | C |
| Spielstaende | `01` **und** `SLOT 1` | nur `01` | -- | B |
| Story-Dialog | `ANTIPPEN · WEITER` | blinkender Pfeil unten rechts | chevron_right (da) | B |
| Cache oeffnen | `TIPPEN ZUM OEFFNEN` | pulsierende Hand/Finger | neu (tap) | C |
| Tab-Leiste | Text unter den fuenf Symbolen | bleibt (Lesbarkeit) -- hoechstens bei sehr schmalen Handys weg | -- | C |

## Schon entfernt (dieser Durchgang)

Bedienhinweise, die die Kachel-Regel wiederholen ("Antippen oeffnet ...",
"Doppeltipp ..."), Entwickler-Notizen im Spiel ("Arbeitsname", "Bauschritt 5",
"Inhalte folgen", "Skilltree kommt noch", "Caches oeffnen kommt mit dem
Hangar-Shop", "darunter: die Wege danach"), doppelte Saetze (Boss-Text vs.
Infinity-Zeile, "Neue DROMEs entstehen in der Fabrik" zweimal, "Anfuehrer" vs.
Titel, "Oeffnet die Spielstand-Wahl", Testkarte), veraltete Verweise auf den
Hangar (jetzt Inventar bzw. DROMEs) und auf Erfahrung/EP.
