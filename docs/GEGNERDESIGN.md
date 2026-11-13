# Cyberdrome – Gegnerdesign: Sentinel-System, Fraktionen & Progression

> **Status:** Konzeptstand aus dem Brainstorming (Stand: 12.11.2026). Noch nicht final.
> Abschnitte mit ⚠️ sind offene Punkte oder Unstimmigkeiten, die vor der Umsetzung geklärt werden müssen.
> **Für Claude Code:** Dieses Dokument beschreibt Design-Absichten, keine fertige Spezifikation. Bei ⚠️-Punkten nicht raten, sondern nachfragen.

---

## 1. Kontext

Cyberdrome ist ein Squad-basiertes Roguelike mit automatischen Kämpfen. Der Spieler stellt vor dem Kampf bis zu vier Dromes zusammen, rüstet sie mit Modulen aus (Shop zwischen den Kämpfen) und schaut dann zu, wie die Einheiten selbstständig kämpfen.

**Kern-Gameplay:** Die Vorbereitung ist das eigentliche Gameplay. Gegnerformationen sind vorhersehbar, Moduldrops nicht. Der Spieler kennt die Herausforderung, aber nicht zwingend die perfekte Lösung.

---

## 2. Entscheidungsweg

| Schritt | Stand | Ergebnis |
| --- | --- | --- |
| Ausgangsidee | Gegnerische Fraktionen bestehen aus eigenen NPC-Bots; der gegnerische Drome tritt als Boss auf und wird nach dem Sieg freigeschaltet. | Erweitert; Freischaltung offen |
| Altformationen | Formationen wie „Neon Bullies“ (2 Tanks + 2 Plänkler) stammen aus dem alten Konzept. | Müssen ans Sentinel-System angepasst werden |
| Anzahl Dromes | Gegner-Squads haben mindestens einen Drome; für hohe Schwierigkeit kommen weitere hinzu. | Übernommen |
| Erweiterung | Gegner treten ebenfalls als Squad an: ein Drome + mehrere reguläre Einheiten. | Übernommen |
| Asymmetrie | Keine symmetrischen 4-vs-4-Kämpfe. Spieler: wenige starke Dromes. Gegner: ein prägender Drome + größere Zahl schwächerer Einheiten. | Übernommen |
| Begriff | Für reguläre Gegner wurden Vasallen, Frames, Constructs, Units und Sentinel diskutiert. | **Sentinel** gewählt |
| Rollen | Sentinels decken Assault, Sniper, Mage, Support ab. Tank und Plänkler bleiben den Dromes vorbehalten. | Übernommen (vorläufig) |
| Skalierung | Sentinels werden eine erweiterbare Gattung mit Varianten (Elite, Heavy, Boss …). | Übernommen |
| Ergebnis | Aus einer einfachen NPC-Idee wird ein **Baukastensystem** für das gesamte Gegnerdesign. | Leitidee |

---

## 3. Begriffe (Glossar)

| Begriff | Bedeutung |
| --- | --- |
| **Drome** | Die spielbaren Helden-Einheiten. Stark und spezialisiert, mit eigener Waffe, passiven Fähigkeiten und einer taktischen Identität. Bis zu 4 im Spieler-Squad; treten auch als Anführer gegnerischer Squads auf. Bekannte Dromes: Strix, Vireo, Nimbus. |
| **Identität** | Die taktische Rolle eines Dromes, z. B. Tank, Plänkler (Vireo) oder Support (Nimbus). |
| **Sentinel** | Die Bots der Gegner: reguläre Kampfeinheiten. Schwächer und einfacher als ein Drome, mit festem Archetyp. Benennung: `[Fraktion] [Archetyp] Sentinel`, z. B. *Neon Sniper Sentinel*. |
| **Squad** | Eine Kampfgruppe. Gegnerisch: mindestens 1 Drome + n Sentinels. |
| **Fraktion** | Thematische Gegnergruppe (z. B. Neon) mit eigenen Dromes, Sentinels und Erweiterungen. |
| **Formation** | Konkrete, benannte Squad-Zusammenstellung (z. B. „Neon Bullies“). |
| **Modul** | Ausrüstungsteil, das Einheiten verändert. Gilt für Spieler und Gegner. |
| **Welle** | Ein Kampfabschnitt innerhalb einer Begegnung; Gegner werden von Welle zu Welle stärker. |

---

## 4. Kampfstruktur

**Spieler:** bis zu 4 Dromes, individuell mächtiger und vielseitiger als reguläre Gegner.

