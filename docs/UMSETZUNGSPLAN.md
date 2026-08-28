# Umsetzungsplan: das volle Klassenmodell in die Engine

> Grundlage: `data/balancing/ausruestung_stats.json` (die kuratierte Balancing-
> Sicht, mit `stat_glossar` = Abbildung jeder Balancing-Größe auf ein Engine-
> Feld) und `docs/KONZEPT_ABGLEICH.md` (Lückenanalyse). Ziel: das in der Tabelle
> beschriebene Klassenmodell Schritt für Schritt in die Engine bringen.
>
> Arbeitsweise: eine Phase = ein oder wenige Commits, Tests grün, dann weiter.
> Werte kommen aus der Balancing-JSON; sie bleiben playtest-tunebar.

## Quelle der Wahrheit
- **Konzept/Werte:** `data/balancing/ausruestung_stats.json`.
- **Engine-Werte:** `tools/build_sample_parts.py` → `STATS` (per Teil, summiert
  sich zur Hülle). Chassis-Werte der Tabelle = Summe aus body+head+feet.
- Neue Engine-Felder markiert das Glossar mit „(neu)": `energieschild` →
  `shield`, `schildregeneration`, `schildbonus`.

---

## Phase 1 — Werte & schnelle Angleichungen (niedriges Risiko)
- **Waffenwerte** an die Tabelle: Puls-Blaster Schaden 12→10; Schienen-Lanze
  16→22; Runenstab 18→10. Belagerung 18 (=).
- **Runenstab = Kreuz-AoE** (4 orthogonale Nachbarn) statt Einzelziel — neue
  Zielform `aoe_cross`.
- **Drohnen-Pod passiv:** 5 %/Zug Selbstheilung zu Zugbeginn statt aktiver
  Heil-Fähigkeit.
- **Ködersender:** vorerst nur Aggro (+25), Taunt schon gestrichen (§13). (Upload-
  Notiz „streichen" → als Einzelentscheidung offen gehalten, nicht destruktiv.)

## Phase 2 — Chassis-Grundwerte an die Tabelle
- Integrität 50/150/100/50, Tempo 15/10/12/10, Move 5/3/4/3, Traglast/Slots
  laut Tabelle. Verteilt auf body/head/feet, sodass die Hüllensumme stimmt.

## Phase 3 — Zwei-Verteidigungs-System (§11)
- Neue Stats **`shield`/`shield_max`, `shield_regen`, `shield_bonus`**; Schild-
  Leiste vor der HP auf `Unit`, regeneriert je Zug.
- **`damage_type`** physical/energie an Waffen (heute alles `normal`).
- **Schadensmatrix** (flach, gedeckelt, nachrechenbar): Schild wird durch
  **Energie** geknackt (Schild schwach gegen Energie), Panzerung durch
  **Physisch** (Panzerung schwach gegen Physisch). Off-Diagonale = volle
  Verteidigung. Faktoren als Config-Dials.
- Kerne tragen `schildregeneration` + `schildbonus`. UI: Schild-Leiste.

## Phase 4 — Signatur-Passive je Chassis
- Passive-/Trigger-System. Adrenalin (nach Kill +Tempo), **Bollwerk** (Molok
  fängt 50 % Schaden angrenzender Verbündeter ab), Energy-Junky (Schaden pro
  ausgegebener Energie), Straight Line (orthogonale Linie +50 %).

## Phase 5 — Kern-Passive + Bonus-Stat + Loot-Kerne
- Hit & Run, Overchargerepair, Fast Forward, Open-Scope. Bonus-Stat je Kern
  (+Speed/+Integrität/+Power …). Loot-Kerne COR-005 (Effizienz) / COR-006
  (Verstärker) mit Kosten-/Wirkungs-Modifikatoren.

## Phase 6 — Angriffsdesigns / Animationen
- Projektil-/Trefferanimationen je Waffe: runder Laserpuls, mörserartiger
  Schuss, Energie-Cluster, dreieckige Railgun.

## Phase 7 — Balancing-Sicht & Doku nachziehen
- `data/balancing/ausruestung_stats.json` / `build_balance_sheet.py` mit dem
  Umgesetzten abgleichen, `docs/ausruestung_stats.xlsx` neu erzeugen,
  `GAME_DESIGN.md` §11/§13 finalisieren.

---

## Status
- [x] **Phase 1 — Werte & schnelle Angleichungen** (Puls 10/Rw3, Lanze 22/Rw8,
  Runenstab 10 als Kreuz-AoE; Drohnen-Pod passiv 5 %/Zug; Ködersender aggro-only)
- [ ] Phase 2 — Chassis-Grundwerte
- [ ] Phase 3 — Zwei-Verteidigungs-System (§11)
- [ ] Phase 4 — Signatur-Passive je Chassis
- [ ] Phase 5 — Kern-Passive + Loot-Kerne
- [ ] Phase 6 — Angriffsdesigns / Animationen
- [ ] Phase 7 — Balancing-Sicht & Doku