**Gegner-Squad:**
- **Mindestens 1 Drome – taktischer Mittelpunkt**
  - Standard ist genau ein Drome. In besonders schweren Begegnungen kommen weitere Dromes hinzu.
  - Ein zusätzlicher Drome ist die stärkste mögliche Verstärkung, z. B. ein Support-Drome für den Anführer.
  - eigene Waffe und passive Fähigkeiten
  - aktive, relevante Bedrohung (kein reiner Support, kein klassischer Boss)
  - prägt die Spielweise der gesamten Squad → Elite-Kämpfer + Squad-Leader
- **Sentinels – reguläre Kampfeinheiten**
  - spezialisierte Archetypen
  - ergänzen den Drome taktisch
  - variieren in Anzahl, Kombination und Stärke

**Ziel:** abwechslungsreiche, interessante Begegnungen – keine erzwungene Symmetrie.

---

## 5. Sentinel-Archetypen (Grundausstattung)

| Archetyp | Aufgabe |
| --- | --- |
| Assault / Nahkampf | Direkter Angriff, Druck auf den Spieler |
| Sniper / Fernkampf | Distanzangriffe, gezielter Schaden (z. B. vereinfachter Strix) |
| Mage | Technische Spezialangriffe, besondere Effekte |
| Support | Buffs und Unterstützung anderer Einheiten |

**Bewusst nicht vorgesehen:** Tank- und Plänkler-Sentinels – diese Rollen decken die Dromes ab.

Anzahl und Fähigkeiten der Archetypen sind noch nicht final (3–4 geplant).

---

## 6. Sentinel-Varianten

| Variante | Eigenschaften |
| --- | --- |
| Basic Sentinel | Standardgegner |
| Elite Sentinel | Verbesserte Werte + zusätzliche Fähigkeiten |
| Specialist Sentinel | Besondere taktische Funktion |
| Heavy Sentinel | Besonders widerstandsfähig |
| Boss Sentinel | Einzigartige Fähigkeiten und Kampfmechaniken |

**Regel:** Eine höhere Stufe darf nicht nur mehr HP und Schaden bedeuten. Jede Variante soll eine neue taktische Herausforderung erzeugen.

---

## 7. Beispiel: Neon-Squad mit Vireo

Grundaufstellung: 1 Neon Vireo (Drome, Plänkler, Nahkampfwaffe) + 3–4 Neon Sentinels.

| Welle | Gegneraufstellung | Steigerung |
| --- | --- | --- |
| 1 | Vireo + 3 Sentinels | Grundformation |
| 2 | Vireo + 3 Sentinels | Zusätzliche Module |
| 3 | Vireo + 4 Sentinels | Verstärkung |
| 4 | Vireo + 4 Sentinels + Nimbus | Support-Erweiterung |

In Welle 4 kommt Nimbus als **zweiter Drome** hinzu. Er gibt dem Vireo gezielt Support: Er buffed die übrigen Einheiten, kämpft aber weiter aktiv mit. Am Ende umfasst die Gegner-Squad 6 Einheiten (2 Dromes + 4 Sentinels) gegen 4 Spieler-Dromes.

---

## 8. KI-Prinzip: Die Waffe bestimmt das Verhalten

Das Verhalten einer Einheit wird primär über ihre Waffe und ihre Drome-Identität gesteuert, nicht über eine individuelle KI pro Gegner.

**Vorteil:** Neue Gegner lassen sich mit geringem Aufwand erstellen, weil sie vorhandene Verhaltensmuster wiederverwenden.

---

## 9. Module & Roguelike-System

Das bestehende Shop- und Modulsystem bleibt unverändert. Spieler kaufen zwischen den Kämpfen Module und entwickeln ihre Dromes weiter.

Gegner nutzen dasselbe Regelsystem:
- Grundausrüstung ist vordefiniert.
- Stärkere Gegner erhalten zusätzliche Module.
- Elite-Einheiten können besondere Modulkombinationen tragen.
- Höhere Schwierigkeitsstufen werten bekannte Gegner durch neue Kombinationen auf.

→ **Ein gemeinsames Regelsystem für Spieler- und Gegner-Einheiten.**

---

## 10. Leveldesign & Progression

Statt pro Level neue Gegner zu bauen, werden vorhandene Einheiten neu kombiniert und erweitert.

| Phase | Inhalt |
| --- | --- |
| Frühe Level | Grundlegende Dromes, einfache Sentinel-Formationen |
| Mittlere Level | Zusätzliche Archetypen, Module, Elite-Einheiten |
| Späte Level | Komplexe Squads mit spezialisierten Einheiten und Synergien |
| Boss-Level | Besondere Drome-Konfigurationen, Elite-Sentinels, einzigartige Mechaniken |

**Stellschrauben für die Schwierigkeit:**
1. Anzahl der Gegner
2. Anzahl der gegnerischen Dromes (zusätzliche Dromes = stärkste Eskalationsstufe)
3. Zusammensetzung der Squad
4. Fähigkeiten der gegnerischen Dromes
5. Ausrüstung / Module
6. Sentinel-Varianten
7. Synergien zwischen Einheiten

**Formationen erzählen eine taktische Geschichte:** Name und Zusammensetzung sollen schon vor dem Kampf erkennen lassen, welche Herausforderung wartet. Bestehende Formationen aus dem alten Konzept (z. B. „Neon Bullies“ mit 2 Tanks + 2 Plänklern) werden auf das Schema „Drome(s) + Sentinels“ umgestellt.

---

## 11. Designprinzipien (Leitplanken)

1. **Asymmetrische Kämpfe** – wenige starke Dromes gegen größere gegnerische Squads.
2. **Klare Rollenverteilung** – Dromes = taktische Spezialeinheiten, Sentinels = reguläre Kampfeinheiten.
3. **Fraktionsidentität** – der gegnerische Drome prägt die Spielweise seiner Squad.
4. **Modularität** – Gegner werden über Module und Zusammensetzung aufgewertet.
5. **Skalierbarkeit** – neue Archetypen und Varianten erweitern das Spiel, ohne das Grundsystem zu ändern.
6. **Taktische Schwierigkeit** – neue Gegner bringen neue Herausforderungen, nicht nur höhere Werte.
7. **Wiederverwendbarkeit** – bekannte Einheiten ergeben durch neue Kombinationen neue Begegnungen.
8. **Vorbereitung als Gameplay** – bekannte Gegner, unbekannte Drops.

---

## 12. Vergleichsspiele (Recherche-Notizen)

Keines bildet das Gesamtkonzept ab; sie dienen als Referenz für Einzelaspekte. Angaben stammen aus einer früheren Recherche und wurden nicht erneut geprüft.

| Spiel | Worauf achten |
| --- | --- |
| Despot's Game | Squad-Aufbau, Roguelike-Progression (nächster Vergleich) |
| Bug Squad Tactics | Synergien, passive Fähigkeiten → relevant für Module |
| Quantum Squad: Sci-Fi Tactics | Waffen, Mods, Sci-Fi-Identität (kein reiner Autobattler) |
| Vivid Knight | Charakteridentitäten, Gruppensynergien |
| Botworld Adventure | Roboterdesign, individuelle Fähigkeiten |

**Leitfragen beim Anspielen:**
- Wie entsteht Abwechslung zwischen aufeinanderfolgenden Kämpfen?
- Wie verhindert das Spiel, dass sich immer dieselbe Squad durchsetzt?
- Wie fühlt sich der Tausch einer Einheit oder Ausrüstung an?

---

## 13. Offene Fragen & Unstimmigkeiten ⚠️

**Geklärt:**
- „Neon Bullies“ stammt aus dem alten Konzept und wird angepasst.
- Gegner-Squads haben mindestens einen Drome; weitere kommen bei hoher Schwierigkeit hinzu (Nimbus in Welle 4 = zweiter Drome).
- Begriffe: Dromes = spielbare Helden-Einheiten, Sentinels = Gegner-Bots, Plänkler = Identität (z. B. Vireo).

**Noch offen:**
1. **Freischaltung:** Ob besiegte gegnerische Dromes für den Spieler freigeschaltet werden, ist bewusst **nicht entschieden**. Nicht fest einbauen; höchstens so umsetzen, dass es später leicht ergänzt oder entfernt werden kann.
2. **Neue Fassung der „Neon Bullies“** und anderer Altformationen.
3. **Mehrere Dromes:** Ab welcher Schwierigkeit kommen zusätzliche Dromes, und gibt es eine Obergrenze?
4. **Archetyp-Name „Mage“:** Platzhalter oder final? (Passt evtl. weniger zum Cyber-Setting als die anderen.)
5. **Anzahl der Archetypen:** 3 oder 4 für den Start?
6. **Wellen:** Kämpft der Spieler alle Wellen mit denselben Dromes ohne Shop dazwischen, und bleibt Schaden zwischen Wellen bestehen?
7. **Monetarisierung:** Premium ohne Gacha oder Free-to-Play? Beeinflusst Progression und Spielökonomie.
8. **Playtest-Ergebnisse:** Die Bedienungsprobleme und die geplante Änderung am Gesamtsetup aus dem letzten Playtest sind hier noch nicht enthalten.
